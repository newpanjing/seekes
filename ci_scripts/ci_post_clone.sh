#!/bin/bash
set -euo pipefail

PROJECT_FILE="${CI_PRIMARY_REPOSITORY_PATH:-$(pwd)}/SeekES.xcodeproj/project.pbxproj"
EXPECTED_BUNDLE_IDENTIFIER="com.noondot.SeekES"

grep -q "PRODUCT_BUNDLE_IDENTIFIER = ${EXPECTED_BUNDLE_IDENTIFIER};" "$PROJECT_FILE"
echo "Validated bundle identifier: ${EXPECTED_BUNDLE_IDENTIFIER}"
