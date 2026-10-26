#!/usr/bin/env bash
# Deploy OpenStack (Kolla-Ansible, all-in-one) on the lab VM created by create.sh. Takes about an hour.
# Safe to run again after a failure, or after a dropped connection: the steps already done are skipped, and a run in
# progress on the VM is followed rather than started again.
. "$(dirname "$0")/lib.sh"
load; [ -n "${VM_ADDRESS:-}" ] || die "No lab found for $VM: run ./create.sh first."
say "Deploying on $VM ($VM_ADDRESS). Output also in $LOG"
SCP=(scp -q -i "$KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts")
# The deploy runs on the VM under nohup, so that it survives a dropped SSH connection; this script only follows its
# log. If the connection drops, run ./deploy.sh again: it follows the run in progress instead of starting another.
running() { ssh_vm '[ -f ~/.quicklab/run.pid ] && kill -0 "$(cat ~/.quicklab/run.pid)" 2>/dev/null'; }
if running; then
  say "A deploy is already running on $VM: following it."
else
  ssh_vm 'mkdir -p ~/.quicklab'; "${SCP[@]}" "$HERE/remote-deploy.sh" "$SSH_USER@$VM_ADDRESS:remote-deploy.sh"
  for v in KOLLA_ANSIBLE_VERSION ANSIBLE_CORE_VERSION LAB_EXT_CIDR HTTPS_PROXY NTP_SERVER APT_HTTPS DOCKER_REGISTRY OPENSTACK_TAG; do printf 'export %s=%q\n' "$v" "${!v:-}"; done > "$STATE_DIR/remote.env"; chmod 600 "$STATE_DIR/remote.env"
  "${SCP[@]}" "$STATE_DIR/remote.env" "$SSH_USER@$VM_ADDRESS:.quicklab/remote.env"
  ssh_vm 'rm -f ~/.quicklab/run.rc; nohup bash -c ". ~/.quicklab/remote.env; bash ~/remote-deploy.sh; echo \$? > ~/.quicklab/run.rc" > ~/.quicklab/run.log 2>&1 < /dev/null & echo $! > ~/.quicklab/run.pid'
fi
# Not stopped by set -e or pipefail here: the exit code of the remote run decides the message below.
set +e
ssh_vm 'tail -n +1 --pid="$(cat ~/.quicklab/run.pid)" -f ~/.quicklab/run.log' 2>&1 | tee -a "$LOG"
rc=$(ssh_vm 'cat ~/.quicklab/run.rc 2>/dev/null')
set -e
if [ -z "$rc" ]; then
  say "Lost the connection to $VM, or the deploy is still running there. Run ./deploy.sh again to follow it."
  exit 2
fi
if [ "$rc" = 0 ]; then
  say "Done. Log in with: ssh -i $KEY $SSH_USER@$VM_ADDRESS   Remember: ./destroy.sh when you are done."
  say "Horizon: ssh -i $KEY -N -L 8080:$VM_FIXED_ADDRESS:80 $SSH_USER@$VM_ADDRESS   then open http://localhost:8080 (user admin; password: see the guide)"
else say "deploy failed (exit $rc); fix the cause and run ./deploy.sh again."; fi
exit "$rc"
