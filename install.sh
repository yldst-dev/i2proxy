#!/bin/sh
set -eu

RAW_BASE="${IPROXY_RAW_BASE:-https://raw.githubusercontent.com/yldst-dev/i2proxy/main}"
TARGET_DIR="${IPROXY_DIR:-$HOME/i2proxy}"

ensure_fetcher() {
  if command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1; then
    return 0
  fi

  if command -v apk >/dev/null 2>&1; then
    apk update
    apk add curl
    return 0
  fi

  printf '%s\n' 'curl 또는 wget이 필요합니다.' >&2
  exit 1
}

fetch() {
  url="$1"
  dest="$2"
  tmp="$dest.tmp.$$"
  rm -f "$tmp"

  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$url" -o "$tmp"
  else
    wget -qO "$tmp" "$url"
  fi

  mv "$tmp" "$dest"
}

download() {
  path="$1"
  dest="$TARGET_DIR/$path"
  dir="$(dirname "$dest")"
  mkdir -p "$dir"
  fetch "$RAW_BASE/$path" "$dest"
}

ensure_fetcher
mkdir -p "$TARGET_DIR"

download README.md
download install.sh
download scripts/ish/start-iproxy.sh
download scripts/ish/stop-iproxy.sh
download scripts/ish/update-iproxy.sh
download scripts/macos/apply-iproxy.sh
download scripts/macos/reset-iproxy.sh
download tests/ish-alpine-docker.sh

chmod +x "$TARGET_DIR/install.sh"
chmod +x "$TARGET_DIR/scripts/ish/start-iproxy.sh"
chmod +x "$TARGET_DIR/scripts/ish/stop-iproxy.sh"
chmod +x "$TARGET_DIR/scripts/ish/update-iproxy.sh"
chmod +x "$TARGET_DIR/scripts/macos/apply-iproxy.sh"
chmod +x "$TARGET_DIR/scripts/macos/reset-iproxy.sh"
chmod +x "$TARGET_DIR/tests/ish-alpine-docker.sh"

printf 'i2proxy 파일을 업데이트했습니다: %s\n' "$TARGET_DIR"
printf '다음 명령으로 이동하십시오: cd %s\n' "$TARGET_DIR"
