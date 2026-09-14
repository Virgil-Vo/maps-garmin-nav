#!/usr/bin/env bash
# Build the Connect IQ watch app and load it on a simulator.
#
# Usage:
#   ./scripts/run_garmin.sh
#   ./scripts/run_garmin.sh fr255
#   ./scripts/run_garmin.sh fr255m
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/connectiq_env.sh
source "$ROOT/scripts/connectiq_env.sh"

device="${1:-fr255}"
case "$device" in
  -h | --help)
    cat <<'EOF'
Usage: scripts/run_garmin.sh [device]

  device   Connect IQ device id (default: fr255)
EOF
    exit 0
    ;;
esac

export PATH="$LOCAL_BIN:$PATH"
use_java || die "Java 17+ not found. Run the \"Run setup\" launch config first."
use_sdk
need_cmd monkeyc
need_cmd monkeydo

compile_watch "$device"
start_simulator
run_watch_on_sim "$device"
