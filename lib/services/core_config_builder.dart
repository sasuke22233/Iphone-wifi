import 'dart:convert';

import '../core/constants.dart';
import '../models/vpn_profile.dart';

/// Собирает JSON-конфигурацию Xray-core и YAML для hev-socks5-tunnel
/// из пользовательского профиля.
class CoreConfigBuilder {
  CoreConfigBuilder._();

  /// Полная конфигурация Xray.
  ///
  /// [listenAll] — слушать 0.0.0.0 (нужно для раздачи прокси по Wi-Fi),
  /// иначе только 127.0.0.1.
  static Map<String, dynamic> buildXrayConfig({
    required VpnProfile profile,
    required int socksPort,
    bool listenAll = false,
    int? sharePort,
    String? shareUser,
    String? sharePass,
    List<String> dnsServers = AppConstants.defaultDns,
    bool mux = false,
    String logLevel = 'warning',
    String? accessLogPath,
    String? errorLogPath,
  }) {
    final listen = listenAll ? '0.0.0.0' : '127.0.0.1';

    final inbounds = <Map<String, dynamic>>[
      {
        'tag': 'socks-in',
        'listen': listen,
        'port': socksPort,
        'protocol': 'socks',
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
          'routeOnly': true,
        },
        'settings': {
          'udp': profile.udpEnabled,
          if (shareUser != null && shareUser.isNotEmpty)
            'auth': 'password',
          if (shareUser != null && shareUser.isNotEmpty)
            'accounts': [
              {'user': shareUser, 'pass': sharePass ?? ''},
            ],
        },
      },
      // HTTP-инбаунд на тот же адрес — удобно для браузеров и ТВ.
      {
        'tag': 'http-in',
        'listen': listen,
        'port': socksPort + 1,
        'protocol': 'http',
        'sniffing': {
          'enabled': true,
          'destOverride': ['http', 'tls', 'quic'],
          'routeOnly': true,
        },
        'settings': {
          if (shareUser != null && shareUser.isNotEmpty)
            'accounts': [
              {'user': shareUser, 'pass': sharePass ?? ''},
            ],
        },
      },
      if (sharePort != null && sharePort > 0 && listenAll)
        {
          'tag': 'share-in',
          'listen': '0.0.0.0',
          'port': sharePort,
          'protocol': 'socks',
          'sniffing': {
            'enabled': true,
            'destOverride': ['http', 'tls', 'quic'],
            'routeOnly': true,
          },
          'settings': {
            'udp': true,
            if (shareUser != null && shareUser.isNotEmpty)
              'auth': 'password',
            if (shareUser != null && shareUser.isNotEmpty)
              'accounts': [
                {'user': shareUser, 'pass': sharePass ?? ''},
              ],
          },
        },
    ];

    final outbounds = <Map<String, dynamic>>[
      buildOutbound(profile, mux: mux),
      {'tag': 'direct', 'protocol': 'freedom', 'settings': {}},
      {'tag': 'block', 'protocol': 'blackhole', 'settings': {}},
    ];

    // Правила маршрутизации: адрес сервера — напрямую (иначе петля),
    // приватные сети — напрямую, всё остальное через прокси.
    final rules = <Map<String, dynamic>>[
      {
        'type': 'field',
        'ip': ['geoip:private'],
        'outboundTag': 'direct',
      },
      {
        'type': 'field',
        'domain': ['geosite:private'],
        'outboundTag': 'direct',
      },
    ];

    final serverIpRule = _serverDirectRule(profile);
    rules.insert(0, serverIpRule);

