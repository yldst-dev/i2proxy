#!/bin/sh
set -eu

TARGET_SERVICE="${1:-${IPROXY_SERVICE:-}}"

usage() {
  printf '사용법: %s [network_service]\n' "$0"
  printf '서비스를 생략하면 모든 네트워크 서비스의 HTTP/HTTPS/SOCKS 프록시를 끕니다.\n'
}

services() {
  if [ -n "$TARGET_SERVICE" ]; then
    printf '%s\n' "$TARGET_SERVICE"
  else
    networksetup -listallnetworkservices | sed '1d; s/^\*//'
  fi
}

reset_service() {
  service="$1"
  [ -n "$service" ] || return 0

  if ! networksetup -getinfo "$service" >/dev/null 2>&1; then
    printf '건너뜀: %s\n' "$service" >&2
    return 0
  fi

  failed=0
  networksetup -setwebproxystate "$service" off || failed=1
  networksetup -setsecurewebproxystate "$service" off || failed=1
  networksetup -setsocksfirewallproxystate "$service" off || failed=1
  networksetup -setautoproxystate "$service" off 2>/dev/null || true
  networksetup -setproxyautodiscovery "$service" off 2>/dev/null || true

  if [ "$failed" -eq 0 ]; then
    printf '초기화 완료: %s\n' "$service"
  else
    printf '초기화 실패: %s\n' "$service" >&2
  fi
}

case "${1:-}" in
  -h|--help)
    usage
    exit 0
    ;;
esac

services | while IFS= read -r service; do
  reset_service "$service"
done

printf 'macOS 프록시 설정을 끈 상태로 초기화했습니다.\n'
