#!/usr/bin/env bash
# =============================================================================
# build_ipa.sh — сборка готового .ipa для установки через Sideloadly/AltStore.
#
# Требования: macOS, Xcode 15+, Flutter 3.19+, выполненный scripts/build_core.sh
#
# Использование:
#   ./scripts/build_ipa.sh                 # автоматическое подпись (DEVELOPMENT_TEAM из env)
#   DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/build_ipa.sh
# =============================================================================
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

if [ ! -d "ios/Frameworks/LibXray.xcframework" ]; then
  echo "Сначала выполните ./scripts/build_core.sh (нет ios/Frameworks)" >&2
  exit 1
fi

echo "==> flutter pub get"
flutter pub get

# Проект использует CocoaPods; SPM-интеграцию Flutter отключаем,
# чтобы инструмент не пытался мигрировать Xcode-проект.
flutter config --no-enable-swift-package-manager >/dev/null 2>&1 || true

# Если DEVELOPMENT_TEAM не задан — собираем без подписи
# (IPA подпишет Sideloadly при установке).
if [ -n "${DEVELOPMENT_TEAM:-}" ]; then
  BUILD_FLAGS="--release"
  echo "==> flutter build ios --release (team: $DEVELOPMENT_TEAM)"
else
  BUILD_FLAGS="--release --no-codesign"
  echo "==> flutter build ios --release --no-codesign"
fi
flutter build ios $BUILD_FLAGS

APP_PATH="build/ios/iphoneos/Runner.app"
if [ ! -d "$APP_PATH" ]; then
  echo "Runner.app не найден: $APP_PATH" >&2
  exit 1
fi

STAGE="build/ios/stage"
rm -rf "$STAGE"
mkdir -p "$STAGE/Payload"
cp -R "$APP_PATH" "$STAGE/Payload/Runner.app"

# Удаляем код-подписи из копий (Sideloadly подпишет заново).
codesign --remove-signature "$STAGE/Payload/Runner.app" 2>/dev/null || true
find "$STAGE/Payload" -name '_CodeSignature' -type d -prune -exec rm -rf {} + 2>/dev/null || true

echo "==> Формирование IPA"
IPA_PATH="$ROOT_DIR/AuraVPN.ipa"
rm -f "$IPA_PATH"
(cd "$STAGE" && zip -qr "$IPA_PATH" Payload)

echo ""
echo "Готово: $IPA_PATH"
echo "Установка: откройте IPA в Sideloadly (см. docs/Sideloadly.md)"
