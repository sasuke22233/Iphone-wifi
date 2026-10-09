/// Глобальные константы приложения и идентификаторы нативной части.
class AppConstants {
  AppConstants._();

  static const String appName = 'Aura VPN';
  static const String appVersion = '1.0.0';

  /// iOS bundle id основного приложения.
  static const String bundleId = 'com.auravpn.app';

  /// iOS bundle id Network Extension (Packet Tunnel).
  static const String tunnelBundleId = 'com.auravpn.app.packet-tunnel';

  /// App Group — общий контейнер приложения и расширения.
  static const String appGroup = 'group.com.auravpn.app';

  /// MethodChannel до нативного VPN-менеджера.
  static const String vpnChannel = 'com.auravpn.app/vpn';

  /// EventChannel потока событий туннеля (статус/логи).
  static const String vpnEventsChannel = 'com.auravpn.app/vpn_events';

  /// Локальный порт SOCKS5-инбаунда ядра (можно менять в настройках).
  static const int defaultSocksPort = 10808;

  /// Порт по умолчанию для раздачи прокси по Wi-Fi.
  static const int defaultSharePort = 10809;

  /// MTU по умолчанию.
  static const int defaultMtu = 1500;

  /// DNS-серверы по умолчанию для туннеля.
  static const List<String> defaultDns = ['1.1.1.1', '8.8.8.8'];

  /// Виртуальный адрес интерфейса туннеля (hev-socks5-tunnel).
  static const String tunnelIpv4 = '198.18.0.1';
  static const String tunnelIpv4Mask = '255.255.255.0';
  static const String tunnelIpv6 = 'fc00::1';

  /// Имена файлов в общем контейнере (App Group).
  static const String statsFile = 'stats.json';
  static const String accessLogFile = 'access.log';
  static const String errorLogFile = 'error.log';
  static const String tunnelLogFile = 'tunnel.log';

  /// Максимальная память для Go-рантайма Xray внутри расширения (iOS жёстко
  /// ограничивает Network Extension, поэтому ставим скромный лимит).
  static const int coreMaxMemoryBytes = 64 * 1024 * 1024;
}
