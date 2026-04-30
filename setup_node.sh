#!/bin/sh
# ============================================================
# iOS iSH (Alpine Linux) 서버 구성 스크립트
# 역할: SSH 서버 설치, 설정, 백그라운드 서비스 구동
# ============================================================

set -e

# ----------------------------------------------------------
# 1. 패키지 설치 및 호스트 키 생성
# ----------------------------------------------------------
echo ">> openssh 설치 중..."
apk update && apk add openssh

echo ">> SSH 호스트 키 생성 중..."
ssh-keygen -A

# ----------------------------------------------------------
# 2. sshd_config 설정 — 포트 포워딩 / 게이트웨이 포트 활성화
# ----------------------------------------------------------
SSHD_CONFIG="/etc/ssh/sshd_config"

echo ">> sshd_config 설정 적용 중..."
sed -i 's/^#\?AllowTcpForwarding.*/AllowTcpForwarding yes/' "$SSHD_CONFIG"
sed -i 's/^#\?GatewayPorts.*/GatewayPorts yes/' "$SSHD_CONFIG"
# 설정이 아예 없으면 추가
grep -q '^AllowTcpForwarding' "$SSHD_CONFIG" || echo 'AllowTcpForwarding yes' >> "$SSHD_CONFIG"
grep -q '^GatewayPorts' "$SSHD_CONFIG"       || echo 'GatewayPorts yes' >> "$SSHD_CONFIG"

# ----------------------------------------------------------
# 3. 사용자 비밀번호 설정
# ----------------------------------------------------------
echo ""
echo "=========================================="
echo "  SSH 접속용 비밀번호를 설정합니다."
echo "=========================================="
passwd

# ----------------------------------------------------------
# 4. 백그라운드 서비스 실행
# ----------------------------------------------------------

# 위치 서비스 유지 (iOS가 iSH 프로세스를 kill하지 않도록)
cat /dev/location > /dev/null &

# SSH 데몬 시작
echo ">> sshd 시작 중..."
/usr/sbin/sshd
echo ">> sshd 실행 완료."

# 현재 IP 확인 (핫스팟 게이트웨이 주소 표시)
echo ""
echo "=========================================="
echo "  서버 준비 완료"
echo "  iSH IP 주소:"
ip addr show | grep 'inet ' | grep -v '127.0.0.1' | awk '{print "    " $2}'
echo ""
echo "  macOS에서 아래 명령으로 연결하세요:"
echo "    ./connect_tunnel.sh"
echo "=========================================="
