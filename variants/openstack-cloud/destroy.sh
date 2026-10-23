#!/usr/bin/env bash
# Delete everything create.sh created for this lab, after confirmation. Safe to run again: what is already gone is
# skipped. Exits non-zero if anything could not be deleted.
. "$(dirname "$0")/lib.sh"
load
# Find each resource from the IDs recorded by create.sh, and by its name in case the state was lost or the creation
# stopped half-way.
find_id() { os "$@" -f value -c id 2>/dev/null || true; }
SERVER="${SERVER:-$(find_id server show "$VM")}"
ROOT_VOLUME="${BOOT_VOLUME_ID:-$(find_id volume show "${VM}-root")}"
PORT="${PORT:-$(find_id port show "${VM}-port")}"
SG="${SG:-$(find_id security group show "${VM}-sg")}"
KEYPAIR="${KEYPAIR:-$(os keypair show "${VM}-key" -f value -c name 2>/dev/null || true)}"
FIP_ID="${FIP_ID:-$(os floating ip list --long -f value -c ID -c Description 2>/dev/null | awk -v d="$VM" '$2==d{print $1}' | head -1)}"
echo "About to delete, in cloud '$OS_CLOUD':"
[ -n "$SERVER" ]      && echo "  server         $VM ($SERVER)"
[ -n "$ROOT_VOLUME" ] && echo "  root volume    ${VM}-root ($ROOT_VOLUME)"
[ -n "$FIP_ID" ]      && echo "  floating IP    $FIP_ID"
[ -n "$PORT" ]        && echo "  port           ${VM}-port ($PORT)"
[ -n "$SG" ]          && echo "  security group ${VM}-sg ($SG)"
[ -n "$KEYPAIR" ]     && echo "  key pair       $KEYPAIR"
if [ -z "$SERVER$ROOT_VOLUME$FIP_ID$PORT$SG$KEYPAIR" ]; then echo "  nothing: no resource of $VM found."; rm -rf "$STATE_DIR"; exit 0; fi
echo "Everything inside the VM (the whole OpenStack lab) is lost."
confirm "Delete all of it?"

FAILED=0
del() { # del <what> <openstack args...>: delete, treat "not found" as already done, record any other failure
  local what=$1 out; shift; say "$what"
  if ! out=$(os "$@" 2>&1); then
    if printf '%s' "$out" | grep -qiE 'no .* (found|exists)|not found|could not be found|HTTP 404'; then echo "  already gone"
    else printf '  FAILED: %s\n' "$out" | tail -3; FAILED=1; fi
  fi
}
T0=$(date +%s)
[ -n "$FIP_ID" ] && del "Floating IP" floating ip delete "$FIP_ID"
[ -n "$SERVER" ] && del "Server" server delete --wait "$SERVER"
if [ -n "$ROOT_VOLUME" ]; then  # wait until the server has released it
  for _ in $(seq 1 30); do st=$(os volume show "$ROOT_VOLUME" -f value -c status 2>/dev/null || echo gone); [ "$st" = available ] || [ "$st" = error ] || [ "$st" = gone ] && break; sleep 5; done
  del "Root volume" volume delete "$ROOT_VOLUME"
  for _ in $(seq 1 24); do os volume show "$ROOT_VOLUME" >/dev/null 2>&1 || break; sleep 5; done  # deletion is asynchronous
fi
[ -n "$PORT" ]    && del "Port" port delete "$PORT"
[ -n "$SG" ]      && del "Security group" security group delete "$SG"
[ -n "$KEYPAIR" ] && del "Key pair" keypair delete "$KEYPAIR"

say "Checking that nothing is left"
sleep 5
LEFT=$( { os server list --name "^${VM}\$" -f value -c ID -c Name
          os volume list --name "${VM}-root" -f value -c ID -c Name -c Status
          [ -n "$ROOT_VOLUME" ] && os volume show "$ROOT_VOLUME" -f value -c id -c status 2>/dev/null
          os port list --name "${VM}-port" -f value -c ID -c Name
          os security group list -f value -c ID -c Name | awk -v n="${VM}-sg" '$2==n'
          os keypair list -f value -c Name | grep -x "${VM}-key"
          os floating ip list --long -f value -c ID -c Description | awk -v d="$VM" '$2==d'; } 2>/dev/null || true)
if [ -n "$LEFT" ]; then echo "STILL PRESENT in the cloud (and possibly billed):"; echo "$LEFT"; exit 1; fi
[ "$FAILED" = 0 ] || { echo "Some deletions failed (see above). Run ./destroy.sh again."; exit 1; }
say "Deleted in $(( $(date +%s)-T0 )) s. Nothing of $VM is left in the cloud."
rm -rf "$STATE_DIR"
