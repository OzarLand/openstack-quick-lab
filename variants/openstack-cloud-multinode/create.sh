#!/usr/bin/env bash
# Create the VMs of a multinode lab: CONTROLLERS controllers and COMPUTES computes, their key, security group, ports,
# the lab's external network and, optionally, a floating IP for controller 1. Shows the estimated cost per hour for
# the lab's size and asks for confirmation before creating anything. Refuses to run without the cost settings,
# unless started with --no-cost-estimate.
. "$(dirname "$0")/lib.sh"
NO_COST_ESTIMATE=""
for a in "$@"; do
  case "$a" in
    --no-cost-estimate) NO_COST_ESTIMATE=yes ;;
    *) die "Unknown option: $a (the only option is --no-cost-estimate)." ;;
  esac
done
need openstack "Install python-openstackclient (pip install python-openstackclient)."
need ssh-keygen "Install OpenSSH."
grep -qE '^(OS_CLOUD|NETWORK|SSH_FROM)=".*<' "$HERE/config.env" && die "Fill in OS_CLOUD, NETWORK and SSH_FROM in config.env."
num() { [[ "$1" =~ ^[0-9]+([.][0-9]+)?$ ]]; }
COST_PER_HOUR_EXTRA="${COST_PER_HOUR_EXTRA:-0}"
if [ -z "$COST_PER_HOUR_CONTROLLER$COST_PER_HOUR_COMPUTE" ] && [ -z "$NO_COST_ESTIMATE" ]; then
  die "COST_PER_HOUR_CONTROLLER and COST_PER_HOUR_COMPUTE are empty in config.env. Copy the price per hour of each flavor from your provider's price list (and in COST_PER_HOUR_EXTRA what it bills apart). To create the lab without a cost estimate anyway, run: ./create.sh --no-cost-estimate"
fi
if [ -n "$COST_PER_HOUR_CONTROLLER$COST_PER_HOUR_COMPUTE" ]; then
  for c in COST_PER_HOUR_CONTROLLER COST_PER_HOUR_COMPUTE COST_PER_HOUR_EXTRA; do
    num "${!c}" || die "$c=${!c} is not a number (write it like 0.196, with a dot)."
  done
fi
python3 - "$SSH_FROM" <<'PY' || die "SSH_FROM=$SSH_FROM opens SSH to too many addresses: use your own address (/32), or at most a /16 (IPv6: /48)."
import ipaddress, sys
n = ipaddress.ip_network(sys.argv[1], strict=False)
sys.exit(0 if n.prefixlen >= (16 if n.version == 4 else 48) else 1)
PY
read -r EXT_GW EXT_PREFIX < <(python3 -c "import ipaddress as i; n=i.ip_network('$LAB_EXT_CIDR'); print(next(n.hosts()), n.prefixlen)") \
  || die "LAB_EXT_CIDR=$LAB_EXT_CIDR is not a valid range."
mkdir -p "$STATE_DIR"; touch "$LOG"
os token issue -f value -c expires >/dev/null || die "Cannot authenticate with OS_CLOUD=$OS_CLOUD."
for n in "${NODES[@]}"; do os server show "$n" >/dev/null 2>&1 && die "A server named $n already exists. Destroy the lab first, or change LAB."; done
# Resources left by a previous run that stopped half-way (all named "${LABNAME}-..."): create.sh would fail on them
# with a raw client error.
names() { local out; out=$(os "$@" -f value -c Name 2>&1) || die "Could not list the project's resources ($*): $(printf '%s' "$out" | tail -1)"; printf '%s\n' "$out"; }
L_KEYS=$(names keypair list); L_SGS=$(names security group list); L_PORTS=$(names port list)
L_NETS=$(names network list); L_VOLS=$(names volume list)
LEFTOVERS=$(printf '%s\n' "$L_KEYS" "$L_SGS" "$L_PORTS" "$L_NETS" "$L_VOLS" | awk -v p="${LABNAME}-" 'index($1, p) == 1')
[ -z "$LEFTOVERS" ] || die "Resources of a previous run of $LABNAME still exist ($(echo $LEFTOVERS)): run ./destroy.sh first."
os network show "$NETWORK" >/dev/null || die "Network $NETWORK not found."
[ -n "$FLOATING_NETWORK" ] && { os network show "$FLOATING_NETWORK" >/dev/null || die "Network $FLOATING_NETWORK not found."; }

