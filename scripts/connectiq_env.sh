# Shared Connect IQ paths and runtime helpers.
# shellcheck shell=bash

CONNECTIQ_SDK_VERSION="${CONNECTIQ_SDK_VERSION:-9.2.0}"
CONNECTIQ_DEVICES="${CONNECTIQ_DEVICES:-fr255 fr255m}"
PCOLBY_RELEASE="${PCOLBY_RELEASE:-v0.6.10}"
PCOLBY_SIM_BUILD="${PCOLBY_SIM_BUILD:-162}"
WATCH_PRG="${WATCH_PRG:-watch/bin/maps-garmin-nav.prg}"
GARMIN_HOME="${GARMIN_HOME:-$HOME/.Garmin/ConnectIQ}"
SDKS_DIR="$GARMIN_HOME/Sdks"
DEVICES_DIR="$GARMIN_HOME/Devices"
APPIMAGES_DIR="$GARMIN_HOME/AppImages"
CURRENT_SDK_CFG="$GARMIN_HOME/current-sdk.cfg"
CONFIG_INI="$GARMIN_HOME/sdkmanager-config.ini"
DEVELOPER_KEY="${DEVELOPER_KEY:-$GARMIN_HOME/developer_key.der}"
LOCAL_BIN="${LOCAL_BIN:-$HOME/.local/bin}"
USER_JAVA_HOME="${USER_JAVA_HOME:-$HOME/.local/jdk}"

log() { printf '==> %s\n' "$*" >&2; }
warn() { printf 'warning: %s\n' "$*" >&2; }
die() { printf 'error: %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Missing required command: $1"
}

host_arch() {
  case "$(uname -m)" in
    x86_64 | amd64) echo x86_64 ;;
    aarch64 | arm64) echo arm64 ;;
    *) uname -m ;;
  esac
}

