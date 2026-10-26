#!/usr/bin/env bash
# Deploy OpenStack (Kolla-Ansible, multinode) on the VMs created by create.sh, from controller 1 as the deploy host.
# Takes about an hour: 57 to 62 minutes measured with 3 VMs, 66 to 69 with 5 (2026-10-25). Safe to run again after a
# failure, or after a dropped connection: the steps already done are skipped, and a run in progress on controller 1
# is followed rather than started again.
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
# The deploy runs on the VM under nohup, so that it survives a dropped SSH connection; this script only follows its
# log. If the connection drops, run ./deploy.sh again: it follows the run in progress instead of starting another.
running() { ssh_ctl '[ -f ~/.quicklab/run.pid ] && kill -0 "$(cat ~/.quicklab/run.pid)" 2>/dev/null'; }
if running; then
  say "A deploy is already running on $CTL1: following it."
else
  ssh_ctl 'mkdir -p ~/.quicklab && chmod 700 ~/.ssh'
  "${SCP[@]}" "$HERE/remote-deploy.sh" "$SSH_USER@$CTL_ADDRESS:remote-deploy.sh"
  "${SCP[@]}" "$NODEFILE" "$SSH_USER@$CTL_ADDRESS:.quicklab/nodes"
  # The lab's private key, so that controller 1 reaches the other VMs (Ansible). It never leaves the lab.
  "${SCP[@]}" "$KEY" "$SSH_USER@$CTL_ADDRESS:.ssh/quicklab_ed25519"
  for v in KOLLA_ANSIBLE_VERSION ANSIBLE_CORE_VERSION LAB_EXT_CIDR EXT_GW EXT_PREFIX GWMAC VIP CONTROLLERS HTTPS_PROXY NTP_SERVER APT_HTTPS DOCKER_REGISTRY OPENSTACK_TAG; do printf 'export %s=%q\n' "$v" "${!v:-}"; done > "$STATE_DIR/remote.env"; chmod 600 "$STATE_DIR/remote.env"
  "${SCP[@]}" "$STATE_DIR/remote.env" "$SSH_USER@$CTL_ADDRESS:.quicklab/remote.env"
  ssh_ctl 'rm -f ~/.quicklab/run.rc; nohup bash -c ". ~/.quicklab/remote.env; bash ~/remote-deploy.sh; echo \$? > ~/.quicklab/run.rc" > ~/.quicklab/run.log 2>&1 < /dev/null & echo $! > ~/.quicklab/run.pid'
fi
# Not stopped by set -e or pipefail here: the exit code of the remote run decides the message below.
set +e
ssh_ctl 'tail -n +1 --pid="$(cat ~/.quicklab/run.pid)" -f ~/.quicklab/run.log' 2>&1 | tee -a "$LOG"
rc=$(ssh_ctl 'cat ~/.quicklab/run.rc 2>/dev/null')
set -e
if [ -z "$rc" ]; then
  say "Lost the connection to $CTL1, or the deploy is still running there. Run ./deploy.sh again to follow it."
  exit 2
fi
if [ "$rc" = 0 ]; then
  say "Done. Log in to controller 1 with: ssh -i $KEY $SSH_USER@$CTL_ADDRESS   Remember: ./destroy.sh when you are done."
  say "Horizon: ssh -i $KEY -N -L 8080:${VIP:-$(get ADDR "$CTL1")}:80 $SSH_USER@$CTL_ADDRESS   then open http://localhost:8080 (user admin)"
else say "deploy failed (exit $rc); fix the cause and run ./deploy.sh again."; fi
exit "$rc"