# Flavor per role: the smallest with at least 4 vCPU, <ram> MB and a 50 GB disk; else one with no disk (boot from a
# volume of 50 GB).
pick_flavor() { # pick_flavor <ram-mb> -> "<flavor> <boot-volume-size or empty>"
  os flavor list --long -f json | python3 -c '
import json, sys
ram = int(sys.argv[1])
f = [x for x in json.load(sys.stdin) if x["VCPUs"] >= 4 and x["RAM"] >= ram]
disk = sorted((x["VCPUs"], x["RAM"], x["Name"]) for x in f if x["Disk"] >= 50)
nodisk = sorted((x["VCPUs"], x["RAM"], x["Name"]) for x in f if x["Disk"] == 0)
print(disk[0][2], "") if disk else print(nodisk[0][2], 50) if nodisk else print("")' "$1"
}
flavor_volume() { [ "$(os flavor show "$1" -f value -c disk)" -lt 50 ] && echo 50 || echo ""; }
if [ -z "$CONTROLLER_FLAVOR" ]; then read -r CONTROLLER_FLAVOR CTL_BOOT < <(pick_flavor 16384); else CTL_BOOT=$(flavor_volume "$CONTROLLER_FLAVOR"); fi
if [ -z "$COMPUTE_FLAVOR" ]; then read -r COMPUTE_FLAVOR CMP_BOOT < <(pick_flavor 8192); else CMP_BOOT=$(flavor_volume "$COMPUTE_FLAVOR"); fi
[ -n "$CONTROLLER_FLAVOR" ] || die "No flavor with at least 4 vCPU and 16 GB of RAM for the controllers: set CONTROLLER_FLAVOR in config.env."
[ -n "$COMPUTE_FLAVOR" ] || die "No flavor with at least 4 vCPU and 8 GB of RAM for the computes: set COMPUTE_FLAVOR in config.env."
[ -z "$IMAGE" ] && IMAGE=$(os image list --status active --sort created_at:desc -f value -c Name | { grep -iE 'ubuntu.*24\.04' || true; } | head -1)
[ -n "$IMAGE" ] || die "No active Ubuntu 24.04 image found: set IMAGE in config.env."
desc() { echo "$(os flavor show "$1" -f value -c vcpus) vCPU, $(os flavor show "$1" -f value -c ram) MB RAM, $(os flavor show "$1" -f value -c disk) GB disk"; }

echo
echo "About to create, in cloud '$OS_CLOUD', a lab of $CONTROLLERS controller(s) and $COMPUTES compute(s):"
for n in "${CTLS[@]}"; do echo "  VM              $n  (flavor $CONTROLLER_FLAVOR: $(desc "$CONTROLLER_FLAVOR"))"; done
for n in "${CMPS[@]}"; do echo "  VM              $n  (flavor $COMPUTE_FLAVOR: $(desc "$COMPUTE_FLAVOR"))"; done
[ -n "$CTL_BOOT$CMP_BOOT" ] && echo "  root volumes    <vm>-root, 50 GB each, for the flavors without a 50 GB disk"
echo "  image           $IMAGE"
echo "  network         $NETWORK$([ -n "$FLOATING_NETWORK" ] && echo ", floating IP from $FLOATING_NETWORK for $CTL1")"
echo "  lab network     ${LABNAME}-ext, $LAB_EXT_CIDR, no gateway, no DHCP (the lab's floating IPs)"
echo "  ports           one per VM on $NETWORK; one per controller on ${LABNAME}-ext; ${LABNAME}-ctl-1-gw for $CTL1"
[ "$CONTROLLERS" = 3 ] && echo "  virtual IP      ${LABNAME}-vip, an address of $NETWORK reserved for the controllers' VIP"
echo "  security group  ${LABNAME}-sg (SSH and ping from $SSH_FROM; everything between the lab's VMs)"
echo "  key pair        ${LABNAME}-key (private key kept in $STATE_DIR)"
if [ -n "$COST_PER_HOUR_CONTROLLER$COST_PER_HOUR_COMPUTE" ]; then
  TOTAL=$(awk -v a="$CONTROLLERS" -v b="${COST_PER_HOUR_CONTROLLER:-0}" -v c="$COMPUTES" -v d="${COST_PER_HOUR_COMPUTE:-0}" -v e="$COST_PER_HOUR_EXTRA" 'BEGIN{printf "%.3f", a*b+c*d+e}')
  echo "  estimated cost  $CONTROLLERS x $COST_PER_HOUR_CONTROLLER + $COMPUTES x $COST_PER_HOUR_COMPUTE + $COST_PER_HOUR_EXTRA = $TOTAL $CURRENCY per hour"
  echo "                  $(awk -v t="$TOTAL" 'BEGIN{printf "%.2f", t*24}') $CURRENCY per day, until you run destroy.sh"
