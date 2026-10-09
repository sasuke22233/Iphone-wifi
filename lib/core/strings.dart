import 'package:flutter/material.dart';

/// Простая локализация (RU/EN) без генерации кода.
class S {
  S(this.locale);

  final Locale locale;

  static S of(BuildContext context) {
    final localizations = Localizations.of<S>(context, S);
    if (localizations != null) return localizations;
    return S(const Locale('ru'));
  }

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  String t(String key) {
    final ruMap = _strings['ru'];
    final enMap = _strings['en'];
    if (locale.languageCode == 'en') {
      return enMap?[key] ?? ruMap?[key] ?? key;
    }
    return ruMap?[key] ?? key;
  }

  /// Короткий алиас.
  String call(String key) => t(key);
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['ru', 'en'].contains(locale.languageCode);

  @override
  Future<S> load(Locale locale) async => S(locale);

  @override
  bool shouldReload(_SDelegate old) => false;
}

const Map<String, Map<String, String>> _strings = {
  'ru': {
    // Общее
    'app_name': 'Aura VPN',
    'ok': 'ОК',
    'cancel': 'Отмена',
    'save': 'Сохранить',
    'delete': 'Удалить',
    'edit': 'Изменить',
    'copy': 'Копировать',
    'copied': 'Скопировано',
    'close': 'Закрыть',
    'retry': 'Повторить',
    'error': 'Ошибка',
    'search_hint': 'Поиск серверов…',
    'none': 'Нет',
    'enabled': 'Включено',
    'disabled': 'Выключено',
    'auto': 'Авто',

    // Навигация
    'nav_home': 'Главная',
    'nav_servers': 'Серверы',
    'nav_hotspot': 'Wi-Fi',
    'nav_settings': 'Настройки',

    // Статусы
    'status_disconnected': 'Отключено',
    'status_connecting': 'Подключение…',
    'status_connected': 'Подключено',
    'status_disconnecting': 'Отключение…',
    'status_reconnecting': 'Переподключение…',
    'status_error': 'Ошибка',

    // Главный экран
    'home_tap_to_connect': 'Нажмите, чтобы подключиться',
    'home_tap_to_disconnect': 'Нажмите, чтобы отключиться',
    'home_current_server': 'Текущий сервер',
    'home_no_server': 'Выберите сервер',
    'home_no_server_sub': 'Импортируйте подписку или добавьте профиль вручную',
    'home_download': 'Загрузка',
    'home_upload': 'Отдача',
    'home_ping': 'Задержка',
    'home_duration': 'Сессия',
    'home_quick_import': 'Импорт',
    'home_quick_hotspot': 'Раздача Wi-Fi',
    'home_quick_logs': 'Логи',
    'home_protected': 'Ваш трафик защищён',
    'home_unprotected': 'Подключитесь, чтобы защитить трафик',

    // Серверы
    'servers_title': 'Серверы',
    'servers_empty': 'Пока нет серверов',
    'servers_empty_sub':
        'Добавьте подписку или одиночный профиль — и они появятся здесь.',
    'servers_add': 'Добавить',
    'servers_all': 'Все',
    'servers_update_subs': 'Обновить подписки',
    'servers_updated': 'Подписки обновлены',
    'servers_count': 'серверов',
    'menu_connect': 'Подключить',
    'menu_share': 'Поделиться ссылкой',
    'menu_set_active': 'Сделать активным',
    'menu_speed_test': 'Проверить задержку',

    // Импорт
    'import_title': 'Импорт',
    'import_tab_link': 'Ссылка',
    'import_tab_sub': 'Подписка',
    'import_tab_qr': 'QR-код',
    'import_tab_manual': 'Вручную',
    'import_link_hint': 'vless://… vmess://… trojan://… ss://… hysteria2://…',
    'import_link_label': 'Ссылка или несколько ссылок',
    'import_sub_url': 'URL подписки',
    'import_sub_name': 'Название подписки',
    'import_sub_update': 'Интервал обновления',
    'import_add': 'Добавить',
    'import_scan_qr': 'Сканировать QR',
    'import_scan_hint': 'Наведите камеру на QR-код с конфигурацией',
    'import_success_one': 'Профиль добавлен',
    'import_success_many': 'Добавлено профилей: ',
    'import_invalid': 'Не удалось распознать ссылку',
    'import_sub_success': 'Подписка добавлена: ',
    'import_paste_error': 'Вставьте ссылку или URL подписки',

    // Редактор профиля
    'edit_title_new': 'Новый профиль',
    'edit_title_edit': 'Профиль',
    'edit_name': 'Название',
    'edit_protocol': 'Протокол',
    'edit_server': 'Сервер (домен/IP)',
    'edit_port': 'Порт',
    'edit_uuid': 'UUID / логин',
    'edit_password': 'Пароль',
    'edit_method': 'Метод шифрования',
    'edit_transport': 'Транспорт',
    'edit_security': 'Безопасность',
    'edit_sni': 'SNI / Server Name',
    'edit_flow': 'Flow',
    'edit_fingerprint': 'Отпечаток (uTLS)',
    'edit_public_key': 'REALITY Public Key (pbk)',
    'edit_short_id': 'REALITY Short ID (sid)',
    'edit_path': 'Path',
    'edit_host_header': 'Host',
    'edit_service_name': 'Service Name (gRPC)',
    'edit_alpn': 'ALPN',
    'edit_allow_insecure': 'Разрешить небезопасный TLS',
    'edit_obfs_password': 'Пароль обфускации',
    'edit_extra': 'XHTTP extra (JSON)',
    'edit_save': 'Сохранить профиль',

    // Wi-Fi / раздача
    'hotspot_title': 'Раздача Wi-Fi с VPN',
    'hotspot_hero':
        'Подключайте ноутбук, ТВ или второй телефон к точке доступа iPhone — '
            'и весь их трафик пойдёт через VPN.',
    'hotspot_personal_title': '1. Точка доступа iPhone',
    'hotspot_personal_sub':
        'Включите «Личная точка доступа» в Настройки → Сотовая связь. '
            'Телефон раздаёт Wi-Fi, VPN остаётся включённым.',
    'hotspot_proxy_title': '2. Общий VPN-прокси',
    'hotspot_proxy_sub':
        'Aura откроет SOCKS5-прокси на iPhone. Укажите его в Wi-Fi/прокси '
            'на подключённом устройстве — трафик пойдёт через VPN-туннель.',
    'hotspot_share_switch': 'Раздавать прокси по Wi-Fi',
    'hotspot_auth_switch': 'Защитить паролем',
    'hotspot_address': 'Адрес прокси',
    'hotspot_copy_address': 'Скопировать адрес',
    'hotspot_qr_hint': 'QR с настройками прокси',
    'hotspot_guide_title': 'Как подключить устройство',
    'hotspot_guide_ios': 'iPhone/iPad: Настройки → Wi-Fi → (i) → Прокси-сервер → Вручную → Сервер и Порт.',
    'hotspot_guide_android': 'Android: Настройки → Wi-Fi → сеть → Изменить → Дополнительно → Прокси → Ручной.',
    'hotspot_guide_pc': 'Windows/macOS: параметры прокси системы (SOCKS5) или в браузере.',
    'hotspot_include_all': 'Захватывать весь трафик (Personal Hotspot)',
    'hotspot_include_all_sub':
        'includeAllNetworks — старается провести через VPN и трафик, '
            'раздаваемый по личной точке доступа.',
    'hotspot_exclude_local': 'Исключить локальную сеть',
    'hotspot_exclude_local_sub':
        'Принтеры, Chromecast и роутер останутся доступны напрямую.',
    'hotspot_ios_limit_title': 'Важно про iOS',
    'hotspot_ios_limit':
        'Apple не даёт приложениям напрямую создавать точку доступа, а трафик '
            '«Личной точки доступа» не всегда проходит через VPN-туннель. '
            'Режим «Общий VPN-прокси» решает это: устройства получают прокси, '
            'который гарантированно идёт через VPN.',
    'hotspot_needs_connection': 'Сначала подключите VPN',
    'hotspot_active': 'Раздача активна',

    // Настройки
    'settings_title': 'Настройки',
    'settings_section_general': 'Общие',
    'settings_section_network': 'Сеть',
    'settings_section_share': 'Раздача Wi-Fi',
    'settings_section_core': 'Ядро и отладка',
    'settings_language': 'Язык',
    'settings_theme': 'Тема',
    'settings_theme_value': 'Тёмная (Aurora)',
    'settings_dns': 'DNS-серверы',
    'settings_dns_hint': 'через запятую: 1.1.1.1, 8.8.8.8',
    'settings_mtu': 'MTU',
    'settings_auto_connect': 'Автоподключение при запуске',
    'settings_auto_update_subs': 'Обновлять подписки при запуске',
    'settings_mux': 'Mux (мультиплексирование)',
    'settings_log_level': 'Уровень логов',
    'settings_socks_port': 'Порт локального SOCKS5',
    'settings_share_port': 'Порт общего прокси',
    'settings_share_user': 'Логин общего прокси',
    'settings_share_pass': 'Пароль общего прокси',
    'settings_about': 'О приложении',
    'settings_version': 'Версия',
    'settings_core_version': 'Версия ядра Xray',
    'settings_docs': 'Документация',
    'settings_license': 'Лицензия (MIT)',

    // Логи
    'logs_title': 'Логи',
    'logs_empty': 'Логи появятся после подключения',
    'logs_clear': 'Очистить',
    'logs_share': 'Поделиться',
    'logs_follow': 'Следить за логом',

    // Онбординг
    'onb_skip': 'Пропустить',
    'onb_next': 'Далее',
    'onb_start': 'Начать',
    'onb_1_title': 'Ваш VPN — ваши правила',
    'onb_1_sub':
        'VLESS (Reality), VMess, Trojan, Shadowsocks, Hysteria2, TUIC и XHTTP '
            '— импортируйте подписку одним нажатием.',
    'onb_2_title': 'Wi-Fi с VPN внутри',
    'onb_2_sub':
        'Раздавайте интернет с iPhone: ноутбук, ТВ и другие устройства '
            'получат трафик через VPN.',
    'onb_3_title': 'Быстро и красиво',
    'onb_3_sub':
        'Живая статистика, задержка серверов, логи и полный контроль '
            'над подключением.',
  },
  'en': {
    'app_name': 'Aura VPN',
    'ok': 'OK',
    'cancel': 'Cancel',
    'save': 'Save',
    'delete': 'Delete',
    'edit': 'Edit',
    'copy': 'Copy',
    'copied': 'Copied',
    'close': 'Close',
    'retry': 'Retry',
    'error': 'Error',
    'search_hint': 'Search servers…',
    'none': 'None',
    'enabled': 'Enabled',
    'disabled': 'Disabled',
    'auto': 'Auto',
    'nav_home': 'Home',
    'nav_servers': 'Servers',
    'nav_hotspot': 'Wi-Fi',
    'nav_settings': 'Settings',
    'status_disconnected': 'Disconnected',
    'status_connecting': 'Connecting…',
    'status_connected': 'Connected',
    'status_disconnecting': 'Disconnecting…',
    'status_reconnecting': 'Reconnecting…',
    'status_error': 'Error',
    'home_tap_to_connect': 'Tap to connect',
    'home_tap_to_disconnect': 'Tap to disconnect',
    'home_current_server': 'Current server',
    'home_no_server': 'Choose a server',
    'home_no_server_sub': 'Import a subscription or add a profile manually',
    'home_download': 'Download',
    'home_upload': 'Upload',
    'home_ping': 'Latency',
    'home_duration': 'Session',
    'home_quick_import': 'Import',
    'home_quick_hotspot': 'Wi-Fi sharing',
    'home_quick_logs': 'Logs',
    'home_protected': 'Your traffic is protected',
    'home_unprotected': 'Connect to protect your traffic',
    'servers_title': 'Servers',
    'servers_empty': 'No servers yet',
    'servers_empty_sub': 'Add a subscription or a single profile to see it here.',
    'servers_add': 'Add',
    'servers_all': 'All',
    'servers_update_subs': 'Update subscriptions',
    'servers_updated': 'Subscriptions updated',
    'servers_count': 'servers',
    'menu_connect': 'Connect',
    'menu_share': 'Share link',
    'menu_set_active': 'Set active',
    'menu_speed_test': 'Check latency',
    'import_title': 'Import',
    'import_tab_link': 'Link',
    'import_tab_sub': 'Subscription',
    'import_tab_qr': 'QR code',
    'import_tab_manual': 'Manual',
    'import_link_hint': 'vless://… vmess://… trojan://… ss://… hysteria2://…',
    'import_link_label': 'Link or multiple links',
    'import_sub_url': 'Subscription URL',
    'import_sub_name': 'Subscription name',
    'import_sub_update': 'Update interval',
    'import_add': 'Add',
    'import_scan_qr': 'Scan QR',
    'import_scan_hint': 'Point the camera at a QR code with configuration',
    'import_success_one': 'Profile added',
    'import_success_many': 'Profiles added: ',
    'import_invalid': 'Could not recognize the link',
    'import_sub_success': 'Subscription added: ',
    'import_paste_error': 'Paste a link or a subscription URL',
    'edit_title_new': 'New profile',
    'edit_title_edit': 'Profile',
    'edit_name': 'Name',
    'edit_protocol': 'Protocol',
    'edit_server': 'Server (host/IP)',
    'edit_port': 'Port',
    'edit_uuid': 'UUID / username',
    'edit_password': 'Password',
    'edit_method': 'Encryption method',
    'edit_transport': 'Transport',
    'edit_security': 'Security',
    'edit_sni': 'SNI / Server Name',
    'edit_flow': 'Flow',
    'edit_fingerprint': 'Fingerprint (uTLS)',
    'edit_public_key': 'REALITY Public Key (pbk)',
    'edit_short_id': 'REALITY Short ID (sid)',
    'edit_path': 'Path',
    'edit_host_header': 'Host',
    'edit_service_name': 'Service Name (gRPC)',
    'edit_alpn': 'ALPN',
    'edit_allow_insecure': 'Allow insecure TLS',
    'edit_obfs_password': 'Obfuscation password',
    'edit_extra': 'XHTTP extra (JSON)',
    'edit_save': 'Save profile',
    'hotspot_title': 'Wi-Fi sharing with VPN',
    'hotspot_hero':
        'Connect your laptop, TV or second phone to the iPhone hotspot — '
            'their traffic goes through the VPN.',
    'hotspot_personal_title': '1. iPhone Personal Hotspot',
    'hotspot_personal_sub':
        'Enable Personal Hotspot in Settings → Cellular. The phone shares '
            'Wi-Fi while the VPN stays connected.',
    'hotspot_proxy_title': '2. Shared VPN proxy',
    'hotspot_proxy_sub':
        'Aura opens a SOCKS5 proxy on the iPhone. Set it in Wi-Fi/proxy '
            'settings of the connected device — traffic goes through the VPN.',
    'hotspot_share_switch': 'Share proxy over Wi-Fi',
    'hotspot_auth_switch': 'Protect with password',
    'hotspot_address': 'Proxy address',
    'hotspot_copy_address': 'Copy address',
    'hotspot_qr_hint': 'QR with proxy settings',
    'hotspot_guide_title': 'How to connect a device',
    'hotspot_guide_ios': 'iPhone/iPad: Settings → Wi-Fi → (i) → Configure Proxy → Manual.',
    'hotspot_guide_android': 'Android: Settings → Wi-Fi → network → Modify → Proxy → Manual.',
    'hotspot_guide_pc': 'Windows/macOS: system proxy settings (SOCKS5) or in the browser.',
    'hotspot_include_all': 'Capture all traffic (Personal Hotspot)',
    'hotspot_include_all_sub':
        'includeAllNetworks — tries to route hotspot traffic through the VPN too.',
    'hotspot_exclude_local': 'Exclude local network',
    'hotspot_exclude_local_sub':
        'Printers, Chromecast and the router stay directly reachable.',
    'hotspot_ios_limit_title': 'Important about iOS',
    'hotspot_ios_limit':
        'Apple does not let apps create a hotspot directly and Personal '
            'Hotspot traffic does not always go through the VPN tunnel. '
            'The shared VPN proxy mode solves this: devices get a proxy that '
            'is guaranteed to go through the VPN.',
    'hotspot_needs_connection': 'Connect the VPN first',
    'hotspot_active': 'Sharing is active',
    'settings_title': 'Settings',
    'settings_section_general': 'General',
    'settings_section_network': 'Network',
    'settings_section_share': 'Wi-Fi sharing',
    'settings_section_core': 'Core & debug',
    'settings_language': 'Language',
    'settings_theme': 'Theme',
    'settings_theme_value': 'Dark (Aurora)',
    'settings_dns': 'DNS servers',
    'settings_dns_hint': 'comma separated: 1.1.1.1, 8.8.8.8',
    'settings_mtu': 'MTU',
    'settings_auto_connect': 'Auto-connect on launch',
    'settings_auto_update_subs': 'Update subscriptions on launch',
    'settings_mux': 'Mux (multiplexing)',
    'settings_log_level': 'Log level',
    'settings_socks_port': 'Local SOCKS5 port',
    'settings_share_port': 'Shared proxy port',
    'settings_share_user': 'Shared proxy username',
    'settings_share_pass': 'Shared proxy password',
    'settings_about': 'About',
    'settings_version': 'Version',
    'settings_core_version': 'Xray core version',
    'settings_docs': 'Documentation',
    'settings_license': 'License (MIT)',
    'logs_title': 'Logs',
    'logs_empty': 'Logs will appear after connecting',
    'logs_clear': 'Clear',
    'logs_share': 'Share',
    'logs_follow': 'Follow log',
    'onb_skip': 'Skip',
    'onb_next': 'Next',
    'onb_start': 'Get started',
    'onb_1_title': 'Your VPN — your rules',
    'onb_1_sub':
        'VLESS (Reality), VMess, Trojan, Shadowsocks, Hysteria2, TUIC and '
            'XHTTP — import a subscription in one tap.',
    'onb_2_title': 'Wi-Fi with VPN inside',
    'onb_2_sub':
        'Share internet from your iPhone: laptop, TV and other devices get '
            'traffic through the VPN.',
    'onb_3_title': 'Fast and beautiful',
    'onb_3_sub':
        'Live stats, server latency, logs and full control over your '
            'connection.',
  },
};
