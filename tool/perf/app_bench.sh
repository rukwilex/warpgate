#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
APP="$1"
LABEL="$2"
shift 2
WORK="${WARPGATE_PERF_DIR:-$ROOT/build/perf}"
HOSTS="${WARPGATE_PERF_HOSTS:-20}"
PORTS="${WARPGATE_PERF_PORTS:-4}"
BASE="${WARPGATE_PERF_PORT:-2300}"
VM_PORT="${WARPGATE_PERF_VM_PORT:-8189}"
MCP_PORT="${WARPGATE_PERF_MCP_PORT:-47811}"
mkdir -p "$WORK"

export WARPGATE_HOME="$WORK/home-$LABEL"
rm -rf "$WARPGATE_HOME"
mkdir -p "$WARPGATE_HOME"
export WARPGATE_MASTER_KEY_FILE="$WORK/master.key"
[ -f "$WARPGATE_MASTER_KEY_FILE" ] || openssl rand -base64 32 > "$WARPGATE_MASTER_KEY_FILE"
chmod 600 "$WARPGATE_MASTER_KEY_FILE"

CLI="$WORK/warpgate"
if [ ! -x "$CLI" ] || [ -n "$WARPGATE_PERF_REBUILD_CLI" ]; then
  (cd "$ROOT/packages/warpgate_cli" && dart compile exe bin/warpgate.dart -o "$CLI" >/dev/null)
fi

[ -n "$WARPGATE_PERF_KEEP_FLEET" ] || "$ROOT/tool/perf/sshd_fleet.sh" start "$PORTS" >/dev/null
AGENT_SOCK="$WORK/agent-$LABEL.sock"
rm -f "$AGENT_SOCK"
eval "$(ssh-agent -s -a "$AGENT_SOCK")" >/dev/null
ssh-add -q "$WORK/key"
FP="$(ssh-keygen -lf "$WORK/host_key.pub" | awk '{print $2}')"

i=0
while [ "$i" -lt "$HOSTS" ]; do
  port=$((BASE + i % PORTS))
  "$CLI" --no-app hosts add "perf-$i" "$(id -un)@127.0.0.1:$port" --auth agent >/dev/null
  "$CLI" --no-app hosts edit "perf-$i" --mcp full >/dev/null
  i=$((i + 1))
done
i=0
while [ "$i" -lt "$PORTS" ]; do
  "$CLI" --no-app known-hosts trust "perf-$i" --fingerprint "$FP" >/dev/null 2>&1 || [ -n "$WARPGATE_PERF_UNREACHABLE" ]
  i=$((i + 1))
done
"$CLI" --no-app settings set mcpEnabled true >/dev/null
"$CLI" --no-app settings set mcpPort "$MCP_PORT" >/dev/null

LOG="$WORK/app-$LABEL.log"
FLUTTER_ENGINE_SWITCHES=3 \
FLUTTER_ENGINE_SWITCH_1="vm-service-port=$VM_PORT" \
FLUTTER_ENGINE_SWITCH_2="disable-service-auth-codes" \
FLUTTER_ENGINE_SWITCH_3="enable-dart-profiling" \
SSH_AUTH_SOCK="$AGENT_SOCK" \
  "$APP/Contents/MacOS/Warpgate" > "$LOG" 2>&1 &
APP_PID=$!

cleanup() {
  kill "$APP_PID" 2>/dev/null || true
  ssh-agent -k >/dev/null 2>&1 || true
}
trap cleanup EXIT INT TERM

for _ in $(seq 1 60); do
  curl -s "http://127.0.0.1:$VM_PORT/getVersion" >/dev/null 2>&1 && break
  sleep 1
done

cd "$ROOT/tool/perf/driver"
WARPGATE_PERF_APP_PID="$APP_PID" \
WARPGATE_PERF_VM="ws://127.0.0.1:$VM_PORT/ws" \
WARPGATE_PERF_LABEL="$LABEL" \
WARPGATE_PERF_OUT="${WARPGATE_PERF_OUT:-$ROOT/build/perf/results.jsonl}" \
WARPGATE_PERF_FLEET="$ROOT/tool/perf/sshd_fleet.sh" \
WARPGATE_PERF_MCP_PORT="$MCP_PORT" \
  dart run bin/driver.dart "$@"