else
  echo "  estimated cost  UNKNOWN (--no-cost-estimate): you chose to create the lab without the cost settings"
fi
echo "The VMs cost money every hour they exist. Run ./destroy.sh when you are done."
confirm "Create it?"

T0=$(date +%s); save CREATED_AT "$(date -u +%FT%TZ)"; save CONTROLLERS "$CONTROLLERS"; save COMPUTES "$COMPUTES"
say "Key pair ${LABNAME}-key"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C "$LABNAME" -f "$KEY"
os keypair create --public-key "$KEY.pub" "${LABNAME}-key" -f value -c name >/dev/null; save KEYPAIR "${LABNAME}-key"
say "Security group ${LABNAME}-sg"
SG=$(os security group create "${LABNAME}-sg" --description "openstack-quick-lab $LABNAME" -f value -c id); save SG "$SG"
os security group rule create "$SG" --protocol tcp --dst-port 22 --remote-ip "$SSH_FROM" >/dev/null
os security group rule create "$SG" --protocol icmp --remote-ip "$SSH_FROM" >/dev/null
# Everything between the lab's VMs: APIs, Galera, RabbitMQ, VXLAN, VRRP, live migration.
os security group rule create "$SG" --protocol any --remote-group "$SG" >/dev/null
say "Lab network ${LABNAME}-ext ($LAB_EXT_CIDR)"
NET=$(os network create "${LABNAME}-ext" --description "openstack-quick-lab $LABNAME" -f value -c id); save EXT_NET "$NET"
# Ports of this cloud need a subnet; no gateway and no DHCP: the lab's own Neutron hands out these addresses.
os subnet create --network "$NET" --subnet-range "$LAB_EXT_CIDR" --gateway none --no-dhcp "${LABNAME}-ext-subnet" -f value -c id >/dev/null
AAP=()
if [ "$CONTROLLERS" = 3 ]; then
  say "Virtual IP ${LABNAME}-vip on $NETWORK"
  VIP=$(os port create --network "$NETWORK" --no-security-group "${LABNAME}-vip" -f json -c fixed_ips | python3 -c 'import json,sys; print(json.load(sys.stdin)["fixed_ips"][0]["ip_address"])')
  save VIP "$VIP"; AAP=(--allowed-address "ip-address=$VIP")
fi
for n in "${NODES[@]}"; do
  s=$(sid "$n"); say "Ports of $n"
  P=$(os port create --network "$NETWORK" --security-group "$SG" "${AAP[@]}" "${n}-port" -f value -c id); save "PORT_$s" "$P"
  save "ADDR_$s" "$(os port show "$P" -f json -c fixed_ips | python3 -c 'import json,sys; print(json.load(sys.stdin)["fixed_ips"][0]["ip_address"])')"
  case "$n" in *-ctl-*)
    E=$(os port create --network "$NET" --no-fixed-ip --disable-port-security "${n}-ext" -f value -c id); save "EXTPORT_$s" "$E"
    save "EXTMAC_$s" "$(os port show "$E" -f value -c mac_address)" ;;
  esac
