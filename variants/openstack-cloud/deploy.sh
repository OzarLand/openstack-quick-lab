#!/usr/bin/env bash
# Deploy OpenStack (Kolla-Ansible, all-in-one) on the lab VM created by create.sh. Takes about an hour.
# Safe to run again after a failure: the steps already done are skipped.
. "$(dirname "$0")/lib.sh"
load; [ -n "${VM_ADDRESS:-}" ] || die "No lab found for $VM: run ./create.sh first."
say "Deploying on $VM ($VM_ADDRESS). Output also in $LOG"
scp -q -i "$KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts" "$HERE/remote-deploy.sh" "$SSH_USER@$VM_ADDRESS:remote-deploy.sh"
ssh_vm "KOLLA_ANSIBLE_VERSION='$KOLLA_ANSIBLE_VERSION' ANSIBLE_CORE_VERSION='$ANSIBLE_CORE_VERSION' LAB_EXT_CIDR='$LAB_EXT_CIDR' \
  HTTPS_PROXY='$HTTPS_PROXY' NTP_SERVER='$NTP_SERVER' APT_HTTPS='$APT_HTTPS' DOCKER_REGISTRY='$DOCKER_REGISTRY' OPENSTACK_TAG='$OPENSTACK_TAG' \
  bash remote-deploy.sh" 2>&1 | tee -a "$LOG"
rc=${PIPESTATUS[0]}
[ "$rc" = 0 ] && say "Done. Log in with: ssh -i $KEY $SSH_USER@$VM_ADDRESS   Remember: ./destroy.sh when you are done." || say "deploy failed (exit $rc); fix the cause and run ./deploy.sh again."
exit "$rc"
