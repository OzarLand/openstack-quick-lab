#!/usr/bin/env bash
# Delete everything create.sh created for this lab, after confirmation.
. "$(dirname "$0")/lib.sh"
load
# What to delete: the IDs recorded by create.sh, and anything left with this lab's names (in case the state was lost).
SERVER="${SERVER:-$(os server show "$VM" -f value -c id 2>/dev/null || true)}"
PORT="${PORT:-$(os port show "${VM}-port" -f value -c id 2>/dev/null || true)}"
SG="${SG:-$(os security group show "${VM}-sg" -f value -c id 2>/dev/null || true)}"
KEYPAIR="${KEYPAIR:-$(os keypair show "${VM}-key" -f value -c name 2>/dev/null || true)}"
FIP_ID="${FIP_ID:-$(os floating ip list --long -f value -c ID -c Description | awk -v d="$VM" '$2==d{print $1}' | head -1)}"
BOOT_VOLUME_ID="${BOOT_VOLUME_ID:-}"
echo "About to delete, in cloud '$OS_CLOUD':"
[ -n "$SERVER" ]         && echo "  server         $VM ($SERVER)"
[ -n "$BOOT_VOLUME_ID" ] && echo "  boot volume    $BOOT_VOLUME_ID"
[ -n "$FIP_ID" ]         && echo "  floating IP    $FIP_ID"
[ -n "$PORT" ]           && echo "  port           ${VM}-port ($PORT)"
[ -n "$SG" ]             && echo "  security group ${VM}-sg ($SG)"
[ -n "$KEYPAIR" ]        && echo "  key pair       $KEYPAIR"
if [ -z "$SERVER$FIP_ID$PORT$SG$KEYPAIR$BOOT_VOLUME_ID" ]; then echo "  nothing: no resource of $VM found."; rm -rf "$STATE_DIR"; exit 0; fi
echo "Everything inside the VM (the whole OpenStack lab) is lost."
confirm "Delete all of it?"
T0=$(date +%s)
[ -n "$FIP_ID" ]  && { say "Floating IP";  os floating ip delete "$FIP_ID"; }
[ -n "$SERVER" ]  && { say "Server";       os server delete --wait "$SERVER"; }
[ -n "$BOOT_VOLUME_ID" ] && { say "Boot volume"; for _ in $(seq 1 30); do os volume delete "$BOOT_VOLUME_ID" 2>/dev/null && break; sleep 5; done; }
[ -n "$PORT" ]    && { say "Port";         os port delete "$PORT" 2>/dev/null || true; }
[ -n "$SG" ]      && { say "Security group"; os security group delete "$SG"; }
[ -n "$KEYPAIR" ] && { say "Key pair";     os keypair delete "$KEYPAIR"; }
say "Checking that nothing is left"
LEFT=$( { os server list --name "^${VM}\$" -f value -c ID; os port list --name "${VM}-port" -f value -c ID; os security group list -f value -c Name | grep -x "${VM}-sg"; os keypair list -f value -c Name | grep -x "${VM}-key"; } 2>/dev/null || true)
[ -n "$LEFT" ] && { echo "Still present:"; echo "$LEFT"; exit 1; }
say "Deleted in $(( $(date +%s)-T0 )) s. Nothing of $VM is left in the cloud."
rm -rf "$STATE_DIR"