done
GW=$(os port create --network "$NET" --fixed-ip "ip-address=$EXT_GW" --disable-port-security "${CTL1}-gw" -f value -c id)
save GWPORT "$GW"; save GWMAC "$(os port show "$GW" -f value -c mac_address)"; save EXT_GW "$EXT_GW"; save EXT_PREFIX "$EXT_PREFIX"
for n in "${NODES[@]}"; do
  s=$(sid "$n"); load
  case "$n" in *-ctl-*) F=$CONTROLLER_FLAVOR; BV=$CTL_BOOT ;; *) F=$COMPUTE_FLAVOR; BV=$CMP_BOOT ;; esac
  BOOT=(--image "$IMAGE")
  if [ -n "$BV" ]; then
    # Created here under a name, so that destroy.sh always finds it.
    say "Root volume ${n}-root"
    VT=(); [ -n "${VOLUME_TYPE:-}" ] && VT=(--type "$VOLUME_TYPE")
    VOL=$(os volume create --image "$IMAGE" --size "$BV" "${VT[@]}" --bootable "${n}-root" -f value -c id) \
      || die "Could not create the root volume of $n (if the cloud has no default volume type, set VOLUME_TYPE). Run ./destroy.sh."
    save "VOL_$s" "$VOL"
    for _ in $(seq 1 60); do st=$(os volume show "$VOL" -f value -c status); [ "$st" = available ] && break; [ "$st" = error ] && die "Volume ${n}-root is in error. Run ./destroy.sh."; sleep 5; done
    [ "$st" = available ] || die "Volume ${n}-root not available after 5 minutes. Run ./destroy.sh."
    BOOT=(--volume "$VOL")
  fi
  NICS=(--port "$(get PORT "$n")"); [ -n "$(get EXTPORT "$n")" ] && NICS+=(--port "$(get EXTPORT "$n")")
  [ "$n" = "$CTL1" ] && NICS+=(--port "$GWPORT")
  say "Server $n (waiting until it is active)"
  SRV=$(os server create --flavor "$F" "${BOOT[@]}" "${NICS[@]}" --key-name "${LABNAME}-key" --config-drive true --wait "$n" -f value -c id) \
    || die "Server $n did not become active. Run ./destroy.sh to delete what was created."
  save "SERVER_$s" "$SRV"
  # "server create --wait" can end with "Error creating server" and still exit 0: check the status itself.
  STATUS=$(os server show "$n" -f value -c status)
  [ "$STATUS" = ACTIVE ] || die "Server $n is $STATUS, not ACTIVE. Run ./destroy.sh to delete what was created."
done
load; CTL_ADDRESS=$(get ADDR "$CTL1")
if [ -n "$FLOATING_NETWORK" ]; then
  say "Floating IP for $CTL1"
  FIP_ID=$(os floating ip create "$FLOATING_NETWORK" --port "$(get PORT "$CTL1")" --description "$LABNAME" -f value -c id); save FIP_ID "$FIP_ID"
  CTL_ADDRESS=$(os floating ip show "$FIP_ID" -f value -c floating_ip_address)
fi
save CTL_ADDRESS "$CTL_ADDRESS"
say "Waiting for SSH on $CTL1 ($CTL_ADDRESS)"
END=$(( $(date +%s)+300 )); until ssh_ctl true 2>/dev/null; do [ "$(date +%s)" -lt "$END" ] || die "VM unreachable: $CTL1 does not answer SSH on $CTL_ADDRESS after 5 minutes. Check FLOATING_NETWORK and SSH_FROM in config.env, then run ./destroy.sh"; sleep 5; done
ssh_ctl 'cloud-init status --wait >/dev/null; echo "$(hostname): $(nproc) vCPU, $(free -g | awk "/Mem/{print \$2}") GB RAM, $(df -h / | awk "NR==2{print \$2}") disk"' | tee -a "$LOG"
say "Created in $(( $(date +%s)-T0 )) s. Next: ./deploy.sh   (and ./destroy.sh when you are done)"
