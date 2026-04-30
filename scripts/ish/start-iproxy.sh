#!/bin/sh
set -eu

HTTP_PORT="${IPROXY_HTTP_PORT:-3128}"
SOCKS_PORT="${IPROXY_SOCKS_PORT:-1080}"
BIND_ADDR="${IPROXY_BIND_ADDR:-0.0.0.0}"
TINYPROXY_CONFIG_PATH="${IPROXY_TINYPROXY_CONFIG_PATH:-/tmp/iproxy-tinyproxy.conf}"
SOCKD_CONFIG_PATH="${IPROXY_SOCKD_CONFIG_PATH:-/tmp/iproxy-sockd.conf}"
TINYPROXY_PID_PATH="${IPROXY_TINYPROXY_PID_PATH:-/tmp/iproxy-tinyproxy.pid}"
SOCKD_PID_PATH="${IPROXY_SOCKD_PID_PATH:-/tmp/iproxy-sockd.pid}"
TINYPROXY_LOG_PATH="${IPROXY_TINYPROXY_LOG_PATH:-/tmp/iproxy-tinyproxy.log}"
SOCKD_LOG_PATH="${IPROXY_SOCKD_LOG_PATH:-/tmp/iproxy-sockd.log}"
EXTERNAL_IFACE="${IPROXY_EXTERNAL_IFACE:-}"
EXTERNAL_ADDR="${IPROXY_EXTERNAL_ADDR:-}"

require_packages() {
  if command -v tinyproxy >/dev/null 2>&1 && command -v sockd >/dev/null 2>&1; then
    return 0
  fi

  if ! command -v apk >/dev/null 2>&1; then
    printf '%s\n' 'apk를 찾을 수 없습니다. iSH Alpine 환경에서 실행하십시오.' >&2
    exit 1
  fi

  apk update
  apk add tinyproxy dante-server
}

