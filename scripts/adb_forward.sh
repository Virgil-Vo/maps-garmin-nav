#!/usr/bin/env bash
# Forward phone port 7381 to the Connect IQ simulator on this machine.
set -euo pipefail

ADB="${ADB:-}"
if [[ -z "$ADB" ]]; then
  if command -v adb >/dev/null 2>&1; then
    ADB=adb
  elif [[ -x "${ANDROID_HOME:-}/platform-tools/adb" ]]; then
    ADB="${ANDROID_HOME}/platform-tools/adb"
  elif [[ -x "$HOME/Android/Sdk/platform-tools/adb" ]]; then
    ADB="$HOME/Android/Sdk/platform-tools/adb"
  else
    echo "error: adb not found. Install platform-tools or set ADB." >&2
    exit 1
  fi
fi

"$ADB" devices
"$ADB" forward tcp:7381 tcp:7381
echo "ADB forward active: device tcp:7381 -> host tcp:7381"
