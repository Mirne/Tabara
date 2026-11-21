#!/usr/bin/env bash
set -euo pipefail

export ANDROID_SERIAL=emulator-5554
export ANDROID_TEST_ROOT=1
test_python="$RUNNER_TEMP/tabara-test-python/bin/python"

adb root
adb wait-for-device
if [[ "$TABARA_ANDROID_API" == 36 ]]; then
  adb shell wm size 720x1544
fi
adb shell settings put secure immersive_mode_confirmations confirmed

if [[ "$TABARA_BACK_PROBE" == true ]]; then
  exec "$test_python" tests/android_smoke.py --back-probe
fi

ANDROID_PREVIOUS_APK="$RUNNER_TEMP/tabara-v0131.apk" ANDROID_REPORT_NAME=android-patch-upgrade \
  "$test_python" tests/android_patch_update.py
if [[ "$TABARA_FULL_SMOKE" == true ]]; then
  "$test_python" tests/android_smoke.py
fi
