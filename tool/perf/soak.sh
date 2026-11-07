#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="${1:-$ROOT/build/macos/Build/Products/Profile/Warpgate.app}"
MINUTES="${2:-720}"
LABEL="${3:-soak}"
export WARPGATE_PERF_SOAK_MIN="$MINUTES"
export WARPGATE_PERF_SOAK_OUT="${WARPGATE_PERF_SOAK_OUT:-$ROOT/build/perf/soak-$LABEL.jsonl}"
exec caffeinate -i "$ROOT/tool/perf/app_bench.sh" "$APP" "$LABEL" soak
