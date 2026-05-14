#!/usr/bin/env sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
ALLOWLIST_INPUT=${1:-}
ADMIN_ACCOUNT_USERNAME=${ADMIN_ACCOUNT_USERNAME:-failsafe}
USER_LOCKER_EXTRA_ARGS=${USER_LOCKER_EXTRA_ARGS:-}

log() {
    printf '[+] %s\n' "$*"
}

fail() {
    printf '[x] %s\n' "$*" >&2
    exit 1
}

need_root() {
    [ "$(id -u)" -eq 0 ] || fail "This script must be run as root."
}

usage() {
    printf 'Usage: %s <authorized_user_list>\n' "${0##*/}" >&2
    exit 1
}

#
# Run a bundled hardening script from this directory.
#
run_script() {
    script_name=$1
    shift

    script_path=$SCRIPT_DIR/$script_name
    [ -f "$script_path" ] || fail "Required script not found: $script_path"

    log "Running $script_name..."
    sh "$script_path" "$@"
}

main() {
    need_root
    [ -n "$ALLOWLIST_INPUT" ] || usage
    [ -f "$ALLOWLIST_INPUT" ] || fail "Allowlist file not found: $ALLOWLIST_INPUT"
    [ -r "$ALLOWLIST_INPUT" ] || fail "Allowlist file is not readable: $ALLOWLIST_INPUT"

    run_script failsafe_creator.sh
    run_script root_locker.sh

    # shellcheck disable=SC2086
    run_script user_locker.sh --yes --admin "$ADMIN_ACCOUNT_USERNAME" $USER_LOCKER_EXTRA_ARGS "$ALLOWLIST_INPUT"

    log "CCDC hardening run complete."
}

main "$@"
