# Сборка Aura VPN (macOS)

## Требования

| Инструмент | Версия | Проверка |
|---|---|---|
| macOS | 13+ (Ventura и новее) | — |
| Xcode | 15+ | `xcodebuild -version` |
| Flutter | 3.19+ (stable) | `flutter --version` |
| Go | 1.23+ | `go version` |
| Python | 3.10+ | `python3 --version` |
| git | любой | `git --version` |

```bash
# Установка (Homebrew):
brew install go flutter python3 git
```

## Шаг 1. Сборка нативных ядер

```bash
./scripts/build_core.sh
```

Скрипт:
1. клонирует [XTLS/libXray](https://github.com/XTLS/libXray) и собирает
   `LibXray.xcframework` (cgo-режим: `python3 build/main.py apple cgo`);
2. клонирует [heiher/hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel)
   и собирает `HevSocks5Tunnel.xcframework` (`./build-apple.sh`);
3. складывает результат в `ios/Frameworks/` + заголовки в `ios/Frameworks/include/`.

> Ядра не хранятся в git (около 200 МБ) — собирайте локально.

## Шаг 2. Зависимости Flutter

```bash
flutter pub get
flutter analyze
flutter test
```

## Шаг 3. Сборка IPA

### Вариант А — скрипт

```bash
DEVELOPMENT_TEAM=XXXXXXXXXX ./scripts/build_ipa.sh
# → AuraVPN.ipa
```

### Вариант Б — вручную (Xcode)

1. `flutter build ios --release --no-codesign`
2. Откройте `ios/Runner.xcworkspace` в Xcode.
3. В таргетах **Runner** и **PacketTunnel** выберите вашу Team
   (Signing & Capabilities → Team). Bundle ID:
   - `com.auravpn.app`
   - `com.auravpn.app.packet-tunnel`

   При желании смените Bundle ID — **меняйте в обоих таргетах** и в
   `lib/core/constants.dart` (`bundleId`, `tunnelBundleId`, `appGroup`),
   `ios/Shared/SharedConstants.swift` и entitlements обоих таргетов.
4. Product → Archive → Distribute App → Custom → **Release** →
   «Export one app for local testing» → получите `.app`/`.ipa`.

## Возможные проблемы

### `LibXray.xcframework not found`
Не выполнен `scripts/build_core.sh` — сборка ядер идёт до сборки приложения.

### `Signing certificate ... doesn't include packet-tunnel-provider`
Сертификат/профиль без Network Extension entitlements. Нужен **платный**
Apple Developer (App ID с capabilities: App Groups + Network Extensions +
Personal VPN) или сертификат стороннего подписки-сервиса. См. `Sideloadly.md`.

### Ошибка `GeneratedPluginRegistrant.m not found`
`flutter pub get` не был запущен перед открытием Xcode. Запустите
`flutter build ios --no-codesign` — файл генерируется автоматически.

### CocoaPods
Плагины (shared_preferences и др.) подключаются через CocoaPods при первом
`flutter build ios`. Если что-то пошло не так:
```bash
cd ios && pod install --repo-update && cd ..
```

## Проверка на устройстве

VPN **не работает в симуляторе** — только физический iPhone (iOS 15+):

```bash
flutter run --release
# или установите IPA через Sideloadly
```

После установки: Настройки → Основные → VPN и управление устройством —
профиль «Aura VPN» должен появиться после первого запуска и нажатия кнопки
подключения (система спросит разрешение на добавление VPN-конфигурации).
