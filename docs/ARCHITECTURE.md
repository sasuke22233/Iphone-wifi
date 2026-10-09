# Архитектура Aura VPN

## Общая схема

```
┌─────────────────────────────── iPhone ───────────────────────────────┐
│                                                                      │
│  ┌──────────────┐   MethodChannel    ┌───────────────────────────┐   │
│  │  Flutter UI  │ ─────────────────► │  Runner (iOS app)         │   │
│  │  (Dart)      │ ◄───────────────── │  VPNManager               │   │
│  └──────────────┘   EventChannel     │  NETunnelProviderManager  │   │
│         │                            └────────────┬──────────────┘   │
│         │ AppState (ChangeNotifier)               │ startVPNTunnel   │
│         ▼                                         ▼                  │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │  PacketTunnel.appex (Network Extension)                      │    │
│  │                                                              │    │
│  │   packetFlow (utun) ⇄ socketpair ⇄ hev-socks5-tunnel         │    │
│  │                                    │ SOCKS5 (127.0.0.1)      │    │
│  │                                    ▼                         │    │
│  │                              Xray-core (libXray)             │    │
│  │                                    │ VLESS/VMess/Trojan/…    │    │
│  └────────────────────────────────────┼─────────────────────────┘    │
│                                       ▼                              │
│                                 VPN-сервер → интернет                │
│                                                                      │
│  App Group: group.com.auravpn.app                                    │
│    stats.json · access.log · error.log · tunnel.log                  │
└──────────────────────────────────────────────────────────────────────┘
```

## Компоненты

### 1. Flutter-приложение (`lib/`)
- **`state/app_state.dart`** — единый `ChangeNotifier`: профили, подписки,
  статус, статистика, настройки.
- **`services/share_link_parser.dart`** — парсер share-ссылок всех
  протоколов (vless/vmess/trojan/ss/hysteria2/tuic/socks) в `VpnProfile`.
- **`services/core_config_builder.dart`** — генератор JSON-конфигурации
  Xray-core и YAML для hev-socks5-tunnel из `VpnProfile`.
- **`services/vpn_service.dart`** — мост к MethodChannel/EventChannel.

### 2. Runner (основное приложение, Swift)
- **`VPNSwift.swift`** — `NETunnelProviderManager`:
  создание VPN-профиля, `startVPNTunnel`/`stopVPNTunnel`, чтение статистики
  и логов из App Group, запрос версии ядра через libXray.
- Ключевые опции протокола туннеля:
  `includeAllNetworks`, `excludeLocalNetworks`, `enforceRoutes` — захват
  трафика личной точки доступа (см. HOTSPOT.md).

### 3. PacketTunnel (Network Extension, Swift)
- **`PacketTunnelProvider.swift`**:
  1. читает `providerConfiguration` (xrayJson, hevYaml, опции);
  2. резолвит адрес сервера и добавляет его в **excludedRoutes**
     (защита от петли: соединение с сервером идёт мимо туннеля);
  3. выставляет `NEPacketTunnelNetworkSettings` (198.18.0.2/24, DNS);
  4. запускает Xray через **libXray** (`Invoke runXray`, apiVersion 3);
  5. создаёт `socketpair` и мостит `packetFlow` ⇄ hev-socks5-tunnel;
  6. пишет `stats.json` каждую секунду (hev_socks5_tunnel_stats).
- **`XrayCore.swift`** — обёртка `CGoInvoke`/`CGoFree`.
- **`HevTunnel.swift` + `HevShim.c`** — обёртка hev-socks5-tunnel
  (`hev_socks5_tunnel_main_from_str` и др.).

### 4. Нативные ядра
| Ядро | Роль |
|---|---|
| [Xray-core](https://github.com/XTLS/Xray-core) через [libXray](https://github.com/XTLS/libXray) | прокси-протоколы, TLS/REALITY, транспорты |
| [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) | tun2socks: IP-пакеты utun → SOCKS5-соединения |

Связка Xray + hev-socks5-tunnel — проверенная схема (используется в
открытых iOS-клиентах): расширение не эмулирует сетевой стек, а
перенаправляет пакеты в локальный SOCKS-инбаунд Xray.

## Потоки данных

### Подключение
1. UI → `VpnService.connect(payload)` (payload из `CoreConfigBuilder`).
2. `VPNManager` сохраняет `providerConfiguration` и вызывает
   `startVPNTunnel`.
3. Extension стартует Xray → hev → мост; статус летит в UI через
   `NEVPNStatusDidChange` → EventChannel.

### Статистика
`HevTunnel.stats()` → `stats.json` (App Group) → `VPNManager.stats()` →
UI (счётчик скорости и график за 60 секунд).

### Раздача Wi-Fi
`CoreConfigBuilder.buildXrayConfig(listenAll: true)` добавляет SOCKS/HTTP
инбаунды на `0.0.0.0` (порт 10809/10808) с опциональной авторизацией —
устройства на личной точке доступа ходят через них в VPN.

## Безопасность
- Все данные — локально (SharedPreferences + App Group).
- Общий прокси можно закрыть логином/паролем (Xray socks `auth=password`).
- REALITY/TLS — стандартные механизмы Xray-core.
- Приложение не содержит телеметрии.

## Сборка (связь компонентов)
```
scripts/build_core.sh
  ├─ libXray (python3 build/main.py apple cgo)  → ios/Frameworks/LibXray.xcframework
  └─ hev-socks5-tunnel (./build-apple.sh)       → ios/Frameworks/HevSocks5Tunnel.xcframework

flutter build ios
  ├─ генерирует GeneratedPluginRegistrant
  ├─ линкует оба xcframework в Runner и PacketTunnel
  └─ Embed App Extensions кладёт PacketTunnel.appex в Runner.app/PlugIns/
```
