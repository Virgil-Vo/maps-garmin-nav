#!/usr/bin/env bash
# Install Connect IQ + Flutter deps. Does not launch apps or the simulator.
#
# Usage:
#   ./scripts/setup.sh
#   ./scripts/setup.sh --force
#
# Device files require a Garmin developer login. Either:
#   export GARMIN_USERNAME=... GARMIN_PASSWORD=...
# or complete the browser OAuth prompt on first run.
#
# First-time device download also needs the Connect IQ agreement:
#   export CONNECTIQ_ACCEPT_AGREEMENT=1
# or type "accept" when prompted. Hash override: CONNECTIQ_AGREEMENT_HASH.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# shellcheck source=scripts/connectiq_env.sh
source "$ROOT/scripts/connectiq_env.sh"

CONNECTIQ_MANAGER_VERSION="${CONNECTIQ_MANAGER_VERSION:-0.8.4}"
CIQ_SDKS_JSON_URL="https://developer.garmin.com/downloads/connect-iq/sdks/sdks.json"
CIQ_SDKS_BASE_URL="https://developer.garmin.com/downloads/connect-iq/sdks"
MANAGER_REPO="lindell/connect-iq-sdk-manager-cli"

FORCE=0

usage() {
  cat <<'EOF'
Usage: scripts/setup.sh [options]

  --force      Re-download SDK / device files even if present
  -h, --help   Show this help
EOF
}

is_tty() { [[ -t 0 && -t 1 ]]; }

host_os() { uname -s | tr '[:upper:]' '[:lower:]'; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    --force) FORCE=1 ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      die "Unknown option: $1"
      ;;
  esac
  shift
done

if [[ "$(id -u)" -eq 0 ]]; then
  die "Do not run this script as root. FVM/Flutter will refuse to run."
fi

[[ "$(host_os)" == "linux" ]] || die "This script currently supports Linux only."

need_cmd curl
need_cmd unzip
need_cmd tar
need_cmd openssl
need_cmd python3
need_cmd jq

mkdir -p "$SDKS_DIR" "$DEVICES_DIR" "$APPIMAGES_DIR" "$LOCAL_BIN" "$ROOT/watch/bin"
export PATH="$LOCAL_BIN:$PATH"

pkg_install() {
  local pkgs=("$@")
  if command -v pacman >/dev/null 2>&1; then
    sudo pacman -S --needed --noconfirm "${pkgs[@]}"
  elif command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update -qq
    sudo apt-get install -y "${pkgs[@]}"
  else
    die "Install packages manually: ${pkgs[*]}"
  fi
}

adoptium_arch() {
  case "$(host_arch)" in
    x86_64) echo x64 ;;
    arm64) echo aarch64 ;;
    *) die "No Adoptium JDK build for $(host_arch)" ;;
  esac
}

install_latest_jdk() {
  local feature api_arch tarball tmp extracted
  feature="$(curl -fsSL https://api.adoptium.net/v3/info/available_releases | jq -r '.most_recent_feature_release')"
  [[ "$feature" =~ ^[0-9]+$ ]] || die "Could not resolve the latest JDK version"
  api_arch="$(adoptium_arch)"
  log "Downloading Eclipse Temurin JDK ${feature} to $USER_JAVA_HOME"
  tmp="$(mktemp -d)"
  tarball="$tmp/jdk.tar.gz"
  curl -fL --progress-bar -o "$tarball" \
    "https://api.adoptium.net/v3/binary/latest/${feature}/ga/linux/${api_arch}/jdk/hotspot/normal/eclipse?project=jdk"
  mkdir -p "$HOME/.local/jdk-dist"
  tar -xzf "$tarball" -C "$tmp"
  extracted="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
  [[ -x "$extracted/bin/java" ]] || die "JDK archive did not contain bin/java"
  rm -rf "$HOME/.local/jdk-dist/jdk-${feature}"
  mv "$extracted" "$HOME/.local/jdk-dist/jdk-${feature}"
  ln -sfn "$HOME/.local/jdk-dist/jdk-${feature}" "$USER_JAVA_HOME"
  mkdir -p "$LOCAL_BIN"
  ln -sfn "$USER_JAVA_HOME/bin/java" "$LOCAL_BIN/java"
  ln -sfn "$USER_JAVA_HOME/bin/javac" "$LOCAL_BIN/javac"
  rm -rf "$tmp"
  export JAVA_HOME="$USER_JAVA_HOME"
  export PATH="$JAVA_HOME/bin:$PATH"
}

ensure_java() {
  local major=0
  if use_java; then
    major="$(java_major)"
  fi
  if [[ "$major" -lt 17 ]]; then
    log "Installing the latest JDK (user-local; no root required)"
    install_latest_jdk
    unset JAVA_HOME
  fi
  use_java || die "Java 17+ is required, found $(java -version 2>&1 | head -n 1)"
  log "Using Java $(java -version 2>&1 | head -n 1) (JAVA_HOME=$JAVA_HOME)"
}

