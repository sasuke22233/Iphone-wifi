#!/usr/bin/env bash
# =============================================================================
# build_core.sh — сборка нативных ядер для iOS:
#   1) LibXray.xcframework  (Xray-core, github.com/XTLS/libXray, cgo-сборка)
#   2) HevSocks5Tunnel.xcframework (tun2socks, github.com/heiher/hev-socks5-tunnel)
#
# Требования (macOS):
#   - Xcode 15+ (с command line tools)
#   - Go 1.23+  (brew install go)
#   - Python 3   (для build/main.py libXray)
#   - git
#
# Результат:
#   ios/Frameworks/LibXray.xcframework
#   ios/Frameworks/HevSocks5Tunnel.xcframework
#   ios/Frameworks/include/libXray.h
#   ios/Frameworks/include/hev_socks5_tunnel.h
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THIRD_PARTY="$ROOT_DIR/third_party"
OUT_DIR="$ROOT_DIR/ios/Frameworks"
INCLUDE_DIR="$OUT_DIR/include"

# Закреплённые версии (обновляйте осознанно).
LIBXRAY_REPO="https://github.com/XTLS/libXray.git"
LIBXRAY_REF="main"
HEV_REPO="https://github.com/heiher/hev-socks5-tunnel.git"
HEV_REF="master"

mkdir -p "$THIRD_PARTY" "$OUT_DIR" "$INCLUDE_DIR"

echo "==> [1/3] libXray ($LIBXRAY_REF)"
if [ ! -d "$THIRD_PARTY/libXray" ]; then
  git clone --depth 1 --branch "$LIBXRAY_REF" "$LIBXRAY_REPO" "$THIRD_PARTY/libXray"
fi

cd "$THIRD_PARTY/libXray"
# cgo-сборка: iOS/iOS Simulator/macOS/tvOS + заголовок libXray.h с CGoInvoke/CGoFree.
python3 build/main.py apple cgo

# Ищем собранный xcframework.
LIBXRAY_XCFRAMEWORK="$(find "$THIRD_PARTY/libXray" -name 'LibXray.xcframework' -type d | head -n1)"
if [ -z "$LIBXRAY_XCFRAMEWORK" ]; then
  echo "LibXray.xcframework не найден после сборки" >&2
  exit 1
fi
rm -rf "$OUT_DIR/LibXray.xcframework"
cp -R "$LIBXRAY_XCFRAMEWORK" "$OUT_DIR/LibXray.xcframework"

LIBXRAY_HEADER="$(find "$THIRD_PARTY/libXray" -name 'libXray.h' | head -n1 || true)"
if [ -n "$LIBXRAY_HEADER" ]; then
  cp "$LIBXRAY_HEADER" "$INCLUDE_DIR/libXray.h"
else
  echo "!! libXray.h не найден — bridging header будет использовать резервные объявления"
fi

echo "==> [2/3] hev-socks5-tunnel ($HEV_REF)"
if [ ! -d "$THIRD_PARTY/hev-socks5-tunnel" ]; then
  git clone --recursive --depth 1 --branch "$HEV_REF" "$HEV_REPO" "$THIRD_PARTY/hev-socks5-tunnel"
fi

cd "$THIRD_PARTY/hev-socks5-tunnel"
# build-apple.sh собирает HevSocks5Tunnel.xcframework (iOS + macOS).
./build-apple.sh

HEV_XCFRAMEWORK="$(find "$THIRD_PARTY/hev-socks5-tunnel" -name 'HevSocks5Tunnel.xcframework' -type d | head -n1)"
if [ -z "$HEV_XCFRAMEWORK" ]; then
  echo "HevSocks5Tunnel.xcframework не найден после сборки" >&2
  exit 1
fi
rm -rf "$OUT_DIR/HevSocks5Tunnel.xcframework"
cp -R "$HEV_XCFRAMEWORK" "$OUT_DIR/HevSocks5Tunnel.xcframework"

HEV_HEADER="$(find "$THIRD_PARTY/hev-socks5-tunnel" -name 'hev_socks5_tunnel.h' | head -n1 || true)"
if [ -n "$HEV_HEADER" ]; then
  cp "$HEV_HEADER" "$INCLUDE_DIR/hev_socks5_tunnel.h"
fi

echo "==> [3/3] Готово:"
ls -la "$OUT_DIR"
ls -la "$INCLUDE_DIR" 2>/dev/null || true
echo ""
echo "Теперь можно собирать приложение: ./scripts/build_ipa.sh"
