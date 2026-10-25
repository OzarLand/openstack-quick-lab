#!/usr/bin/env bash
# Deploy OpenStack (Kolla-Ansible, multinode) on the VMs created by create.sh, from controller 1 as the deploy host.
# Takes about an hour and a half. Safe to run again after a failure: the steps already done are skipped.
. "$(dirname "$0")/lib.sh"
load; [ -n "${CTL_ADDRESS:-}" ] || die "No lab found for $LABNAME: run ./create.sh first."
say "Deploying on $LABNAME from $CTL1 ($CTL_ADDRESS). Output also in $LOG"
# The node list for controller 1: name, role, address on NETWORK, MAC of the port on the lab network (controllers).
NODEFILE="$STATE_DIR/nodes"; : > "$NODEFILE"
for n in "${NODES[@]}"; do
  case "$n" in *-ctl-*) r=ctl ;; *) r=cmp ;; esac
  m=$(get EXTMAC "$n"); echo "$n $r $(get ADDR "$n") ${m:--}" >> "$NODEFILE"
done
SCP=(scp -q -i "$KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts")
ssh_ctl 'mkdir -p ~/.quicklab && chmod 700 ~/.ssh'
"${SCP[@]}" "$HERE/remote-deploy.sh" "$SSH_USER@$CTL_ADDRESS:remote-deploy.sh"
"${SCP[@]}" "$NODEFILE" "$SSH_USER@$CTL_ADDRESS:.quicklab/nodes"
# The lab's private key, so that controller 1 reaches the other VMs (Ansible). It never leaves the lab.
"${SCP[@]}" "$KEY" "$SSH_USER@$CTL_ADDRESS:.ssh/quicklab_ed25519"
# Not stopped by set -e or pipefail here: the exit code of the remote run decides the message below.
set +e
ssh_ctl "KOLLA_ANSIBLE_VERSION='$KOLLA_ANSIBLE_VERSION' ANSIBLE_CORE_VERSION='$ANSIBLE_CORE_VERSION' LAB_EXT_CIDR='$LAB_EXT_CIDR' \
  EXT_GW='$EXT_GW' EXT_PREFIX='$EXT_PREFIX' GWMAC='$GWMAC' VIP='${VIP:-}' CONTROLLERS='$CONTROLLERS' \
  HTTPS_PROXY='$HTTPS_PROXY' NTP_SERVER='$NTP_SERVER' APT_HTTPS='$APT_HTTPS' DOCKER_REGISTRY='$DOCKER_REGISTRY' OPENSTACK_TAG='$OPENSTACK_TAG' \
  bash remote-deploy.sh" 2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
set -e
if [ "$rc" = 0 ]; then
  say "Done. Log in to controller 1 with: ssh -i $KEY $SSH_USER@$CTL_ADDRESS   Remember: ./destroy.sh when you are done."
  say "Horizon: ssh -i $KEY -N -L 8080:${VIP:-$(get ADDR "$CTL1")}:80 $SSH_USER@$CTL_ADDRESS   then open http://localhost:8080 (user admin)"
else say "deploy failed (exit $rc); fix the cause and run ./deploy.sh again."; fi
exit "$rc"
