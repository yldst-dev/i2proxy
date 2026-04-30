# i2proxy

iPhone의 iSH 앱에서 HTTP/SOCKS 프록시를 실행하고, macOS에서 해당 프록시를 시스템 프록시로 적용하거나 초기화하는 스크립트입니다.

## 설치

```sh
if [ -d i2proxy ]; then cd i2proxy; else git clone https://github.com/yldst-dev/i2proxy.git i2proxy && cd i2proxy; fi
```

## 지원 범위

이 구성은 macOS 앱이 시스템 프록시 설정을 따르는 트래픽에 적용됩니다. HTTP, HTTPS, SOCKS 기반 TCP 연결을 대상으로 하며, iOS/iSH 앱 샌드박스 제약 때문에 iPhone을 완전한 라우터처럼 동작시켜 UDP, ICMP, 모든 인바운드, 모든 프로토콜, 전체 경로를 강제 터널링하는 방식은 지원되지 않습니다.

통신사 제한 우회, 속도 제한 해제, iOS 시스템 전체 네트워크 언락은 이 스크립트로 수행할 수 없습니다. 프록시 자체는 인증 없이 열리므로 iPhone 핫스팟이나 USB 테더링처럼 신뢰하는 연결에서만 사용하십시오.

## iSH에서 프록시 시작

```sh
chmod +x scripts/ish/start-iproxy.sh scripts/ish/stop-iproxy.sh
./scripts/ish/start-iproxy.sh
```

기본 포트는 HTTP `3128`, SOCKS `1080`입니다.

이 스크립트는 Alpine 기본 저장소의 `tinyproxy`와 `dante-server`를 사용합니다.

포트를 바꾸려면 다음처럼 실행하십시오.

```sh
IPROXY_HTTP_PORT=8080 IPROXY_SOCKS_PORT=1081 ./scripts/ish/start-iproxy.sh
```

## macOS에서 프록시 적용

iPhone 핫스팟 또는 USB 테더링에 macOS를 연결한 뒤 실행하십시오.

```sh
chmod +x scripts/macos/apply-iproxy.sh scripts/macos/reset-iproxy.sh
./scripts/macos/apply-iproxy.sh
```

호스트를 생략하면 macOS의 기본 게이트웨이를 프록시 호스트로 사용합니다. iSH에서 출력된 주소 또는 iPhone 핫스팟 게이트웨이를 직접 지정할 수도 있습니다.

```sh
./scripts/macos/apply-iproxy.sh 172.20.10.1 1080 3128
```

특정 네트워크 서비스에만 적용하려면 네 번째 인자로 서비스명을 입력하십시오.

```sh
./scripts/macos/apply-iproxy.sh 172.20.10.1 1080 3128 "Wi-Fi"
```

핫스팟 Wi-Fi 자동 연결이 필요하면 환경 변수를 사용하십시오.

```sh
IPROXY_HOTSPOT_SSID="iPhone" IPROXY_HOTSPOT_PASSWORD="password" ./scripts/macos/apply-iproxy.sh
```

## macOS 프록시 초기화

```sh
./scripts/macos/reset-iproxy.sh
```

특정 네트워크 서비스만 초기화할 수 있습니다.

```sh
./scripts/macos/reset-iproxy.sh "Wi-Fi"
```

## iSH에서 프록시 중지

```sh
./scripts/ish/stop-iproxy.sh
```

## Docker 기반 Alpine 검증

iSH와 유사한 x86 Alpine 환경에서 스크립트를 검증하려면 다음을 실행하십시오.

```sh
chmod +x tests/ish-alpine-docker.sh
./tests/ish-alpine-docker.sh
```
