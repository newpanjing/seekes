#!/bin/bash
set -euo pipefail

EXPECTED_BUNDLE_IDENTIFIER="com.noondot.SeekES"

if [[ -n "${CI_ARCHIVE_PATH:-}" && -f "${CI_ARCHIVE_PATH}/Info.plist" ]]; then
  ACTUAL_BUNDLE_IDENTIFIER=$(/usr/libexec/PlistBuddy -c 'Print :ApplicationProperties:CFBundleIdentifier' "${CI_ARCHIVE_PATH}/Info.plist")
  test "$ACTUAL_BUNDLE_IDENTIFIER" = "$EXPECTED_BUNDLE_IDENTIFIER"
  echo "Validated archive bundle identifier: ${ACTUAL_BUNDLE_IDENTIFIER}"
else
  echo "CI_ARCHIVE_PATH is unavailable; Xcode Cloud will validate the archive during distribution."
fi
