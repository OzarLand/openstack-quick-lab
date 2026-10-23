#!/usr/bin/env bash
# Create the lab VM: one VM (4 vCPU, 16 GB RAM, 50 GB disk), its key, security group, port and, optionally, a
# floating IP. Shows the estimated cost per hour and asks for confirmation before creating anything.
. "$(dirname "$0")/lib.sh"
need openstack "Install python-openstackclient (pip install python-openstackclient)."
need ssh-keygen "Install OpenSSH."
grep -qE '^(OS_CLOUD|NETWORK|SSH_FROM)=".*<' "$HERE/config.env" && die "Fill in OS_CLOUD, NETWORK and SSH_FROM in config.env."
python3 - "$SSH_FROM" <<'PY' || die "SSH_FROM=$SSH_FROM opens SSH to too many addresses: use your own address (/32), or at most a /16 (IPv6: /48)."
import ipaddress, sys
n = ipaddress.ip_network(sys.argv[1], strict=False)
sys.exit(0 if n.prefixlen >= (16 if n.version == 4 else 48) else 1)
PY
mkdir -p "$STATE_DIR"; touch "$LOG"
os token issue -f value -c expires >/dev/null || die "Cannot authenticate with OS_CLOUD=$OS_CLOUD."
os server show "$VM" >/dev/null 2>&1 && die "A server named $VM already exists. Destroy it first, or change LAB."

