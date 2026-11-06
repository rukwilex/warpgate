#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="${WARPGATE_PERF_DIR:-$ROOT/build/perf}"
COUNT="${2:-4}"
BASE="${WARPGATE_PERF_PORT:-2300}"
SSHD="${SSHD:-/usr/sbin/sshd}"
mkdir -p "$WORK/fleet"
[ -f "$WORK/key" ] || ssh-keygen -q -t ed25519 -N '' -f "$WORK/key"
[ -f "$WORK/host_key" ] || ssh-keygen -q -t ed25519 -N '' -f "$WORK/host_key"
cp "$WORK/key.pub" "$WORK/authorized_keys"
chmod 600 "$WORK/authorized_keys"

start() {
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    port=$((BASE + i))
    conf="$WORK/fleet/sshd_$port.conf"
    cat > "$conf" <<CONF
Port $port
ListenAddress 127.0.0.1
HostKey $WORK/host_key
PidFile $WORK/fleet/sshd_$port.pid
AuthorizedKeysFile $WORK/authorized_keys
PasswordAuthentication no
KbdInteractiveAuthentication no
UsePAM no
StrictModes no
Subsystem sftp internal-sftp
MaxSessions 64
MaxStartups 200
LogLevel ERROR
ClientAliveInterval 0
CONF
    "$SSHD" -f "$conf" -E "$WORK/fleet/sshd_$port.log"
    i=$((i + 1))
  done
  i=0
  while [ "$i" -lt "$COUNT" ]; do
    port=$((BASE + i))
    for _ in 1 2 3 4 5 6 7 8 9 10; do
      if ssh -i "$WORK/key" -p "$port" -o BatchMode=yes -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o LogLevel=ERROR \
        "$(id -un)@127.0.0.1" true 2>/dev/null; then break; fi
      sleep 0.3
    done
    i=$((i + 1))
  done
  echo "WARPGATE_PERF_HOST=127.0.0.1"
  echo "WARPGATE_PERF_PORT=$BASE"
  echo "WARPGATE_PERF_COUNT=$COUNT"
  echo "WARPGATE_PERF_USER=$(id -un)"
  echo "WARPGATE_PERF_KEY=$WORK/key"
}

stop() {
  for pid in "$WORK"/fleet/*.pid; do
    [ -f "$pid" ] && kill "$(cat "$pid")" 2>/dev/null || true
    rm -f "$pid"
  done
}

pause() {
  for pid in "$WORK"/fleet/*.pid; do [ -f "$pid" ] && kill -STOP "$(cat "$pid")"; done
  pkill -STOP -U "$(id -u)" -f "sshd-session.*$(id -un)" 2>/dev/null || true
}

resume() {
  pkill -CONT -U "$(id -u)" -f "sshd-session.*$(id -un)" 2>/dev/null || true
  for pid in "$WORK"/fleet/*.pid; do [ -f "$pid" ] && kill -CONT "$(cat "$pid")"; done
}

drop() {
  pkill -KILL -U "$(id -u)" -f "sshd-session.*$(id -un)" 2>/dev/null || true
  pkill -KILL -U "$(id -u)" -f "sshd-auth" 2>/dev/null || true
}

case "${1:-start}" in
  start) stop; start ;;
  stop) stop ;;
  pause) pause ;;
  resume) resume ;;
  drop) drop ;;
  *) echo "usage: $0 start|stop|pause|resume|drop [count]" >&2; exit 2 ;;
esac
