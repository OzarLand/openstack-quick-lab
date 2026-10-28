# shellcheck shell=bash
# Common functions of the multinode variant (sourced, not run). Same rules and helpers as ../openstack-cloud/lib.sh,
# for a lab of several VMs: CONTROLLERS controllers (1 or 3) and COMPUTES computes.
set -euo pipefail
# Needs bash 4.4 or later (empty arrays under set -u). macOS ships bash 3.2: install a newer bash.
if [ "${BASH_VERSINFO[0]}" -lt 4 ] || { [ "${BASH_VERSINFO[0]}" -eq 4 ] && [ "${BASH_VERSINFO[1]}" -lt 4 ]; }; then
  echo "These scripts need bash 4.4 or later (this is $BASH_VERSION)." >&2; exit 1
fi
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/config.env" ] || { echo "Missing $HERE/config.env: copy config.example.env to config.env and fill it in." >&2; exit 1; }
# shellcheck source=/dev/null
. "$HERE/config.env"
export OS_CLOUD
CONTROLLERS="${CONTROLLERS:-1}"; COMPUTES="${COMPUTES:-2}"
case "$CONTROLLERS" in 1|3) ;; *) echo "CONTROLLERS must be 1 or 3 (it is $CONTROLLERS)." >&2; exit 1 ;; esac
case "$COMPUTES" in 1|2|3|4) ;; *) echo "COMPUTES must be between 1 and 4 (it is $COMPUTES)." >&2; exit 1 ;; esac
LABNAME="${PREFIX}${LAB}"
# destroy.sh deletes every resource of the project whose name starts with "${LABNAME}-": a prefix shared with
# other resources would delete them too. Refuse a prefix that does not start with "quicklab", unless the user says so.
case "$PREFIX" in
  quicklab*) ;;
  *) [ "${ALLOW_ANY_PREFIX:-}" = yes ] || { echo "PREFIX must start with \"quicklab\" (it is \"$PREFIX\"): destroy.sh deletes everything named \"\${PREFIX}\${LAB}-*\" in the project. Set ALLOW_ANY_PREFIX=yes in config.env only if no other resource of the project can start with that name." >&2; exit 1; } ;;
esac
CTLS=(); for i in $(seq 1 "$CONTROLLERS"); do CTLS+=("${LABNAME}-ctl-$i"); done
CMPS=(); for i in $(seq 1 "$COMPUTES"); do CMPS+=("${LABNAME}-cmp-$i"); done
NODES=("${CTLS[@]}" "${CMPS[@]}")
CTL1="${CTLS[0]}"
STATE_DIR="$HERE/.state/${LABNAME}"
STATE="$STATE_DIR/state.env"
KEY="$STATE_DIR/id_ed25519"
LOG="$STATE_DIR/log.txt"

say()  { mkdir -p "$STATE_DIR"; printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "$LOG"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "'$1' is required. $2"; }
confirm() { local a; read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ] || { echo "Cancelled."; exit 1; }; }
os() { openstack "$@"; }
save() { # save <KEY> <value>: keeps the last non-empty line of the value (some client commands print a blank line first)
  local v; v=$(printf '%s\n' "$2" | tr -d '\r' | awk 'NF' | tail -1)
  mkdir -p "$STATE_DIR"; touch "$STATE"; grep -v "^$1=" "$STATE" > "$STATE.tmp" || true; echo "$1=$v" >> "$STATE.tmp"; mv "$STATE.tmp" "$STATE"; }
load() { [ -f "$STATE" ] && . "$STATE" || true; }
sid() { local s="${1#"${LABNAME}"-}"; printf '%s' "${s//-/_}"; }   # sid <node>: its short id in state.env (ctl_1, cmp_2)
get() { local v="$1_$(sid "$2")"; printf '%s' "${!v:-}"; }          # get <FIELD> <node>: a value saved for that node
ssh_ctl() { ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts" -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER@$CTL_ADDRESS" "$@"; }
