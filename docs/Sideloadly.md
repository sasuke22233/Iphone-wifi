# Установка Aura VPN через Sideloadly

Инструкция описывает установку собранного `AuraVPN.ipa` на iPhone без App Store.

---

## 0. Что нужно

| | |
|---|---|
| iPhone (iOS 15+) | и кабель Lightning/USB-C |
| Компьютер | Windows или macOS |
| [Sideloadly](https://sideloadly.io/) | бесплатная утилита |
| Apple ID | **платный** Developer (99 $/год) — см. предупреждение ниже |
| Файл `AuraVPN.ipa` | собранный по [BUILD.md](BUILD.md) |

> ### ⚠️ Почему нужен платный Apple ID
> Aura VPN использует **Network Extension (Packet Tunnel)** — системный
> VPN iOS. Apple разрешает подписывать такие расширения только аккаунтам
> Apple Developer Program. С бесплатным Apple ID приложение установится, но
> **VPN-подключение не запустится** (расширение будет отклонено системой).
>
> Альтернативы: сертификат от подписочного сервиса подписки приложений
> ( Scarlet / AppleP12-сервисы и т.п.), если он поддерживает entitlements
> `com.apple.developer.networking.networkextension`.

---

## 1. Подготовка Apple Developer App ID

1. Откройте [developer.apple.com/account/resources/identifiers/list](https://developer.apple.com/account/resources/identifiers/list)
2. Создайте **App ID** (Explicit) с Bundle ID `com.auravpn.app`
3. Включите **Capabilities**:
   - ✅ App Groups — группа `group.com.auravpn.app`
   - ✅ Network Extensions — `Packet Tunnel`
   - ✅ Personal VPN
4. Создайте **Provisioning Profile** (Development) для этого App ID
   с вашим устройством и скачайте его.
5. (Необязательно) откройте профиль в Xcode / установите в Sideloadly.

> Если вы меняли Bundle ID при сборке — создавайте App ID с ним же.

---

## 2. Установка через Sideloadly (macOS)

1. Установите и откройте **Sideloadly**.
2. Подключите iPhone кабелем, разблокируйте, нажмите «Trust» на телефоне.
3. В Sideloadly:
   - перетащите `AuraVPN.ipa` в окно;
   - **Apple account** — ваш Apple ID (email);
   - **Device** — выберите iPhone;
   - Advanced → *Use automatic provisioning* **или**
     укажите скачанный provisioning profile (если автоматика не выдаёт
     Network Extension entitlements).
4. Нажмите **Start**. При первом запросе введите пароль Apple ID
   (и код подтверждения).
5. Дождитесь «Done».

## 2а. Установка через Sideloadly (Windows)

Алгоритм тот же. Потребуется iTunes (или iCloud) с установленными
драйверами Apple. При запросе пароля используйте «app-specific password»
с [appleid.apple.com](https://appleid.apple.com) → Безопасность →
«Пароли приложений», если включена двухфакторная аутентификация.

---

## 3. Первый запуск на iPhone

1. На iPhone: **Настройки → Основные → VPN и управление устройством** —
   доверяйте разработчику (если требуется).
2. Откройте **Aura VPN**.
3. Импортируйте подписку/ссылку (вкладка «Импорт»).
4. Нажмите большую кнопку подключения → разрешите добавление VPN-конфигурации.
5. Статус «Подключено» — готово.

---

## 4. Проблемы и решения

| Симптом | Причина / решение |
|---|---|
| `This app cannot be installed` / error 8100 | Бесплатный Apple ID или нет места на устройстве |
| Не появляется переключатель VPN | Профиль подписан без Network Extension entitlements — см. п. 1 |
| Через 7 дней приложение «отваливается» | Бесплатная подписка живёт 7 дней — переподпишите через Sideloadly |
| «Untrusted Developer» | Настройки → Основные → VPN и управление устройством → Доверять |
| Sideloadly требует app-specific password | appleid.apple.com → Безопасность → Пароли приложений |
| Не удаляется старая копия | Удалите приложение с телефона и установите заново |

---

## 5. Обновление

Просто повторите установку с новым `AuraVPN.ipa` поверх старой —
настройки и профили сохранятся (тот же Bundle ID и App Group).