download_sdk() {
  log "Resolving Connect IQ SDK ${CONNECTIQ_SDK_VERSION}"
  local linux_zip
  linux_zip="$(
    curl -fsSL "$CIQ_SDKS_JSON_URL" | jq -r --arg v "$CONNECTIQ_SDK_VERSION" '
      [.[] | select(.version == $v) | .linux] | last // empty
    '
  )"
  [[ -n "$linux_zip" ]] || die "Connect IQ SDK ${CONNECTIQ_SDK_VERSION} not listed at $CIQ_SDKS_JSON_URL"

  local dest="$SDKS_DIR/${linux_zip%.zip}"
  local zip_path="$SDKS_DIR/$linux_zip"
  if [[ "$FORCE" -eq 1 && -d "$dest" ]]; then
    rm -rf "$dest"
  fi
  if [[ -x "$dest/bin/monkeyc" ]]; then
    log "SDK ${CONNECTIQ_SDK_VERSION} already installed at $dest"
    activate_sdk "$dest"
    return
  fi

  log "Downloading $linux_zip (~200MB). By downloading you accept Garmin's Connect IQ agreement:"
  log "https://developer.garmin.com/connect-iq/sdk/"
  curl -fL --progress-bar -o "$zip_path" "$CIQ_SDKS_BASE_URL/$linux_zip"

  local tmp
  tmp="$(mktemp -d)"
  unzip -q "$zip_path" -d "$tmp"
  mkdir -p "$dest"
  if [[ -x "$tmp/bin/monkeyc" ]]; then
    shopt -s dotglob
    mv "$tmp"/* "$dest/"
    shopt -u dotglob
  else
    local inner
    inner="$(find "$tmp" -mindepth 1 -maxdepth 1 -type d | head -n 1)"
    [[ -n "$inner" ]] || die "Unexpected SDK zip layout in $linux_zip"
    shopt -s dotglob
    mv "$inner"/* "$dest/"
    shopt -u dotglob
  fi
  rm -rf "$tmp" "$zip_path"
  [[ -x "$dest/bin/monkeyc" ]] || die "SDK extract failed: monkeyc missing in $dest"
  chmod +x "$dest/bin/"* 2>/dev/null || true
  log "Installed Connect IQ SDK ${CONNECTIQ_SDK_VERSION}"
  activate_sdk "$dest"
}

ensure_sdk() {
  local existing current
  existing="$(find_sdk_dir || true)"
  current="$(current_sdk_path || true)"

  if [[ "$FORCE" -eq 0 && -n "$existing" ]]; then
    if [[ -n "$current" && "$(sdk_version_of "$current")" == "$CONNECTIQ_SDK_VERSION" && -x "$current/bin/monkeyc" ]]; then
      log "Connect IQ SDK ${CONNECTIQ_SDK_VERSION} already active"
      activate_sdk "$current"
      return
    fi
    log "Switching active Connect IQ SDK to ${CONNECTIQ_SDK_VERSION}"
    activate_sdk "$existing"
    return
  fi

  if [[ -n "$current" && "$(sdk_version_of "$current")" != "$CONNECTIQ_SDK_VERSION" ]]; then
    log "Active SDK is $(sdk_version_of "$current" || echo unknown); want ${CONNECTIQ_SDK_VERSION}"
  fi
  download_sdk
}

manager_bin() {
  if command -v connect-iq-sdk-manager >/dev/null 2>&1; then
    command -v connect-iq-sdk-manager
    return
  fi
  if [[ -x "$LOCAL_BIN/connect-iq-sdk-manager" ]]; then
    echo "$LOCAL_BIN/connect-iq-sdk-manager"
    return
  fi
  return 1
}

ensure_manager() {
  local bin
  if bin="$(manager_bin)"; then
    echo "$bin"
    return
  fi

  [[ "$(host_arch)" == "x86_64" ]] || die "Install connect-iq-sdk-manager manually for $(host_arch)"
  log "Installing connect-iq-sdk-manager ${CONNECTIQ_MANAGER_VERSION}"
  local tmp tar_name
  tmp="$(mktemp -d)"
  tar_name="connect-iq-sdk-manager-cli_${CONNECTIQ_MANAGER_VERSION}_Linux_x86_64.tar.gz"
  curl -fL --progress-bar -o "$tmp/$tar_name" \
    "https://github.com/${MANAGER_REPO}/releases/download/v${CONNECTIQ_MANAGER_VERSION}/${tar_name}"
  tar -xzf "$tmp/$tar_name" -C "$tmp"
  local extracted
  extracted="$(find "$tmp" -type f \( -name 'connect-iq-sdk-manager' -o -name 'connect-iq-sdk-manager-cli' \) | head -n 1)"
  [[ -n "$extracted" ]] || die "connect-iq-sdk-manager binary missing from $tar_name"
  install -m 0755 "$extracted" "$LOCAL_BIN/connect-iq-sdk-manager"
  rm -rf "$tmp"
  echo "$LOCAL_BIN/connect-iq-sdk-manager"
}

all_devices_ready() {
  local id
  for id in $CONNECTIQ_DEVICES; do
    device_ready "$id" || return 1
  done
  return 0
}

prompt_agreement() {
  if [[ -n "${CONNECTIQ_AGREEMENT_HASH:-}" || "${CONNECTIQ_ACCEPT_AGREEMENT:-}" == "1" ]]; then
    return 0
  fi
  if is_tty; then
    printf 'Connect IQ device files require Garmin'\''s developer agreement:\n' >&2
    printf '  https://developer.garmin.com/connect-iq/sdk/\n' >&2
    printf 'Type "accept" to continue: ' >&2
    local reply
    read -r reply
    [[ "$reply" == "accept" ]] || die "Agreement not accepted"
    return 0
  fi
  die "Set CONNECTIQ_ACCEPT_AGREEMENT=1 after reviewing https://developer.garmin.com/connect-iq/sdk/"
}

ensure_devices() {
  if [[ "$FORCE" -eq 0 ]] && all_devices_ready; then
    log "Forerunner 255 device files already present"
    return
  fi

  local manager
  manager="$(ensure_manager)"
  prompt_agreement

  log "Accepting Connect IQ SDK agreement"
  "$manager" agreement view >/tmp/connectiq-agreement.txt || true
  if [[ -n "${CONNECTIQ_AGREEMENT_HASH:-}" ]]; then
    "$manager" agreement accept --agreement-hash="$CONNECTIQ_AGREEMENT_HASH"
  else
    "$manager" agreement accept
  fi

  log "Logging into Garmin (needed to download device files)"
  if [[ -n "${GARMIN_USERNAME:-}" && -n "${GARMIN_PASSWORD:-}" ]]; then
    "$manager" login --username "$GARMIN_USERNAME" --password "$GARMIN_PASSWORD"
  else
    "$manager" login
  fi

  log "Downloading device files from watch/manifest.xml ($CONNECTIQ_DEVICES)"
  # CLI allows manifest OR -d devices, not both.
  "$manager" device download --include-fonts -m "$ROOT/watch/manifest.xml"
  all_devices_ready || die "Device files missing after download. Expected $CONNECTIQ_DEVICES under $DEVICES_DIR"
}

ensure_developer_key() {
  if [[ -f "$DEVELOPER_KEY" ]]; then
    log "Using developer key $DEVELOPER_KEY"
    return
  fi
  log "Generating Connect IQ developer key at $DEVELOPER_KEY"
  openssl genrsa 4096 2>/dev/null | openssl pkcs8 -topk8 -nocrypt -outform DER -out "$DEVELOPER_KEY"
}

ensure_sim_appimage() {
  [[ "$(host_arch)" == "x86_64" ]] || return 0
  local path
  path="$(sim_appimage_path)"
  if [[ -x "$path" && "$FORCE" -eq 0 ]]; then
    log "Simulator AppImage already present"
    return
  fi
  if command -v pacman >/dev/null 2>&1 && ! pacman -Q fuse2 >/dev/null 2>&1; then
    log "Installing fuse2 for the Connect IQ simulator AppImage"
    pkg_install fuse2 || warn "Could not install fuse2; AppImage may need --appimage-extract-and-run"
  fi
  log "Downloading Linux simulator AppImage ${CONNECTIQ_SDK_VERSION}"
  local url="https://github.com/pcolby/connectiq-sdk-manager/releases/download/${PCOLBY_RELEASE}/Connect_IQ_Simulator-${CONNECTIQ_SDK_VERSION}%2B${PCOLBY_SIM_BUILD}-x86_64.AppImage"
  curl -fL --progress-bar -o "$path" "$url"
  chmod +x "$path"
}

run_flutter() {
  if command -v fvm >/dev/null 2>&1; then
    fvm flutter "$@"
  else
    flutter "$@"
  fi
}

run_dart() {
  if command -v fvm >/dev/null 2>&1; then
    fvm dart "$@"
  else
    dart "$@"
  fi
}

setup_flutter() {
  if command -v fvm >/dev/null 2>&1; then
    log "Using FVM Flutter $(jq -r '.flutter' "$ROOT/.fvmrc" 2>/dev/null || echo pinned)"
    fvm install
  else
    command -v flutter >/dev/null 2>&1 || die "Flutter is not on PATH. Install FVM or Flutter."
  fi
  log "Installing Flutter packages"
  run_flutter pub get
  log "Running dart build_runner"
  run_dart run build_runner build --delete-conflicting-outputs
}

ensure_java
ensure_sdk
ensure_devices
ensure_developer_key
ensure_sim_appimage
setup_flutter

log "Setup complete"
printf 'SDK:     %s\n' "$(current_sdk_path)"
printf 'Devices: %s\n' "$CONNECTIQ_DEVICES"
printf 'Key:     %s\n' "$DEVELOPER_KEY"
printf 'Sim:     %s\n' "$(sim_appimage_path)"