# Flavor: the smallest with at least 4 vCPU, 16 GB RAM and a 50 GB disk; else one with no disk (boot from a volume).
BOOT_VOLUME=""
if [ -z "$FLAVOR" ]; then
  read -r FLAVOR BOOT_VOLUME < <(os flavor list --long -f json | python3 -c '
import json, sys
f = [x for x in json.load(sys.stdin) if x["VCPUs"] >= 4 and x["RAM"] >= 16384]
disk = sorted((x["VCPUs"], x["RAM"], x["Disk"], x["Name"]) for x in f if x["Disk"] >= 50)
nodisk = sorted((x["VCPUs"], x["RAM"], x["Name"]) for x in f if x["Disk"] == 0)
print(disk[0][3], "" if disk else "") if disk else print(nodisk[0][2], 50) if nodisk else print("")')
  [ -n "$FLAVOR" ] || die "No flavor with at least 4 vCPU and 16 GB of RAM: set FLAVOR in config.env."
else
  [ "$(os flavor show "$FLAVOR" -f value -c disk)" -lt 50 ] && BOOT_VOLUME=50
fi
# Image: the most recent active image named like "Ubuntu 24.04".
[ -z "$IMAGE" ] && IMAGE=$(os image list --status active -f value -c Name | { grep -iE 'ubuntu.*24\.04' || true; } | sort | tail -1)
[ -n "$IMAGE" ] || die "No active Ubuntu 24.04 image found: set IMAGE in config.env."
os network show "$NETWORK" >/dev/null || die "Network $NETWORK not found."
[ -n "$FLOATING_NETWORK" ] && { os network show "$FLOATING_NETWORK" >/dev/null || die "Network $FLOATING_NETWORK not found."; }

F="$(os flavor show "$FLAVOR" -f value -c vcpus) vCPU, $(os flavor show "$FLAVOR" -f value -c ram) MB RAM, $(os flavor show "$FLAVOR" -f value -c disk) GB disk"
echo
echo "About to create, in cloud '$OS_CLOUD':"
echo "  VM              $VM  (flavor $FLAVOR: $F)"
[ -n "$BOOT_VOLUME" ] && echo "  root volume     ${VM}-root, ${BOOT_VOLUME} GB (the flavor has no disk of 50 GB)"
echo "  image           $IMAGE"
echo "  network         $NETWORK$([ -n "$FLOATING_NETWORK" ] && echo ", floating IP from $FLOATING_NETWORK")"
echo "  security group  ${VM}-sg (SSH and ping from $SSH_FROM only)"
echo "  key pair        ${VM}-key (private key kept in $STATE_DIR)"
if [ -n "$COST_PER_HOUR" ]; then
  echo "  estimated cost  $COST_PER_HOUR $CURRENCY per hour (COST_PER_HOUR: the flavor, plus the root volume and the floating IP if your provider bills them apart)"
  echo "                  $COST_PER_HOUR $CURRENCY per hour, $(awk -v c="$COST_PER_HOUR" 'BEGIN{printf "%.2f", c*24}') $CURRENCY per day, until you run destroy.sh"
else
  echo "  estimated cost  UNKNOWN: set COST_PER_HOUR in config.env from your provider's price list"
fi
echo "The VM costs money every hour it exists. Run ./destroy.sh when you are done."
confirm "Create it?"

T0=$(date +%s); save CREATED_AT "$(date -u +%FT%TZ)"
say "Key pair ${VM}-key"
[ -f "$KEY" ] || ssh-keygen -q -t ed25519 -N '' -C "$VM" -f "$KEY"
os keypair create --public-key "$KEY.pub" "${VM}-key" -f value -c name >/dev/null; save KEYPAIR "${VM}-key"
say "Security group ${VM}-sg"
SG=$(os security group create "${VM}-sg" --description "openstack-quick-lab $VM" -f value -c id); save SG "$SG"
os security group rule create "$SG" --protocol tcp --dst-port 22 --remote-ip "$SSH_FROM" >/dev/null
os security group rule create "$SG" --protocol icmp --remote-ip "$SSH_FROM" >/dev/null
say "Port ${VM}-port on $NETWORK"
PORT=$(os port create --network "$NETWORK" --security-group "$SG" "${VM}-port" -f value -c id); save PORT "$PORT"
if [ -n "$BOOT_VOLUME" ]; then
  # The root volume is created here, under a name, so that destroy.sh always finds it (a volume created by
  # "server create --boot-from-volume" has no name and survives the server).
  say "Root volume ${VM}-root (${BOOT_VOLUME} GB, from the image)"
  VT=(); [ -n "${VOLUME_TYPE:-}" ] && VT=(--type "$VOLUME_TYPE")
  VOL=$(os volume create --image "$IMAGE" --size "$BOOT_VOLUME" "${VT[@]}" --bootable "${VM}-root" -f value -c id) \
    || die "Could not create the root volume (if the cloud has no default volume type, set VOLUME_TYPE). Run ./destroy.sh to delete what was created."
  save BOOT_VOLUME_ID "$VOL"
  for _ in $(seq 1 60); do st=$(os volume show "$VOL" -f value -c status); [ "$st" = available ] && break; [ "$st" = error ] && die "Volume ${VM}-root is in error. Run ./destroy.sh."; sleep 5; done
  [ "$st" = available ] || die "Volume ${VM}-root not available after 5 minutes. Run ./destroy.sh."
fi
say "Server $VM (waiting until it is active)"
BOOT=(--image "$IMAGE"); [ -n "$BOOT_VOLUME" ] && BOOT=(--volume "$VOL")
SRV=$(os server create --flavor "$FLAVOR" "${BOOT[@]}" --port "$PORT" --key-name "${VM}-key" \
      --config-drive true --wait "$VM" -f value -c id) || die "The server did not become active. Run ./destroy.sh to delete what was created."
save SERVER "$SRV"
# "server create --wait" can end with "Error creating server" and still exit 0: check the status itself.
STATUS=$(os server show "$VM" -f value -c status)
[ "$STATUS" = ACTIVE ] || die "Server $VM is $STATUS, not ACTIVE. Run ./destroy.sh to delete what was created."
ADDR=$(os port show "$PORT" -f json -c fixed_ips | python3 -c 'import json,sys; print(json.load(sys.stdin)["fixed_ips"][0]["ip_address"])')
save VM_FIXED_ADDRESS "$ADDR"; VM_ADDRESS="$ADDR"
if [ -n "$FLOATING_NETWORK" ]; then
  say "Floating IP"
  FIP_ID=$(os floating ip create "$FLOATING_NETWORK" --port "$PORT" --description "$VM" -f value -c id); save FIP_ID "$FIP_ID"
  VM_ADDRESS=$(os floating ip show "$FIP_ID" -f value -c floating_ip_address)
fi
save VM_ADDRESS "$VM_ADDRESS"
say "Waiting for SSH on $VM_ADDRESS"
for _ in $(seq 1 60); do ssh_vm true 2>/dev/null && break; sleep 5; done
ssh_vm 'cloud-init status --wait >/dev/null; echo "$(hostname): $(nproc) vCPU, $(free -g | awk "/Mem/{print \$2}") GB RAM, $(df -h / | awk "NR==2{print \$2}") disk, KVM: $([ -e /dev/kvm ] && echo yes || echo no)"' | tee -a "$LOG"
say "Created in $(( $(date +%s)-T0 )) s. Next: ./deploy.sh   (and ./destroy.sh when you are done)"
