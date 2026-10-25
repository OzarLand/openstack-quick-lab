#!/usr/bin/env bash
# Runs on controller 1 (copied and started by deploy.sh). Prepares every VM of the lab, then deploys OpenStack with
# Kolla-Ansible from here. Every step is timed and leaves a marker in ~/.quicklab: a new run skips the steps done.
set -euo pipefail
: "${KOLLA_ANSIBLE_VERSION:?}" "${ANSIBLE_CORE_VERSION:?}" "${LAB_EXT_CIDR:?}" "${EXT_GW:?}" "${EXT_PREFIX:?}" "${GWMAC:?}" "${CONTROLLERS:?}"
HTTPS_PROXY="${HTTPS_PROXY:-}"; NTP_SERVER="${NTP_SERVER:-}"; APT_HTTPS="${APT_HTTPS:-no}"; VIP="${VIP:-}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"; OPENSTACK_TAG="${OPENSTACK_TAG:-}"
M=~/.quicklab; VENV=~/kolla-venv; INV=~/multinode; LKEY=~/.ssh/quicklab_ed25519
export PATH="$VENV/bin:$PATH" ANSIBLE_HOST_KEY_CHECKING=False
trap 'echo "   FAILED at line $LINENO: $BASH_COMMAND"' ERR
# The lab's VMs: name, role (ctl or cmp), address, MAC of the port on the lab network (controllers only).
mapfile -t NODELINES < "$M/nodes"
NAMES=(); ADDRS=(); ROLES=(); EXTMACS=()
for l in "${NODELINES[@]}"; do read -r n r a m <<<"$l"; NAMES+=("$n"); ROLES+=("$r"); ADDRS+=("$a"); EXTMACS+=("$m"); done
CTL1=${NAMES[0]}; CTL1_ADDR=${ADDRS[0]}; CMP1=""; for i in "${!NAMES[@]}"; do [ "${ROLES[$i]}" = cmp ] && { CMP1=${NAMES[$i]}; break; }; done
VIP_ADDR="${VIP:-$CTL1_ADDR}"
read -r EXT_START EXT_END < <(python3 -c "import ipaddress as i; h=list(i.ip_network('$LAB_EXT_CIDR').hosts()); print(h[99], h[198])")
PX=(); [ -n "$HTTPS_PROXY" ] && PX=(env "https_proxy=$HTTPS_PROXY" "http_proxy=$HTTPS_PROXY")
NOPX="localhost,127.0.0.1,$VIP_ADDR,$(IFS=,; echo "${ADDRS[*]}"),$(IFS=,; echo "${NAMES[*]}")${DOCKER_REGISTRY:+,${DOCKER_REGISTRY%%:*}}"
sshn() { local a=$1; shift; ssh -n -i "$LKEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "ubuntu@$a" "$@"; }
sshs() { local a=$1; shift; ssh -i "$LKEY" -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -o BatchMode=yes "ubuntu@$a" "$@"; }

step() { # step <name> <description> <function>
  if [ -f "$M/done-$1" ]; then echo "== $2: already done ($(cat "$M/done-$1") s)"; return; fi
  echo "== $2"; local t0; t0=$(date +%s); "$3"; echo $(( $(date +%s)-t0 )) > "$M/done-$1"; echo "   done in $(cat "$M/done-$1") s"
}
kolla() { # kolla <command> [options]: runs kolla-ansible, keeps the log, shows the failures
  local log="$M/kolla-$1.log"
  if ! "$VENV/bin/kolla-ansible" "$@" -i "$INV" > "$log" 2>&1; then
    grep -E '^fatal' -A8 "$log" | grep -v '\.\.\.ignoring' | head -40; tail -3 "$log"; echo "kolla-ansible $1 failed: full log in $log"; return 1
  fi; grep -A20 'PLAY RECAP' "$log" | grep -E 'ok=' | sed 's/^/   /'
}

# The host preparation every VM gets, the same as in the single-VM variant: automatic upgrades off, proxy, apt over
# HTTPS, NTP. It runs on each VM through SSH, all VMs at once.
host_script() { cat <<HS
set -e
sudo systemctl disable --now unattended-upgrades apt-daily.timer apt-daily-upgrade.timer >/dev/null 2>&1 || true
printf 'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n' | sudo tee /etc/apt/apt.conf.d/20auto-upgrades >/dev/null
if [ -n "$HTTPS_PROXY" ]; then printf 'Acquire::http::Proxy "%s";\nAcquire::https::Proxy "%s";\n' "$HTTPS_PROXY" "$HTTPS_PROXY" | sudo tee /etc/apt/apt.conf.d/90proxy >/dev/null; fi
if [ "$APT_HTTPS" = yes ]; then sudo sed -i 's#http://[^ ]*ubuntu.com/ubuntu/\?#https://archive.ubuntu.com/ubuntu/#' /etc/apt/sources.list.d/ubuntu.sources; fi
if [ -n "$NTP_SERVER" ]; then sudo mkdir -p /etc/systemd/timesyncd.conf.d; printf '[Time]\nNTP=%s\n' "$NTP_SERVER" | sudo tee /etc/systemd/timesyncd.conf.d/90-quicklab.conf >/dev/null; sudo systemctl restart systemd-timesyncd; fi
for _ in \$(seq 1 30); do [ "\$(timedatectl show -p NTPSynchronized --value)" = yes ] && break; sleep 5; done
sudo apt-get update -q >/dev/null
echo "   \$(hostname): clock synchronised \$(timedatectl show -p NTPSynchronized --value), /dev/kvm \$([ -e /dev/kvm ] && echo yes || echo no)"
HS
}
# A port of the lab network: up, without an address (Neutron's br-ex), or with the gateway address on controller 1.
# Named 05- so that it wins over the files netplan generates for the same interface.
link_script() { # link_script <mac> <address/prefix or empty>
  printf "sudo tee /etc/systemd/network/05-quicklab-%s.network >/dev/null <<'NET'\n" "${1//:/}"
  printf '[Match]\nMACAddress=%s\n[Link]\nRequiredForOnline=no\n[Network]\nLinkLocalAddressing=no\n' "$1"
  [ -n "$2" ] && printf 'Address=%s\n' "$2"
  printf 'NET\n'
}
wait_vm() { # wait_vm <address>: SSH answers and cloud-init has finished (the last VMs may still be booting)
  for _ in $(seq 1 60); do sshn "$1" 'cloud-init status --wait >/dev/null 2>&1; true' 2>/dev/null && return 0; sleep 5; done
  echo "   no SSH on $1 after 5 minutes"; return 1
}
prepare_hosts() {
  local i pids=() rc=0
  for i in "${!NAMES[@]}"; do wait_vm "${ADDRS[$i]}" || return 1; done
  for i in "${!NAMES[@]}"; do
    { { host_script
        if [ "${ROLES[$i]}" = ctl ]; then link_script "${EXTMACS[$i]}" ""; fi
        if [ "$i" = 0 ]; then link_script "$GWMAC" "$EXT_GW/$EXT_PREFIX"; fi
        echo 'sudo networkctl reload; sleep 3'
      } | sshs "${ADDRS[$i]}" 'bash -s' > "$M/prepare-${NAMES[$i]}.log" 2>&1; } &
    pids+=($!)
  done
  for i in "${!pids[@]}"; do wait "${pids[$i]}" || { echo "   preparing ${NAMES[$i]} failed:"; tail -5 "$M/prepare-${NAMES[$i]}.log"; rc=1; }; done
  cat "$M"/prepare-*.log | grep -E '^   ' || true
  [ "$rc" = 0 ] || return 1
  sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get install -y -q git python3-dev python3-venv libffi-dev gcc libssl-dev libdbus-glib-1-dev >/dev/null 2>&1
  ip -br addr | grep -F "$EXT_GW/" | sed 's/^/   gateway of the lab network: /' || { echo "   $EXT_GW not configured on $CTL1"; return 1; }
}
install_kolla() {
  python3 -m venv "$VENV"
  "${PX[@]}" "$VENV/bin/pip" install -q -U pip
  "${PX[@]}" "$VENV/bin/pip" install -q "ansible-core==$ANSIBLE_CORE_VERSION" "kolla-ansible==$KOLLA_ANSIBLE_VERSION" docker dbus-python
  "${PX[@]}" "$VENV/bin/kolla-ansible" install-deps > "$M/install-deps.log" 2>&1 || { tail -5 "$M/install-deps.log"; return 1; }
  echo "   $("$VENV/bin/kolla-ansible" --version), ansible-core $ANSIBLE_CORE_VERSION"
}
iface_of() { sshn "$1" "ip -o link | awk -F': ' -v m='$2' 'tolower(\$0) ~ m {print \$2; exit}' | cut -d@ -f1"; }
configure() {
  sudo mkdir -p /etc/kolla/config && sudo chown -R "$USER": /etc/kolla
  cp "$VENV"/share/kolla-ansible/etc_examples/kolla/* /etc/kolla/
  "$VENV/bin/kolla-genpwd"
  # The inventory: Kolla-Ansible's multinode sample, with this lab's VMs in its first groups. Interface names are
  # host variables, read on each VM.
  local hosts="" i ifc ext
  for i in "${!NAMES[@]}"; do
    ifc=$(sshn "${ADDRS[$i]}" "ip -4 route show default | awk '{print \$5; exit}'")
    ext=""; [ "${ROLES[$i]}" = ctl ] && ext=" neutron_external_interface=$(iface_of "${ADDRS[$i]}" "${EXTMACS[$i]}")"
    hosts+="${NAMES[$i]} ${ROLES[$i]} ansible_host=${ADDRS[$i]} ansible_user=ubuntu ansible_become=true ansible_ssh_private_key_file=$LKEY network_interface=$ifc$ext"$'\n'
  done
  printf '%s' "$hosts" | python3 -c '
import re, sys
hosts = [l.split(" ", 2) for l in sys.stdin.read().splitlines()]
line = lambda h: h[0] + " " + h[2]
groups = {"control": [line(h) for h in hosts if h[1] == "ctl"], "compute": [line(h) for h in hosts if h[1] == "cmp"]}
groups["network"] = [h[0] for h in hosts if h[1] == "ctl"]; groups["monitoring"] = [hosts[0][0]]; groups["storage"] = []
src = open(sys.argv[1]).read().split("\n"); out = []; cur = None
for l in src:
    m = re.match(r"^\[([^\]:]+)\]$", l)
    if m: cur = m.group(1); out.append(l)
    if m and cur in groups: out.extend(groups[cur]); continue
    if not m and cur in groups and l and not l.startswith("#"): continue
    if not m: out.append(l)
open(sys.argv[2], "w").write("\n".join(out))' "$VENV/share/kolla-ansible/ansible/inventory/multinode" "$INV"
  # kvm when the computes offer nested virtualisation (checked on the first one), qemu otherwise.
  local virt=qemu cmp1_addr; cmp1_addr=$(awk -v n="$CMP1" '$1==n{print $3}' "$M/nodes")
  sshn "$cmp1_addr" '[ -e /dev/kvm ] && grep -qE "vmx|svm" /proc/cpuinfo' && virt=kvm
  local mtu; mtu=$(cat /sys/class/net/"$(ip -4 route show default | awk '{print $5; exit}')"/mtu)
  {
    echo "---"
    echo "# openstack-quick-lab: multinode, $CONTROLLERS controller(s). Generated by remote-deploy.sh."
    echo 'kolla_base_distro: "ubuntu"'
    echo 'kolla_container_engine: "docker"'
    if [ "$CONTROLLERS" = 1 ]; then
      echo '# One controller: no HAProxy, no keepalived, and no ProxySQL (it would take port 3306 from MariaDB).'
      echo 'enable_haproxy: "no"'
      echo 'enable_proxysql: "no"'
    else
      echo '# Three controllers: HAProxy and keepalived hold the VIP; VRRP in unicast, the cloud network may drop multicast.'
      echo 'keepalived_traffic_mode: "unicast"'
    fi
    echo "kolla_internal_vip_address: \"$VIP_ADDR\""
    echo 'neutron_plugin_agent: "openvswitch"'
    echo "nova_compute_virt_type: \"$virt\""
    echo 'docker_client_timeout: 600'
    if [ -n "$DOCKER_REGISTRY" ]; then
      echo "docker_registry: \"$DOCKER_REGISTRY\""; echo 'docker_registry_insecure: true'
      [ -n "$OPENSTACK_TAG" ] && echo "openstack_tag: \"$OPENSTACK_TAG\""
    fi
    if [ -n "$HTTPS_PROXY" ]; then
      echo "docker_http_proxy: \"$HTTPS_PROXY\""; echo "docker_https_proxy: \"$HTTPS_PROXY\""; echo "docker_no_proxy: \"$NOPX\""
      echo 'docker_apt_key_env:'; echo "  http_proxy: \"$HTTPS_PROXY\""; echo "  https_proxy: \"$HTTPS_PROXY\""
      echo "container_http_proxy: \"$HTTPS_PROXY\""; echo "container_https_proxy: \"$HTTPS_PROXY\""; echo "container_no_proxy: \"$NOPX\""
    fi
  } > /etc/kolla/globals.yml
  printf '[DEFAULT]\nglobal_physnet_mtu = %s\n' "$mtu" > /etc/kolla/config/neutron.conf
  echo "   $CONTROLLERS controller(s), $(grep -c ' cmp ' "$M/nodes") compute(s), VIP $VIP_ADDR, MTU $mtu, nova_compute_virt_type $virt"
  grep -E 'network_interface' "$INV" | sed 's/ansible_ssh_private_key_file=[^ ]* //; s/^/   /'
}
bootstrap() {
  kolla bootstrap-servers
  # Docker must run with its proxy before the first pull, on every VM.
  if [ -n "$HTTPS_PROXY" ]; then
    local a; for a in "${ADDRS[@]}"; do
      sshn "$a" 'sudo docker info 2>/dev/null | grep -q "HTTPS Proxy" || { sudo systemctl daemon-reload; sudo systemctl restart docker; sleep 5; sudo docker info 2>/dev/null | grep -q "HTTPS Proxy"; }' \
        || { echo "   Docker has no proxy on $a"; return 1; }
    done
  fi
}
prechecks()  { if [ -z "$DOCKER_REGISTRY" ]; then kolla prechecks --use-test-images; else kolla prechecks; fi; }
pull()       { kolla pull; }
deploy()     { kolla deploy; }
postdeploy() { kolla post-deploy; "${PX[@]}" "$VENV/bin/pip" install -q python-openstackclient; }
wait_ping() { for _ in $(seq 1 36); do ping -c 1 -W 2 "$1" >/dev/null && return 0; sleep 5; done; return 1; }
wait_ssh() {
  for _ in $(seq 1 18); do
    ssh -n -i ~/.ssh/id_ecdsa -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o BatchMode=yes -o ConnectTimeout=10 "cirros@$1" hostname 2>/dev/null && return 0
    sleep 10
  done; return 1
}
smoke_test() {
  # shellcheck source=/dev/null
  . /etc/kolla/admin-openrc.sh
  # init-runonce (Kolla-Ansible's demo set-up) runs only once
  openstack network show public1 >/dev/null 2>&1 || "${PX[@]}" env no_proxy="$NOPX" DEMO_NET_CIDR=10.98.0.0/24 DEMO_NET_GATEWAY=10.98.0.1 \
    EXT_NET_CIDR="$LAB_EXT_CIDR" EXT_NET_RANGE="start=$EXT_START,end=$EXT_END" EXT_NET_GATEWAY="$EXT_GW" \
    "$VENV/share/kolla-ansible/init-runonce" > "$M/init-runonce.log" 2>&1 || { tail -5 "$M/init-runonce.log"; return 1; }
  local hosts n=0 h s fip t0 lost
  mapfile -t hosts < <(openstack compute service list --service nova-compute -f value -c Host | sort)
  echo "   computes: ${hosts[*]}"
  for h in "${hosts[@]}"; do
    n=$((n+1)); s="demo$n"
    openstack server show "$s" >/dev/null 2>&1 || openstack server create --image cirros --flavor m1.tiny --key-name mykey --network demo-net \
      --availability-zone "nova:$h" --wait "$s" -f value -c status >/dev/null
    fip=$(openstack floating ip list --port "$(openstack port list --server "$s" -f value -c ID | head -1)" -f value -c "Floating IP Address" | head -1)
    if [ -z "$fip" ]; then fip=$(openstack floating ip create public1 -f value -c floating_ip_address); openstack server add floating ip "$s" "$fip"; fi
    wait_ping "$fip" || { echo "   $s ($h): no ping on $fip"; return 1; }
    wait_ssh "$fip" >/dev/null || { echo "   $s ($h): no SSH on $fip"; return 1; }
    echo "   $s on $(openstack server show "$s" -f value -c OS-EXT-SRV-ATTR:host), floating IP $fip: ping and SSH"
  done
  [ "${#hosts[@]}" -ge 2 ] || return 0
  # Live migration of demo1 to another compute, with a ping running.
  s=demo1; h=$(openstack server show "$s" -f value -c OS-EXT-SRV-ATTR:host)
  fip=$(openstack server show "$s" -f json -c addresses | python3 -c 'import json,sys; print([a for v in json.load(sys.stdin)["addresses"].values() for a in v][-1])')
  ping -i 0.2 "$fip" > "$M/migration-ping.log" 2>&1 & local pp=$!
  t0=$(date +%s)
  openstack server migrate --live-migration --wait "$s" >/dev/null || { kill "$pp"; echo "   live migration of $s failed"; openstack server show "$s" -f value -c status -c fault; return 1; }
  sleep 2; kill -INT "$pp"; wait "$pp" 2>/dev/null || true
  lost=$(grep -oE '[0-9]+ packets transmitted, [0-9]+ received' "$M/migration-ping.log")
  echo "   $s live-migrated from $h to $(openstack server show "$s" -f value -c OS-EXT-SRV-ATTR:host) in $(( $(date +%s)-t0 )) s; ping every 0.2 s: $lost"
  [ "$(openstack server show "$s" -f value -c OS-EXT-SRV-ATTR:host)" != "$h" ] || { echo "   $s did not move"; return 1; }
  wait_ssh "$fip" >/dev/null && echo "   SSH into $s after the migration: ok" || { echo "   no SSH into $s after the migration"; return 1; }
}

T0=$(date +%s)
step prepare    "Prepare every VM"                     prepare_hosts
step kolla      "Install Kolla-Ansible on $CTL1"       install_kolla
step configure  "Write the configuration"              configure
step bootstrap  "kolla-ansible bootstrap-servers"      bootstrap
step prechecks  "kolla-ansible prechecks"              prechecks
step pull       "kolla-ansible pull"                   pull
step deploy     "kolla-ansible deploy"                 deploy
step postdeploy "kolla-ansible post-deploy, client"    postdeploy
step smoke      "Smoke test: an instance on each compute, ping and SSH, a live migration" smoke_test
echo "== OpenStack is ready ($(( $(date +%s)-T0 )) s for this run). On $CTL1: source ~/kolla-venv/bin/activate; . /etc/kolla/admin-openrc.sh"
