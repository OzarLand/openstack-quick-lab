# shellcheck shell=bash
# Common functions of the openstack-quick-lab scripts (sourced, not run).
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "$HERE/config.env" ] || { echo "Missing $HERE/config.env: copy config.example.env to config.env and fill it in." >&2; exit 1; }
# shellcheck source=/dev/null
. "$HERE/config.env"
export OS_CLOUD
VM="${PREFIX}${LAB}"
STATE_DIR="$HERE/.state/${VM}"
STATE="$STATE_DIR/state.env"
KEY="$STATE_DIR/id_ed25519"
LOG="$STATE_DIR/log.txt"

say()  { printf '%s %s\n' "$(date -u +%H:%M:%S)" "$*" | tee -a "${LOG:-/dev/null}"; }
die()  { echo "ERROR: $*" >&2; exit 1; }
need() { command -v "$1" >/dev/null || die "'$1' is required. $2"; }
confirm() { local a; read -r -p "$1 [y/N] " a; [ "$a" = y ] || [ "$a" = Y ] || { echo "Cancelled."; exit 1; }; }
os() { openstack "$@"; }
save() { # save <KEY> <value>: keeps the last non-empty line of the value (some client commands print a blank line first)
  local v; v=$(printf '%s\n' "$2" | tr -d '\r' | awk 'NF' | tail -1)
  mkdir -p "$STATE_DIR"; touch "$STATE"; grep -v "^$1=" "$STATE" > "$STATE.tmp" || true; echo "$1=$v" >> "$STATE.tmp"; mv "$STATE.tmp" "$STATE"; }
load() { [ -f "$STATE" ] && . "$STATE" || true; }
ssh_vm() { ssh -i "$KEY" -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile="$STATE_DIR/known_hosts" -o ConnectTimeout=10 -o ServerAliveInterval=30 "$SSH_USER@$VM_ADDRESS" "$@"; }
