# ⚡ Aura VPN — VPN-клиент для iPhone с раздачей Wi-Fi

**Aura VPN** — красивое приложение на Flutter (в стиле [Happ](https://apps.apple.com/us/app/happ-proxy-utility/id6504287215)),
которое подключает iPhone к VPN по подписке и **раздаёт Wi-Fi с уже
защищённым трафиком** на ноутбук, ТВ и другие устройства.

> Исходный код полностью открыт. Приложение не содержит серверов и не
> продаёт подписки — вы импортируете **свои** конфигурации.

---

## ✨ Возможности

### Протоколы (ядро Xray-core)
| Протокол | Подробности |
|---|---|
| **VLESS** | в т.ч. **REALITY** (`pbk`, `sid`, `spx`), flow `xtls-rprx-vision` |
| **VMess** | AEAD, шифрование auto/aes-128-gcm/chacha20-poly1305 |
| **Trojan** | TLS + все транспорты |
| **Shadowsocks** | все основные методы (aes-256-gcm, chacha20-ietf-poly1305…) |
| **Hysteria2** | salamander-обфускация, port hopping (`mport`) |
| **TUIC** | v5, congestion control, UDP relay |
| **SOCKS5** | с авторизацией |

### Транспорты
`TCP` · `WebSocket` · `gRPC` · `HTTP/2` · **`XHTTP`** · `HTTPUpgrade` · `mKCP` · `QUIC`

### Защита
`TLS` · **`REALITY`** · `uTLS fingerprint` (chrome/firefox/…) · `ALPN` · `ECH` (через `extra`)

### Подписки
- Импорт по URL (base64-текст со ссылками `vless:// vmess:// trojan:// ss:// hysteria2:// tuic:// socks://`)
- Заголовок `subscription-userinfo` (расход трафика, срок действия)
- QR-коды, вставка нескольких ссылок, ручное создание профиля
- Ping-тест серверов, быстрое переключение

### 📶 Раздача Wi-Fi с VPN — фирменная функция
1. **Личная точка доступа iPhone** — телефон раздаёт Wi-Fi, VPN остаётся включённым;
2. **Общий VPN-прокси** — Aura открывает SOCKS5 (с паролем) на адресе точки
   доступа: любое устройство указывает его в настройках прокси и получает
   трафик **гарантированно через VPN** (QR-код и инструкции встроены);
3. **`includeAllNetworks`** — туннель пытается захватить и трафик личной точки
   доступа целиком (подробности и ограничения iOS — в [docs/HOTSPOT.md](docs/HOTSPOT.md)).

### Интерфейс
Тёмная тема «Aurora», glassmorphism, анимированная кнопка подключения,
живой график скорости, статистика сессии, логи ядра, RU/EN.

---

## 📱 Установка на iPhone (Sideloadly)

### Шаг 1. Получите IPA

**Вариант А — готовый файл (рекомендуется):**
1. Скачайте **[AuraVPN.ipa](../../releases/download/v1.0.0/AuraVPN.ipa)** из
   [Releases](../../releases) — уже собран и проверен CI.

**Вариант Б — соберите сами за 3 команды (macOS):**
```bash
./scripts/build_core.sh        # ядра Xray + tun2socks (нужны Xcode 15+, Go, Python 3)
flutter pub get                # зависимости Flutter
./scripts/build_ipa.sh         # → AuraVPN.ipa в корне
```
Подробности и решение проблем: [docs/BUILD.md](docs/BUILD.md).

### Шаг 2. Установите через Sideloadly

1. Скачайте [Sideloadly](https://sideloadly.io/) (macOS/Windows).
2. Подключите iPhone кабелем, откройте Sideloadly.
3. Перетащите `AuraVPN.ipa` в окно, укажите Apple ID и своё устройство → **Start**.
4. На iPhone: Настройки → Основные → VPN и управление устройством → доверяйте разработчику.
5. Откройте **Aura VPN** → импортируйте подписку → нажмите большую кнопку.

Пошагово с картинками и частыми проблемами: **[docs/Sideloadly.md](docs/Sideloadly.md)**.

> ⚠️ **Важно:** функция VPN (Network Extension) требует entitlements
> `packet-tunnel-provider`. Бесплатный Apple ID **не может** подписать
> расширение — нужен платный аккаунт Apple Developer (99 $/год) или
> сертификат от подписки-сервиса. Sideloadly поддерживает оба варианта.

---

## 🛠 Сборка (macOS)

```bash
# 0) Требования: Xcode 15+, Flutter 3.19+, Go 1.23+, Python 3, git

# 1) Собрать нативные ядра (Xray-core + tun2socks) — один раз
./scripts/build_core.sh

# 2) Сгенерировать иконку (уже готова в репозитории, опционально)
python3 scripts/make_icons.py

# 3) Собрать IPA
DEVELOPMENT_TEAM=ВАШ_TEAM_ID ./scripts/build_ipa.sh
# → AuraVPN.ipa в корне репозитория
```

Подробности, включая ручную сборку через Xcode: **[docs/BUILD.md](docs/BUILD.md)**.

### Проверка кода и тесты

```bash
flutter pub get
flutter analyze
flutter test
```

---

## 🏗 Архитектура

```
┌─────────────────────────── iPhone ───────────────────────────┐
│  Flutter UI (Dart)                                           │
│    │  MethodChannel com.auravpn.app/vpn                      │
│    ▼                                                         │
│  NETunnelProviderManager (Runner)                            │
│    │  startVPNTunnel                                         │
│    ▼                                                         │
│  PacketTunnel (Network Extension)                            │
│    ├─ Xray-core (libXray) ──► ваш VPN-сервер (VLESS/…)       │
│    └─ hev-socks5-tunnel ⇄ utun (весь трафик устройства)      │
│                                                              │
│  Wi-Fi Sharing: SOCKS5-инбаунд Xray на 0.0.0.0:10809         │
│    └─► устройства на личной точке доступа                    │
└──────────────────────────────────────────────────────────────┘
```

Подробнее — [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

---

## 📂 Структура проекта

```
lib/                  Flutter-приложение (UI, парсеры, генератор Xray-конфига)
  core/               тема, строки (RU/EN), форматирование
  models/             VpnProfile, Subscription, статусы
  services/           VPN-мост, парсер ссылок, подписки, Xray-конфиги
  screens/            Главная, Серверы, Wi-Fi, Настройки, Логи, Импорт
  widgets/            glass-карточки, кнопка подключения, графики
ios/
  Runner/             AppDelegate, VPNManager (NETunnelProviderManager)
  PacketTunnel/       PacketTunnelProvider + libXray + hev-socks5-tunnel
  Shared/             App Group контейнер, логи, статистика
scripts/              сборка ядер, иконки, IPA
docs/                 инструкции (сборка, Sideloadly, Wi-Fi, архитектура)
test/                 тесты парсера ссылок и генератора конфигов
```

---

## ❓ Частые вопросы

**Почему VPN требует платный Apple ID?**
Apple выдаёт entitlement `com.apple.developer.networking.networkextension`
(packet-tunnel-provider) только платным аккаунтам. Это ограничение Apple,
а не приложения.

**Как раздать VPN на ноутбук?**
Включите VPN → вкладка «Wi-Fi» → включите «Раздавать прокси по Wi-Fi» →
включите «Личную точку доступа» на iPhone → на ноутбуке укажите SOCKS5-прокси
`172.20.10.1:10809` (QR/инструкции на экране). Подробнее: [docs/HOTSPOT.md](docs/HOTSPOT.md).

**Работает ли с моей подпиской?**
Поддерживаются все распространённые форматы share-ссылок и base64-подписки.
Формат Clash/Mihomo YAML не поддерживается (используйте провайдеров,
отдающих vless/vmess-ссылки).

**Где хранятся данные?**
Только на устройстве (SharedPreferences + App Group контейнер).
Приложение не отправляет данные наружу.

---

## 📄 Лицензия

MIT — см. [LICENSE](LICENSE).
Ядра: [Xray-core](https://github.com/XTLS/Xray-core) (MPL-2.0),
[libXray](https://github.com/XTLS/libXray), [hev-socks5-tunnel](https://github.com/heiher/hev-socks5-tunnel) (MIT).
