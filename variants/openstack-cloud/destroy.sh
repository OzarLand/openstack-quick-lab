#!/usr/bin/env bash
# Delete everything create.sh created for this lab, after confirmation. Safe to run again: what is already gone is
# skipped. Fails closed: if the cloud cannot be reached or a listing fails, it stops with a non-zero exit, deletes
# nothing more, and keeps .state/ (with the lab's private key). Exits non-zero if anything is left.
. "$(dirname "$0")/lib.sh"
load
os token issue -f value -c expires >/dev/null || die "Cannot authenticate with OS_CLOUD=$OS_CLOUD: nothing deleted, $STATE_DIR kept."
# lst <what> <openstack args...>: a listing that must succeed. Each call is a plain assignment at the top level, so
# that set -e stops the script when it fails (a failure inside a pipeline or a $(...) group would not).
lst() { local what=$1 out; shift; out=$(os "$@" 2>&1) || die "Could not list the $what: $(printf '%s' "$out" | tail -1). Nothing more deleted, $STATE_DIR kept."; printf '%s\n' "$out"; }
first() { awk -v k="$1" -v c="$2" '$c==k && !f {print $1; f=1}'; }   # first <name> <column>: ID of the first row named so
inventory() { # fills SERVERS VOLUMES PORTS SGS KEYS FIPS with the lab's rows; stops the script if a listing fails
  SERVERS=$(lst servers server list --name "^${VM}\$" -f value -c ID -c Name)
  VOLUMES=$(lst volumes volume list -f value -c ID -c Name -c Status)
  PORTS=$(lst ports port list --name "${VM}-port" -f value -c ID -c Name)
  SGS=$(lst "security groups" security group list -f value -c ID -c Name)
  KEYS=$(lst "key pairs" keypair list -f value -c Name)
  FIPS=$(lst "floating IPs" floating ip list --long -f value -c ID -c Description)
}
# Find each resource by its name: it works even if the state was lost or the creation stopped half-way.
inventory
SERVER=$(printf '%s\n' "$SERVERS" | first "$VM" 2)
ROOT_VOLUME=$(printf '%s\n' "$VOLUMES" | first "${VM}-root" 2)
PORT=$(printf '%s\n' "$PORTS" | first "${VM}-port" 2)
SG=$(printf '%s\n' "$SGS" | first "${VM}-sg" 2)
KEYPAIR=$(printf '%s\n' "$KEYS" | awk -v n="${VM}-key" '$1==n && !f {print; f=1}')
FIP_ID=$(printf '%s\n' "$FIPS" | first "$VM" 2)
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
# Every listing must succeed again: a failed listing is not "nothing left".
inventory
LEFT=$( { printf '%s\n' "$SERVERS" | awk -v n="$VM" '$2==n'
          printf '%s\n' "$VOLUMES" | awk -v n="${VM}-root" '$2==n'
          printf '%s\n' "$PORTS" | awk -v n="${VM}-port" '$2==n'
          printf '%s\n' "$SGS" | awk -v n="${VM}-sg" '$2==n'
          printf '%s\n' "$KEYS" | awk -v n="${VM}-key" '$1==n'
          printf '%s\n' "$FIPS" | awk -v d="$VM" '$2==d'; } )
if [ -n "$LEFT" ]; then echo "STILL PRESENT in the cloud (and possibly billed):"; echo "$LEFT"; exit 1; fi
[ "$FAILED" = 0 ] || { echo "Some deletions failed (see above). Run ./destroy.sh again."; exit 1; }
say "Deleted in $(( $(date +%s)-T0 )) s. Nothing of $VM is left in the cloud."
rm -rf "$STATE_DIR"
