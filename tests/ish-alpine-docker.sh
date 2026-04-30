#!/bin/sh
set -eu

ROOT_DIR="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
IMAGE="${IPROXY_TEST_IMAGE:-alpine:3.20}"
PLATFORM="${IPROXY_TEST_PLATFORM:-linux/386}"

docker run --rm --platform "$PLATFORM" -v "$ROOT_DIR:/work" -w /work "$IMAGE" sh -ec '
  apk add --no-cache curl >/dev/null
  sh -n scripts/ish/start-iproxy.sh
  sh -n scripts/ish/stop-iproxy.sh

  ./scripts/ish/start-iproxy.sh >/tmp/start-default.out
  test -f /tmp/iproxy-tinyproxy.pid
  test -f /tmp/iproxy-sockd.pid
  curl -fsS -x http://127.0.0.1:3128 http://example.com >/tmp/http-default.out
  curl -fsS --socks5-hostname 127.0.0.1:1080 http://example.com >/tmp/socks-default.out
  grep -qi "example" /tmp/http-default.out
  grep -qi "example" /tmp/socks-default.out

  IPROXY_HTTP_PORT=18080 IPROXY_SOCKS_PORT=11080 ./scripts/ish/start-iproxy.sh >/tmp/start-custom.out
  curl -fsS -x http://127.0.0.1:18080 http://example.com >/tmp/http-custom.out
  curl -fsS --socks5-hostname 127.0.0.1:11080 http://example.com >/tmp/socks-custom.out
  grep -qi "example" /tmp/http-custom.out
  grep -qi "example" /tmp/socks-custom.out

  ./scripts/ish/stop-iproxy.sh >/tmp/stop1.out
  ./scripts/ish/stop-iproxy.sh >/tmp/stop2.out
  grep -q "중지했습니다" /tmp/stop1.out
  grep -q "실행 중인 iproxy 프록시가 없습니다" /tmp/stop2.out
  ! pgrep -f "tinyproxy -c /tmp/iproxy-tinyproxy.conf" >/dev/null 2>&1
  ! pgrep -f "sockd .* /tmp/iproxy-sockd.conf" >/dev/null 2>&1

  echo "ALPINE_ISH_DOCKER_TEST=passed"
'
