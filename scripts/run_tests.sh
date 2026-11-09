#!/bin/sh
# Created: 2026-11-08 21:11 -06:00 · Edited: 2026-11-08 21:11 -06:00
# Harness `run` (`C1`): every Swift test, from the repository this script sits in.
# Optional $1: a scratch path to reuse a build cache (the pre-commit export passes one).
root=$(cd "$(dirname "$0")/.." && pwd)
if [ -n "${1:-}" ]; then
    exec swift test --package-path "$root/CountdownCore" --scratch-path "$1"
fi
exec swift test --package-path "$root/CountdownCore"