java_major() {
  local line
  line="$(java -version 2>&1 | head -n 1 || true)"
  if [[ "$line" =~ version\ \"1\.([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$line" =~ version\ \"([0-9]+) ]]; then
    echo "${BASH_REMATCH[1]}"
  else
    echo 0
  fi
}

java_home_from_bin() {
  local java_bin
  java_bin="$(command -v java 2>/dev/null || true)"
  [[ -n "$java_bin" ]] || return 1
  java_bin="$(readlink -f "$java_bin")"
  local home
  home="$(cd "$(dirname "$java_bin")/.." && pwd)"
  [[ -x "$home/bin/java" ]] || return 1
  printf '%s\n' "$home"
}

newest_jvm_home() {
  local dir major best="" best_major=0
  shopt -s nullglob
  for dir in \
    "$USER_JAVA_HOME" \
    "$HOME/.local/jdk" \
    "$HOME/.jdks"/* \
    /usr/lib/jvm/default \
    /usr/lib/jvm/default-java \
    /usr/lib/jvm/java-*-openjdk \
    /usr/lib/jvm/java-*-openjdk-* \
    /usr/lib/jvm/java-*
  do
    [[ -x "$dir/bin/java" ]] || continue
    major="$("$dir/bin/java" -version 2>&1 | sed -nE 's/.*version "1\.([0-9]+).*/\1/p; s/.*version "([0-9]+).*/\1/p' | head -n 1)"
    [[ -n "$major" ]] || continue
    if [[ "$major" -ge "$best_major" ]]; then
      best_major="$major"
      best="$dir"
    fi
  done
  shopt -u nullglob
  [[ -n "$best" ]] || return 1
  printf '%s\n' "$best"
}

use_java() {
  local home=""
  if [[ -n "${JAVA_HOME:-}" && -x "${JAVA_HOME}/bin/java" ]]; then
    home="$JAVA_HOME"
  else
    home="$(newest_jvm_home || true)"
  fi
  if [[ -z "$home" ]]; then
    home="$(java_home_from_bin || true)"
  fi
  if [[ -n "$home" ]]; then
    export JAVA_HOME="$home"
    export PATH="$JAVA_HOME/bin:$PATH"
  fi
  command -v java >/dev/null 2>&1 || return 1
  local major
  major="$(java_major)"
  [[ "$major" -ge 17 ]] || return 1
  return 0
}

current_sdk_path() {
  if [[ -f "$CURRENT_SDK_CFG" ]]; then
    tr -d '[:space:]' <"$CURRENT_SDK_CFG"
  fi
}

sdk_version_of() {
  local name
  name="$(basename "$1")"
  if [[ "$name" =~ connectiq-sdk-[a-z]+-([0-9]+(\.[0-9]+)*)- ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

find_sdk_dir() {
  local dir
  shopt -s nullglob
  for dir in "$SDKS_DIR"/connectiq-sdk-*-"${CONNECTIQ_SDK_VERSION}"-*; do
    if [[ -x "$dir/bin/monkeyc" ]]; then
      echo "$dir"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

activate_sdk() {
  local sdk_dir="$1"
  printf '%s\n' "$sdk_dir" >"$CURRENT_SDK_CFG"
  python3 - "$CONFIG_INI" "$sdk_dir" <<'PY'
from pathlib import Path
import sys
path, sdk = Path(sys.argv[1]), sys.argv[2]
text = path.read_text() if path.exists() else ""
lines = [line for line in text.splitlines() if not line.startswith("current-sdk")]
lines.append(f"current-sdk={sdk}")
path.write_text("\n".join(lines) + "\n")
PY
  export CONNECTIQ_HOME="$sdk_dir"
  export PATH="$sdk_dir/bin:$PATH"
}

use_sdk() {
  local existing current
  existing="$(find_sdk_dir || true)"
  current="$(current_sdk_path || true)"
  if [[ -n "$current" && -x "$current/bin/monkeyc" ]]; then
    activate_sdk "$current"
    return
  fi
  if [[ -n "$existing" ]]; then
    activate_sdk "$existing"
    return
  fi
  die "Connect IQ SDK ${CONNECTIQ_SDK_VERSION} is not installed. Run scripts/setup.sh first."
}

device_ready() {
  local id="$1"
  [[ -f "$DEVICES_DIR/$id/compiler.json" && -f "$DEVICES_DIR/$id/simulator.json" ]]
}

sim_appimage_path() {
  echo "$APPIMAGES_DIR/Connect_IQ_Simulator-${CONNECTIQ_SDK_VERSION}+${PCOLBY_SIM_BUILD}-x86_64.AppImage"
}

simulator_running() {
  pgrep -f 'Connect_IQ_Simulator|connectiq-sdk-.*/bin/simulator|/bin/connectiq' >/dev/null 2>&1
}

official_simulator_ok() {
  local sim
  sim="$(command -v simulator || true)"
  [[ -n "$sim" ]] || return 1
  if ldd "$sim" 2>/dev/null | grep -q 'not found'; then
    return 1
  fi
  return 0
}

start_simulator() {
  if [[ -z "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    die "No display available; cannot start the Connect IQ simulator"
  fi
  if simulator_running; then
    log "Connect IQ simulator already running"
    return
  fi

  local sim_cmd=()
  local appimage=""
  appimage="$(sim_appimage_path)"
  if official_simulator_ok; then
    sim_cmd=(connectiq)
  elif [[ -x "$appimage" ]]; then
    sim_cmd=("$appimage")
  else
    die "Simulator is not installed. Run scripts/setup.sh first."
  fi

  log "Starting Connect IQ simulator"
  nohup "${sim_cmd[@]}" >/tmp/connectiq-simulator.log 2>&1 &

  local i
  for i in $(seq 1 20); do
    if simulator_running; then
      sleep 2
      log "Simulator is up"
      return
    fi
    sleep 1
  done

  if [[ -x "$appimage" ]]; then
    warn "Retrying simulator AppImage without FUSE"
    nohup "$appimage" --appimage-extract-and-run >/tmp/connectiq-simulator.log 2>&1 &
    for i in $(seq 1 20); do
      if simulator_running; then
        sleep 2
        log "Simulator is up"
        return
      fi
      sleep 1
    done
  fi
  die "Simulator did not start. See /tmp/connectiq-simulator.log"
}

compile_watch() {
  local device="$1"
  need_cmd monkeyc
  [[ -f "$DEVELOPER_KEY" ]] || die "Developer key missing. Run scripts/setup.sh first."
  device_ready "$device" || die "Device files for $device are missing. Run scripts/setup.sh first."
  mkdir -p "$(dirname "$ROOT/$WATCH_PRG")"
  log "Building watch app for $device"
  monkeyc \
    -f "$ROOT/watch/monkey.jungle" \
    -d "$device" \
    -o "$ROOT/$WATCH_PRG" \
    -y "$DEVELOPER_KEY" \
    -w
}

run_watch_on_sim() {
  local device="$1"
  need_cmd monkeydo
  log "Loading $WATCH_PRG onto $device"
  exec monkeydo "$ROOT/$WATCH_PRG" "$device"
}