    return {
      'log': {
        'loglevel': logLevel,
        if (accessLogPath != null) 'access': accessLogPath,
        if (errorLogPath != null) 'error': errorLogPath,
      },
      'dns': {
        'servers': [
          ...dnsServers.map((d) => d.startsWith('http') ? d : d),
          'localhost',
        ],
        'queryStrategy': 'UseIP',
      },
      'inbounds': inbounds,
      'outbounds': outbounds,
      'routing': {
        'domainStrategy': 'IPIfNonMatch',
        'rules': rules,
      },
      'policy': {
        'levels': {
          '0': {
            'handshake': 8,
            'connIdle': 300,
            'uplinkOnly': 2,
            'downlinkOnly': 5,
            'statsUserUplink': false,
            'statsUserDownlink': false,
            'bufferSize': 512,
          },
        },
        'system': {
          'statsInboundUplink': true,
          'statsInboundDownlink': true,
        },
      },
    };
  }

  /// Стабильный outbound для профиля.
  static Map<String, dynamic> buildOutbound(VpnProfile p, {bool mux = false}) {
    final stream = _streamSettings(p);
    final outbound = <String, dynamic>{
      'tag': 'proxy',
      'protocol': _protocolName(p),
      'settings': _protocolSettings(p),
      'streamSettings': stream,
      if (mux)
        'mux': {
          'enabled': true,
          'concurrency': 8,
          'xudpProxyUDP443': 'reject',
        },
    };
    return outbound;
  }

  static String _protocolName(VpnProfile p) {
    switch (p.protocol) {
      case VpnProtocol.vless:
        return 'vless';
      case VpnProtocol.vmess:
        return 'vmess';
      case VpnProtocol.trojan:
        return 'trojan';
      case VpnProtocol.shadowsocks:
        return 'shadowsocks';
      case VpnProtocol.hysteria2:
        return 'hysteria2';
      case VpnProtocol.tuic:
        return 'tuic';
      case VpnProtocol.socks:
        return 'socks';
    }
  }

  static Map<String, dynamic> _protocolSettings(VpnProfile p) {
    switch (p.protocol) {
      case VpnProtocol.vless:
        return {
          'vnext': [
            {
              'address': p.host,
              'port': p.port,
              'users': [
                {
                  'id': p.userId ?? '',
                  'encryption': 'none',
                  if (p.flow != null && p.flow!.isNotEmpty) 'flow': p.flow,
                },
              ],
            },
          ],
        };
      case VpnProtocol.vmess:
        return {
          'vnext': [
            {
              'address': p.host,
              'port': p.port,
              'users': [
                {
                  'id': p.userId ?? '',
                  'alterId': 0,
                  'security': (p.method == null || p.method!.isEmpty)
                      ? 'auto'
                      : p.method,
                },
              ],
            },
          ],
        };
      case VpnProtocol.trojan:
        return {
          'servers': [
            {
              'address': p.host,
              'port': p.port,
              'password': p.password ?? '',
            },
          ],
        };
      case VpnProtocol.shadowsocks:
        return {
          'servers': [
            {
              'address': p.host,
              'port': p.port,
              'method': p.method ?? 'aes-256-gcm',
              'password': p.password ?? '',
            },
          ],
        };
      case VpnProtocol.hysteria2:
        return {
          'servers': [
            {
              'address': p.host,
              'port': p.port,
              'password': p.password ?? '',
              if (p.hysteriaPorts != null && p.hysteriaPorts!.isNotEmpty)
                'ports': p.hysteriaPorts,
              if (p.hysteriaUp != null ||
                  p.hysteriaDown != null)
                'up': p.hysteriaUp ?? '100 Mbps',
              if (p.hysteriaDown != null)
                'down': p.hysteriaDown ?? '100 Mbps',
              if (p.obfsPassword != null && p.obfsPassword!.isNotEmpty)
                'obfs': {
                  'type': 'salamander',
                  'password': p.obfsPassword,
                },
            },
          ],
        };
      case VpnProtocol.tuic:
        return {
          'servers': [
            {
              'address': p.host,
              'port': p.port,
              'uuid': p.userId ?? '',
              'password': p.password ?? '',
              if (p.fingerprint != null && p.fingerprint!.isNotEmpty)
                'congestion_control': p.fingerprint,
              if (p.alpn != null) 'alpn': p.alpn,
              'udp_relay_mode': 'native',
            },
          ],
        };
      case VpnProtocol.socks:
        return {
          'servers': [
            {
              'address': p.host,
              'port': p.port,
              if (p.userId != null && p.userId!.isNotEmpty)
                'users': [
                  {'user': p.userId, 'pass': p.password ?? ''},
                ],
            },
          ],
          'version': '5',
        };
    }
  }

  static Map<String, dynamic> _streamSettings(VpnProfile p) {
    // Некоторые протоколы (hysteria2/tuic) не используют streamSettings.
    if (p.protocol == VpnProtocol.hysteria2 || p.protocol == VpnProtocol.tuic) {
      return {
        'network': 'tcp',
        'security': 'none',
      };
    }

    final network = p.transport.xrayName;
    final ss = <String, dynamic>{
      'network': network,
    };

    // ---- transport settings ----
    switch (p.transport) {
      case TransportType.tcp:
        ss['tcpSettings'] = {
          'header': {
            'type': p.kcpHeaderType ?? 'none',
          },
        };
      case TransportType.ws:
        ss['wsSettings'] = {
          'path': p.transportPath ?? '/',
          if (p.transportHost != null && p.transportHost!.isNotEmpty)
            'headers': {'Host': p.transportHost},
        };
      case TransportType.grpc:
        ss['grpcSettings'] = {
          'serviceName': p.serviceName ?? p.transportPath ?? '',
          'multiMode': p.grpcMulti,
        };
      case TransportType.http:
        ss['httpSettings'] = {
          'path': p.transportPath ?? '/',
          if (p.transportHost != null && p.transportHost!.isNotEmpty)
            'host': [p.transportHost],
        };
      case TransportType.xhttp:
        ss['xhttpSettings'] = {
          'mode': p.xhttpMode ?? 'auto',
          'path': p.transportPath ?? '/',
          if (p.transportHost != null && p.transportHost!.isNotEmpty)
            'host': p.transportHost,
          if (p.xhttpExtra != null && p.xhttpExtra!.trim().isNotEmpty)
            'extra': _tryJson(p.xhttpExtra!),
        };
      case TransportType.httpupgrade:
        ss['httpupgradeSettings'] = {
          'path': p.transportPath ?? '/',
          if (p.transportHost != null && p.transportHost!.isNotEmpty)
            'host': p.transportHost,
        };
      case TransportType.kcp:
        ss['kcpSettings'] = {
          'mtu': 1350,
          'tti': 50,
          'uplinkCapacity': 12,
          'downlinkCapacity': 100,
          'congestion': false,
          'header': {'type': p.kcpHeaderType ?? 'none'},
          if (p.kcpSeed != null && p.kcpSeed!.isNotEmpty) 'seed': p.kcpSeed,
        };
      case TransportType.quic:
        ss['quicSettings'] = {
          'security': p.quicSecurity ?? 'none',
          'key': p.quicKey ?? '',
          'header': {'type': p.kcpHeaderType ?? 'none'},
        };
    }

    // ---- security ----
    switch (p.security) {
      case SecurityType.none:
        ss['security'] = 'none';
      case SecurityType.tls:
        ss['security'] = 'tls';
        ss['tlsSettings'] = {
          'serverName': _sniOrHost(p),
          'allowInsecure': p.allowInsecure,
          if (p.fingerprint != null && p.fingerprint!.isNotEmpty)
            'fingerprint': p.fingerprint,
          if (p.alpn != null && p.alpn!.isNotEmpty) 'alpn': p.alpn,
        };
      case SecurityType.reality:
        ss['security'] = 'reality';
        ss['realitySettings'] = {
          'serverName': _sniOrHost(p),
          'fingerprint': (p.fingerprint == null || p.fingerprint!.isEmpty)
              ? 'chrome'
              : p.fingerprint,
          'publicKey': p.realityPublicKey ?? '',
          if (p.realityShortId != null && p.realityShortId!.isNotEmpty)
            'shortId': p.realityShortId,
          'spiderX': (p.realitySpX == null || p.realitySpX!.isEmpty)
              ? '/'
              : p.realitySpX,
        };
    }

    return ss;
  }

  static String _sniOrHost(VpnProfile p) {
    final sni = p.sni;
    if (sni != null && sni.isNotEmpty) return sni;
    return p.host;
  }

  static Map<String, dynamic> _serverDirectRule(VpnProfile p) {
    final host = p.host.trim();
    if (host.isEmpty) return {'type': 'field', 'ip': ['127.0.0.1'], 'outboundTag': 'direct'};
    final isIp = RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(host) ||
        host.contains(':');
    if (isIp) {
      return {
        'type': 'field',
        'ip': [host],
        'outboundTag': 'direct',
      };
    }
    return {
      'type': 'field',
      'domain': [host],
      'outboundTag': 'direct',
    };
  }

  static dynamic _tryJson(String raw) {
    try {
      return jsonDecode(raw);
    } catch (_) {
      return {'raw': raw};
    }
  }

  // ------------------------------------------------- hev-socks5-tunnel

  /// Конфиг tun2socks (hev-socks5-tunnel) в YAML.
  static String buildHevConfig({
    required int socksPort,
    int mtu = AppConstants.defaultMtu,
    String? socksUser,
    String? socksPass,
    bool udp = true,
  }) {
    return '''
tunnel:
  name: aura
  mtu: $mtu
  ipv4: ${AppConstants.tunnelIpv4}
  ipv6: '${AppConstants.tunnelIpv6}'
  icmp: 'off'

socks5:
  port: $socksPort
  address: 127.0.0.1
  udp: '${udp ? 'udp' : 'tcp'}'
${socksUser != null && socksUser.isNotEmpty ? "  username: '$socksUser'\n  password: '${socksPass ?? ''}'\n" : ''}misc:
  task-stack-size: 24576
  tcp-buffer-size: 4096
  max-session-count: 1200
  log-level: error
''';
  }

  /// Полезная нагрузка для запуска ядра внутри Network Extension.
  ///
  /// Логи пишутся в App Group контейнер: маркер `__APP_GROUP__` заменяется
  /// на реальный путь внутри PacketTunnelProvider.
  static Map<String, dynamic> buildTunnelPayload({
    required VpnProfile profile,
    required int socksPort,
    bool shareProxy = false,
    int sharePort = AppConstants.defaultSharePort,
    String? shareUser,
    String? sharePass,
    List<String> dnsServers = AppConstants.defaultDns,
    int mtu = AppConstants.defaultMtu,
    bool mux = false,
    String logLevel = 'warning',
    String? accessLogPath = '__APP_GROUP__/access.log',
    String? errorLogPath = '__APP_GROUP__/error.log',
    String? logDir,
  }) {
    final xray = buildXrayConfig(
      profile: profile,
      socksPort: socksPort,
      listenAll: shareProxy,
      sharePort: shareProxy ? sharePort : null,
      shareUser: shareProxy ? shareUser : null,
      sharePass: shareProxy ? sharePass : null,
      dnsServers: dnsServers,
      mux: mux,
      logLevel: logLevel,
      accessLogPath: accessLogPath,
      errorLogPath: errorLogPath,
    );
    final hev = buildHevConfig(
      socksPort: socksPort,
      mtu: mtu,
      udp: profile.udpEnabled,
    );
    return {
      'profileName': profile.name,
      'serverAddress': profile.host,
      'serverPort': profile.port,
      'socksPort': socksPort,
      'httpPort': socksPort + 1,
      'shareProxy': shareProxy,
      'sharePort': sharePort,
      'shareUser': shareUser ?? '',
      'sharePass': sharePass ?? '',
      'mtu': mtu,
      'dnsServers': dnsServers,
      'logDir': logDir ?? '',
      'xrayJson': jsonEncode(xray),
      'hevYaml': hev,
    };
  }
}
