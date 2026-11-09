#!/bin/sh
# Created: 2026-11-09 07:38 -06:00 · Edited: 2026-11-09 07:38 -06:00
# Compile check for the app and widget targets (`H2`, from `F1`): one unsigned build each for
# the iOS Simulator and macOS. Signing is Xcode's job on Marty's machine; CI has no team.
# Exit 1 if either build fails, with its errors printed.
cd "$(dirname "$0")/.." || exit 1
dd=${DERIVED_DATA:-.build/xcode}
fail=0
for dest in "generic/platform=iOS Simulator" "generic/platform=macOS"; do
    log=$(mktemp)
    if xcodebuild build -project Countdown.xcodeproj -scheme Countdown -destination "$dest" \
        -derivedDataPath "$dd" CODE_SIGNING_ALLOWED=NO >"$log" 2>&1; then
        printf '  ok    build %s\n' "$dest"
    else
        printf '  FAIL  build %s\n' "$dest"
        grep -E "error:" "$log" | sort -u | head -20 | sed 's/^/          /'
        fail=1
    fi
    rm -f "$log"
done
exit $fail
