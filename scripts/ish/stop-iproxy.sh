#!/bin/sh
set -eu

TINYPROXY_CONFIG_PATH="${IPROXY_TINYPROXY_CONFIG_PATH:-/tmp/iproxy-tinyproxy.conf}"
SOCKD_CONFIG_PATH="${IPROXY_SOCKD_CONFIG_PATH:-/tmp/iproxy-sockd.conf}"
TINYPROXY_PID_PATH="${IPROXY_TINYPROXY_PID_PATH:-/tmp/iproxy-tinyproxy.pid}"
SOCKD_PID_PATH="${IPROXY_SOCKD_PID_PATH:-/tmp/iproxy-sockd.pid}"

stopped=0
pids=""

for pid_path in "$TINYPROXY_PID_PATH" "$SOCKD_PID_PATH"; do
  if [ -f "$pid_path" ]; then
    old_pid="$(cat "$pid_path" 2>/dev/null || true)"
    [ -n "$old_pid" ] && pids="$pids $old_pid"
    rm -f "$pid_path"
  fi
done

if command -v pgrep >/dev/null 2>&1; then
  found="$(pgrep -f "tinyproxy -c $TINYPROXY_CONFIG_PATH" 2>/dev/null || true)"
  pids="$pids $found"
  found="$(pgrep -f "sockd .* $SOCKD_CONFIG_PATH" 2>/dev/null || true)"
  pids="$pids $found"
fi

for pid in $pids; do
  [ -n "$pid" ] || continue
  [ "$pid" = "$$" ] && continue
  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    stopped=1
  fi
done

sleep 1

for pid in $pids; do
  [ -n "$pid" ] || continue
  [ "$pid" = "$$" ] && continue
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
    stopped=1
  fi
done

if [ "$stopped" -eq 1 ]; then
  printf 'iproxy 프록시를 중지했습니다.\n'
else
  printf '실행 중인 iproxy 프록시가 없습니다.\n'
fi
