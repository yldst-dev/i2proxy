#!/bin/sh
set -eu

HOST="${1:-}"
SOCKS_PORT="${2:-1080}"
HTTP_PORT="${3:-3128}"
TARGET_SERVICE="${4:-${IPROXY_SERVICE:-}}"
HOTSPOT_SSID="${IPROXY_HOTSPOT_SSID:-}"
HOTSPOT_PASSWORD="${IPROXY_HOTSPOT_PASSWORD:-}"

usage() {
  printf '사용법: %s [proxy_host] [socks_port] [http_port] [network_service]\n' "$0"
  printf '예시: %s 172.20.10.1 1080 3128\n' "$0"
  printf '서비스를 생략하면 모든 네트워크 서비스에 적용합니다.\n'
}

wifi_device() {
  networksetup -listallhardwareports | awk '
    /Hardware Port: Wi-Fi/ { getline; if ($1 == "Device:") print $2 }
  ' | head -n 1
}

connect_hotspot() {
  [ -n "$HOTSPOT_SSID" ] || return 0
  device="$(wifi_device)"
  if [ -z "$device" ]; then
    printf '%s\n' 'Wi-Fi 장치를 찾지 못해 핫스팟 자동 연결을 건너뜁니다.' >&2
    return 0
  fi
  if [ -n "$HOTSPOT_PASSWORD" ]; then
    networksetup -setairportnetwork "$device" "$HOTSPOT_SSID" "$HOTSPOT_PASSWORD"
  else
    networksetup -setairportnetwork "$device" "$HOTSPOT_SSID"
  fi
}

default_gateway() {
  route -n get default 2>/dev/null | awk '/gateway:/ { print $2; exit }'
}

services() {
  if [ -n "$TARGET_SERVICE" ]; then
    printf '%s\n' "$TARGET_SERVICE"
  else
    networksetup -listallnetworkservices | sed '1d; s/^\*//'
  fi
}

apply_service() {
  service="$1"
  [ -n "$service" ] || return 0

  if ! networksetup -getinfo "$service" >/dev/null 2>&1; then
    printf '건너뜀: %s\n' "$service" >&2
    return 0
  fi

  failed=0
  networksetup -setwebproxy "$service" "$HOST" "$HTTP_PORT" off || failed=1
  networksetup -setsecurewebproxy "$service" "$HOST" "$HTTP_PORT" off || failed=1
  networksetup -setsocksfirewallproxy "$service" "$HOST" "$SOCKS_PORT" off || failed=1
  networksetup -setwebproxystate "$service" on || failed=1
  networksetup -setsecurewebproxystate "$service" on || failed=1
  networksetup -setsocksfirewallproxystate "$service" on || failed=1

  if [ "$failed" -eq 0 ]; then
    printf '적용 완료: %s\n' "$service"
  else
    printf '적용 실패: %s\n' "$service" >&2
  fi
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

connect_hotspot

if [ -z "$HOST" ] || [ "$HOST" = "auto" ]; then
  HOST="$(default_gateway)"
fi

if [ -z "$HOST" ]; then
  printf '%s\n' '프록시 호스트를 찾지 못했습니다. iPhone 핫스팟 또는 USB 테더링 연결 후 다시 실행하거나 호스트를 직접 입력하십시오.' >&2
  exit 1
fi

services | while IFS= read -r service; do
  apply_service "$service"
done

printf 'macOS 프록시 설정이 완료되었습니다.\n'
printf 'HTTP/HTTPS: %s:%s\n' "$HOST" "$HTTP_PORT"
printf 'SOCKS: %s:%s\n' "$HOST" "$SOCKS_PORT"
