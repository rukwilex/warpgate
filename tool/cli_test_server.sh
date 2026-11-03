#!/bin/sh
set -e
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
WORK="${1:-$ROOT/build/cli_test_server}"
mkdir -p "$WORK"
[ -f "$WORK/key" ] || ssh-keygen -q -t ed25519 -N '' -f "$WORK/key"
docker rm -f warpgate-cli-test >/dev/null 2>&1 || true
docker run -d --name warpgate-cli-test \
  -p 2222:2222 \
  -e PUID=1000 -e PGID=1000 \
  -e USER_NAME=warp \
  -e "PUBLIC_KEY=$(cat "$WORK/key.pub")" \
  -e DOCKER_MODS=linuxserver/mods:openssh-server-ssh-tunnel \
  lscr.io/linuxserver/openssh-server:latest >/dev/null
for _ in $(seq 1 60); do
  if ssh -i "$WORK/key" -p 2222 -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o IdentitiesOnly=yes -o ConnectTimeout=2 warp@127.0.0.1 true 2>/dev/null; then
    echo "WARPGATE_TEST_SSH_HOST=127.0.0.1"
    echo "WARPGATE_TEST_SSH_PORT=2222"
    echo "WARPGATE_TEST_SSH_USER=warp"
    echo "WARPGATE_TEST_SSH_KEY=$WORK/key"
    exit 0
  fi
  sleep 2
done
docker logs warpgate-cli-test >&2
exit 1