detect_address_for_iface() {
  iface="$1"

  if command -v ip >/dev/null 2>&1; then
    found="$(ip -4 addr show dev "$iface" scope global 2>/dev/null | awk '/inet / { sub(/\/.*/, "", $2); print $2; exit }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    found="$(ifconfig "$iface" 2>/dev/null | awk '/inet addr:/ { sub(/addr:/, "", $2); print $2; exit } /inet / { print $2; exit }' || true)"
    if [ -n "$found" ] && [ "$found" != "127.0.0.1" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  return 1
}

detect_external_iface() {
  if [ -n "$EXTERNAL_IFACE" ]; then
    printf '%s\n' "$EXTERNAL_IFACE"
    return 0
  fi

  if command -v ip >/dev/null 2>&1; then
    found="$(ip route show default 2>/dev/null | awk '{ for (i = 1; i <= NF; i++) if ($i == "dev") { print $(i + 1); exit } }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  if [ -r /proc/net/route ]; then
    found="$(awk '$2 == "00000000" { print $1; exit }' /proc/net/route 2>/dev/null || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  if command -v route >/dev/null 2>&1; then
    found="$(route -n 2>/dev/null | awk '$1 == "0.0.0.0" { print $8; exit }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    found="$(ifconfig 2>/dev/null | awk '/^[^[:space:]]/ { sub(":", "", $1); iface = $1 } /inet / && iface != "lo" && iface != "lo0" { print iface; exit }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  printf '%s\n' 'eth0'
}

detect_external_addr() {
  if [ -n "$EXTERNAL_ADDR" ]; then
    printf '%s\n' "$EXTERNAL_ADDR"
    return 0
  fi

  iface="$(detect_external_iface)"
  found="$(detect_address_for_iface "$iface" 2>/dev/null || true)"
  if [ -n "$found" ]; then
    printf '%s\n' "$found"
    return 0
  fi

  if command -v ip >/dev/null 2>&1; then
    found="$(ip -4 addr show scope global 2>/dev/null | awk '/inet / { sub(/\/.*/, "", $2); print $2; exit }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  if command -v ifconfig >/dev/null 2>&1; then
    found="$(ifconfig 2>/dev/null | awk '/^[^[:space:]]/ { sub(":", "", $1); iface = $1 } /inet addr:/ && iface != "lo" && iface != "lo0" { sub(/addr:/, "", $2); print $2; exit } /inet / && iface != "lo" && iface != "lo0" { print $2; exit }' || true)"
    if [ -n "$found" ]; then
      printf '%s\n' "$found"
      return 0
    fi
  fi

  return 1
}

collect_pids() {
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

  printf '%s\n' "$pids"
}

stop_pids() {
  pids="$1"

  for pid in $pids; do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue
    kill "$pid" 2>/dev/null || true
  done

  sleep 1

  for pid in $pids; do
    [ -n "$pid" ] || continue
    [ "$pid" = "$$" ] && continue
    if kill -0 "$pid" 2>/dev/null; then
      kill -KILL "$pid" 2>/dev/null || true
    fi
  done
}

stop_existing() {
  stop_pids "$(collect_pids)"
}

write_tinyproxy_config() {
  umask 077
  {
    printf 'Port %s\n' "$HTTP_PORT"
    printf 'Listen %s\n' "$BIND_ADDR"
    printf '%s\n' 'Timeout 600'
    printf 'LogFile "%s"\n' "$TINYPROXY_LOG_PATH"
    printf 'PidFile "%s"\n' "$TINYPROXY_PID_PATH"
    printf '%s\n' 'MaxClients 4096'
    printf '%s\n' 'Allow 0.0.0.0/0'
    printf '%s\n' 'ConnectPort 443'
    printf '%s\n' 'ConnectPort 563'
  } > "$TINYPROXY_CONFIG_PATH"
}

write_sockd_config() {
  if ! addr="$(detect_external_addr)"; then
    printf '%s\n' 'SOCKS 외부 IPv4 주소를 감지하지 못했습니다.' >&2
    printf '다음처럼 주소를 직접 지정하십시오: IPROXY_EXTERNAL_ADDR=<iSH_IP주소> %s\n' "$0" >&2
    exit 1
  fi
  umask 077
  {
    printf 'logoutput: %s\n' "$SOCKD_LOG_PATH"
    printf 'internal: %s port = %s\n' "$BIND_ADDR" "$SOCKS_PORT"
    printf 'external: %s\n' "$addr"
    printf '%s\n' 'socksmethod: none'
    printf '%s\n' 'clientmethod: none'
    printf '%s\n' 'user.privileged: root'
    printf '%s\n' 'user.unprivileged: nobody'
    printf '%s\n' 'client pass {'
    printf '%s\n' '  from: 0.0.0.0/0 to: 0.0.0.0/0'
    printf '%s\n' '}'
    printf '%s\n' 'socks pass {'
    printf '%s\n' '  from: 0.0.0.0/0 to: 0.0.0.0/0'
    printf '%s\n' '  command: connect bind udpassociate'
    printf '%s\n' '  protocol: tcp udp'
    printf '%s\n' '}'
  } > "$SOCKD_CONFIG_PATH"
}

print_addresses() {
  addresses=""

  if command -v ip >/dev/null 2>&1; then
    addresses="$(ip -4 addr show scope global 2>/dev/null | awk '/inet / { sub(/\/.*/, "", $2); print $2 }' || true)"
  fi

  if [ -z "$addresses" ] && command -v ifconfig >/dev/null 2>&1; then
    addresses="$(ifconfig 2>/dev/null | awk '/inet / && $2 != "127.0.0.1" { print $2 }' || true)"
  fi

  printf '%s\n' "$addresses" | while IFS= read -r addr; do
    [ -n "$addr" ] || continue
    printf 'iSH 후보 주소: %s\n' "$addr"
  done
}

require_packages
stop_existing
write_tinyproxy_config
write_sockd_config
if ! tinyproxy -c "$TINYPROXY_CONFIG_PATH"; then
  printf '%s\n' 'tinyproxy 시작에 실패했습니다.' >&2
  [ -f "$TINYPROXY_LOG_PATH" ] && tail -n 20 "$TINYPROXY_LOG_PATH" >&2
  stop_existing
  exit 1
fi

if ! sockd -D -f "$SOCKD_CONFIG_PATH" -p "$SOCKD_PID_PATH"; then
  printf '%s\n' 'sockd 시작에 실패했습니다.' >&2
  sockd -V -f "$SOCKD_CONFIG_PATH" >&2 || true
  [ -f "$SOCKD_LOG_PATH" ] && tail -n 20 "$SOCKD_LOG_PATH" >&2
  printf 'SOCKS 외부 주소 감지가 잘못되었으면 다음처럼 다시 실행하십시오: IPROXY_EXTERNAL_ADDR=<iSH_IP주소> %s\n' "$0" >&2
  stop_existing
  exit 1
fi
sleep 1

if [ -f "$TINYPROXY_PID_PATH" ] && [ -f "$SOCKD_PID_PATH" ]; then
  printf 'iproxy 프록시가 시작되었습니다.\n'
  printf 'HTTP 포트: %s\n' "$HTTP_PORT"
  printf 'SOCKS 포트: %s\n' "$SOCKS_PORT"
  printf '바인드 주소: %s\n' "$BIND_ADDR"
  printf 'SOCKS 외부 주소: %s\n' "$(detect_external_addr)"
  print_addresses
  printf 'macOS에서 iPhone 핫스팟 또는 USB 테더링에 연결한 뒤 다음 형식으로 실행하십시오.\n'
  printf './scripts/macos/apply-iproxy.sh <iPhone 또는 iSH 주소> %s %s\n' "$SOCKS_PORT" "$HTTP_PORT"
  printf '주소를 생략하면 macOS 기본 게이트웨이를 사용합니다.\n'
else
  printf '%s\n' '프록시 시작에 실패했습니다.' >&2
  stop_existing
  exit 1
fi
