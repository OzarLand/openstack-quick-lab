#!/usr/bin/env bash
# Delete everything create.sh created for this lab, after confirmation. Finds every resource by its name (all start
# with "${PREFIX}${LAB}-"), so it works even if the creation stopped half-way or .state/ was lost. Safe to run again.
# Exits non-zero if anything could not be deleted or is still there at the end.
. "$(dirname "$0")/lib.sh"
load
# Everything is found by its name prefix: refuse a prefix that could match resources that are not the lab's.
[ -n "$PREFIX" ] || die "PREFIX is empty in config.env: destroy.sh finds the lab's resources by \"\${PREFIX}\${LAB}-\", and refuses an empty PREFIX."
[ "${#LABNAME}" -ge 4 ] || die "\${PREFIX}\${LAB} is \"$LABNAME\", shorter than 4 characters: too likely to match resources that are not the lab's."
os token issue -f value -c expires >/dev/null || die "Cannot authenticate with OS_CLOUD=$OS_CLOUD: nothing deleted, $STATE_DIR kept."
P="${LABNAME}-"
mine() { awk -v p="$P" 'index($2, p) == 1'; }   # rows "<id> <name> ..." whose name starts with the lab's prefix
# lst <what> <openstack args...>: a listing that must succeed. Each call is a plain assignment at the top level, so
# that set -e stops the script when it fails (a failure inside a pipeline or a $(...) group would not).
lst() { local what=$1 out; shift; out=$(os "$@" 2>&1) || die "Could not list the $what: $(printf '%s' "$out" | tail -1). Nothing more deleted, $STATE_DIR kept."; printf '%s\n' "$out"; }
inventory() { # fills the lists below with the lab's rows; stops the script if a listing fails
  A_SERVERS=$(lst servers server list -f value -c ID -c Name)
  A_FIPS=$(lst "floating IPs" floating ip list --long -f value -c ID -c Description)
  A_VOLUMES=$(lst volumes volume list -f value -c ID -c Name -c Status)
  A_PORTS=$(lst ports port list -f value -c ID -c Name)
  A_SUBNETS=$(lst subnets subnet list -f value -c ID -c Name)
  A_NETS=$(lst networks network list -f value -c ID -c Name)
  A_SGS=$(lst "security groups" security group list -f value -c ID -c Name)
  A_KEYS=$(lst "key pairs" keypair list -f value -c Name)
  SERVERS=$(printf '%s\n' "$A_SERVERS" | mine); FIPS=$(printf '%s\n' "$A_FIPS" | awk -v d="$LABNAME" '$2==d')
  VOLUMES=$(printf '%s\n' "$A_VOLUMES" | mine); PORTS=$(printf '%s\n' "$A_PORTS" | mine)
  SUBNETS=$(printf '%s\n' "$A_SUBNETS" | mine); NETS=$(printf '%s\n' "$A_NETS" | mine)
  SGS=$(printf '%s\n' "$A_SGS" | mine); KEYS=$(printf '%s\n' "$A_KEYS" | awk -v k="${LABNAME}-key" '$1==k')
}
inventory
show() { [ -n "$2" ] && printf '%s\n' "$2" | awk -v w="$1" '{printf "  %-15s %s (%s)\n", w, $2, $1}'; return 0; }
echo "About to delete, in cloud '$OS_CLOUD', everything named ${P}*:"
show server "$SERVERS"; show "floating IP" "$FIPS"; show volume "$VOLUMES"; show port "$PORTS"; show subnet "$SUBNETS"
show network "$NETS"; show "security group" "$SGS"; [ -n "$KEYS" ] && echo "  key pair        $KEYS"
if [ -z "$SERVERS$FIPS$VOLUMES$PORTS$SUBNETS$NETS$SGS$KEYS" ]; then echo "  nothing: no resource of $LABNAME found."; rm -rf "$STATE_DIR"; exit 0; fi
echo "Everything inside the VMs (the whole OpenStack lab) is lost."
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
while read -r id _; do [ -n "$id" ] && del "Floating IP $id" floating ip delete "$id"; done <<<"$FIPS"
[ -n "$SERVERS" ] && del "Servers" server delete --wait $(awk '{print $1}' <<<"$SERVERS")
while read -r id name; do
  [ -n "$id" ] || continue
  for _ in $(seq 1 30); do st=$(os volume show "$id" -f value -c status 2>/dev/null || echo gone); [ "$st" = available ] || [ "$st" = error ] || [ "$st" = gone ] && break; sleep 5; done
  del "Volume $name" volume delete "$id"
done <<<"$VOLUMES"
while read -r id name; do [ -n "$id" ] && del "Port $name" port delete "$id"; done <<<"$PORTS"
while read -r id name; do [ -n "$id" ] && del "Subnet $name" subnet delete "$id"; done <<<"$SUBNETS"
while read -r id name; do [ -n "$id" ] && del "Network $name" network delete "$id"; done <<<"$NETS"
while read -r id name; do [ -n "$id" ] && del "Security group $name" security group delete "$id"; done <<<"$SGS"
[ -n "$KEYS" ] && del "Key pair $KEYS" keypair delete "$KEYS"

say "Checking that nothing is left"
for _ in $(seq 1 24); do inventory; [ -z "$VOLUMES" ] && break; sleep 5; done  # volume deletion is asynchronous
# The listings of inventory must all have succeeded: a failed listing is not "nothing left".
LEFT=$(printf '%s\n' "$SERVERS" "$FIPS" "$VOLUMES" "$PORTS" "$SUBNETS" "$NETS" "$SGS" "$KEYS" | awk 'NF')
if [ -n "$LEFT" ]; then echo "STILL PRESENT in the cloud (and possibly billed):"; echo "$LEFT"; exit 1; fi
[ "$FAILED" = 0 ] || { echo "Some deletions failed (see above). Run ./destroy.sh again."; exit 1; }
say "Deleted in $(( $(date +%s)-T0 )) s. Nothing of $LABNAME is left in the cloud."
rm -rf "$STATE_DIR"
