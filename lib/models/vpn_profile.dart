import 'dart:convert';

/// Поддерживаемые прокси-протоколы (все — через ядро Xray).
enum VpnProtocol {
  vless,
  vmess,
  trojan,
  shadowsocks,
  hysteria2,
  tuic,
  socks;

  String get label {
    switch (this) {
      case VpnProtocol.vless:
        return 'VLESS';
      case VpnProtocol.vmess:
        return 'VMess';
      case VpnProtocol.trojan:
        return 'Trojan';
      case VpnProtocol.shadowsocks:
        return 'Shadowsocks';
      case VpnProtocol.hysteria2:
        return 'Hysteria2';
      case VpnProtocol.tuic:
        return 'TUIC';
      case VpnProtocol.socks:
        return 'SOCKS';
    }
  }

  static VpnProtocol? tryParse(String raw) {
    final v = raw.toLowerCase().trim();
    switch (v) {
      case 'vless':
        return VpnProtocol.vless;
      case 'vmess':
        return VpnProtocol.vmess;
      case 'trojan':
        return VpnProtocol.trojan;
      case 'ss':
      case 'shadowsocks':
        return VpnProtocol.shadowsocks;
      case 'hysteria2':
      case 'hy2':
      case 'hysteria':
        return VpnProtocol.hysteria2;
      case 'tuic':
        return VpnProtocol.tuic;
      case 'socks':
      case 'socks5':
      case 'socks5h':
        return VpnProtocol.socks;
    }
    return null;
  }
}

/// Транспорт (network) соединения.
enum TransportType {
  tcp,
  ws,
  grpc,
  http,
  xhttp,
  httpupgrade,
  kcp,
  quic;

  String get label {
    switch (this) {
      case TransportType.tcp:
        return 'TCP';
      case TransportType.ws:
        return 'WebSocket';
      case TransportType.grpc:
        return 'gRPC';
      case TransportType.http:
        return 'HTTP/2';
      case TransportType.xhttp:
        return 'XHTTP';
      case TransportType.httpupgrade:
        return 'HTTPUpgrade';
      case TransportType.kcp:
        return 'mKCP';
      case TransportType.quic:
        return 'QUIC';
    }
  }

  String get xrayName {
    switch (this) {
      case TransportType.tcp:
        return 'tcp';
      case TransportType.ws:
        return 'ws';
      case TransportType.grpc:
        return 'grpc';
      case TransportType.http:
        return 'http';
      case TransportType.xhttp:
        return 'xhttp';
      case TransportType.httpupgrade:
        return 'httpupgrade';
      case TransportType.kcp:
        return 'kcp';
      case TransportType.quic:
        return 'quic';
    }
  }

  static TransportType parse(String? raw) {
    final v = (raw ?? 'tcp').toLowerCase().trim();
    switch (v) {
      case 'ws':
      case 'websocket':
        return TransportType.ws;
      case 'grpc':
      case 'gun':
        return TransportType.grpc;
      case 'h2':
      case 'http':
        return TransportType.http;
      case 'xhttp':
      case 'splithttp':
        return TransportType.xhttp;
      case 'httpupgrade':
      case 'http_upgrade':
        return TransportType.httpupgrade;
      case 'kcp':
      case 'mkcp':
        return TransportType.kcp;
      case 'quic':
        return TransportType.quic;
      case 'raw':
      case 'tcp':
      default:
        return TransportType.tcp;
    }
  }
}

/// Режим защиты канала.
enum SecurityType {
  none,
  tls,
  reality;

  String get label {
    switch (this) {
      case SecurityType.none:
        return 'None';
      case SecurityType.tls:
        return 'TLS';
      case SecurityType.reality:
        return 'REALITY';
    }
  }

  static SecurityType parse(String? raw) {
    final v = (raw ?? 'none').toLowerCase().trim();
    if (v == 'tls') return SecurityType.tls;
    if (v == 'reality' || v == 'xtls') return SecurityType.reality;
    return SecurityType.none;
  }
}

/// Полный профиль подключения.
class VpnProfile {
  VpnProfile({
    required this.id,
    required this.name,
    required this.protocol,
    required this.host,
    required this.port,
    this.userId,
    this.password,
    this.method,
    this.flow,
    this.transport = TransportType.tcp,
    this.transportPath,
    this.transportHost,
    this.serviceName,
    this.grpcMulti = false,
    this.xhttpMode,
    this.xhttpExtra,
    this.kcpHeaderType,
    this.kcpSeed,
    this.quicSecurity,
    this.quicKey,
    this.security = SecurityType.none,
    this.sni,
    this.allowInsecure = false,
    this.fingerprint,
    this.alpn,
    this.realityPublicKey,
    this.realityShortId,
    this.realitySpX,
    this.obfsPassword,
    this.hysteriaUp,
    this.hysteriaDown,
    this.hysteriaPorts,
    this.udpEnabled = true,
    this.subscriptionId,
    this.shareLink,
    this.sortIndex = 0,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  final String id;
  String name;
  VpnProtocol protocol;
  String host;
  int port;

  /// UUID (VLESS/VMess), логин (SOCKS) или пароль (Trojan/Hysteria2).
  String? userId;

  /// Пароль (Trojan/SS/Hysteria2/TUIC/SOCKS).
  String? password;

  /// Метод шифрования Shadowsocks.
  String? method;

  /// Flow (например xtls-rprx-vision).
  String? flow;

  TransportType transport;
  String? transportPath;
  String? transportHost;
  String? serviceName;
  bool grpcMulti;
  String? xhttpMode;
  String? xhttpExtra;
  String? kcpHeaderType;
  String? kcpSeed;
  String? quicSecurity;
  String? quicKey;

  SecurityType security;
  String? sni;
  bool allowInsecure;
  String? fingerprint;
  List<String>? alpn;
  String? realityPublicKey;
  String? realityShortId;
  String? realitySpX;

  /// Salamander (Hysteria2).
  String? obfsPassword;
  String? hysteriaUp;
  String? hysteriaDown;
  String? hysteriaPorts;

  bool udpEnabled;
  String? subscriptionId;
  String? shareLink;
  int sortIndex;
  DateTime updatedAt;

  String get serverLabel => '$host:$port';

  bool get isReality =>
      security == SecurityType.reality && realityPublicKey != null;

  VpnProfile copy() => VpnProfile(
        id: id,
        name: name,
        protocol: protocol,
        host: host,
        port: port,
        userId: userId,
        password: password,
        method: method,
        flow: flow,
        transport: transport,
        transportPath: transportPath,
        transportHost: transportHost,
        serviceName: serviceName,
        grpcMulti: grpcMulti,
        xhttpMode: xhttpMode,
        xhttpExtra: xhttpExtra,
        kcpHeaderType: kcpHeaderType,
        kcpSeed: kcpSeed,
        quicSecurity: quicSecurity,
        quicKey: quicKey,
        security: security,
        sni: sni,
        allowInsecure: allowInsecure,
        fingerprint: fingerprint,
        alpn: alpn == null ? null : List<String>.from(alpn!),
        realityPublicKey: realityPublicKey,
        realityShortId: realityShortId,
        realitySpX: realitySpX,
        obfsPassword: obfsPassword,
        hysteriaUp: hysteriaUp,
        hysteriaDown: hysteriaDown,
        hysteriaPorts: hysteriaPorts,
        udpEnabled: udpEnabled,
        subscriptionId: subscriptionId,
        shareLink: shareLink,
        sortIndex: sortIndex,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'protocol': protocol.name,
        'host': host,
        'port': port,
        if (userId != null) 'userId': userId,
        if (password != null) 'password': password,
        if (method != null) 'method': method,
        if (flow != null) 'flow': flow,
        'transport': transport.name,
        if (transportPath != null) 'transportPath': transportPath,
        if (transportHost != null) 'transportHost': transportHost,
        if (serviceName != null) 'serviceName': serviceName,
        'grpcMulti': grpcMulti,
        if (xhttpMode != null) 'xhttpMode': xhttpMode,
        if (xhttpExtra != null) 'xhttpExtra': xhttpExtra,
        if (kcpHeaderType != null) 'kcpHeaderType': kcpHeaderType,
        if (kcpSeed != null) 'kcpSeed': kcpSeed,
        if (quicSecurity != null) 'quicSecurity': quicSecurity,
        if (quicKey != null) 'quicKey': quicKey,
        'security': security.name,
        if (sni != null) 'sni': sni,
        'allowInsecure': allowInsecure,
        if (fingerprint != null) 'fingerprint': fingerprint,
        if (alpn != null) 'alpn': alpn,
        if (realityPublicKey != null) 'realityPublicKey': realityPublicKey,
        if (realityShortId != null) 'realityShortId': realityShortId,
        if (realitySpX != null) 'realitySpX': realitySpX,
        if (obfsPassword != null) 'obfsPassword': obfsPassword,
        if (hysteriaUp != null) 'hysteriaUp': hysteriaUp,
        if (hysteriaDown != null) 'hysteriaDown': hysteriaDown,
        if (hysteriaPorts != null) 'hysteriaPorts': hysteriaPorts,
        'udpEnabled': udpEnabled,
        if (subscriptionId != null) 'subscriptionId': subscriptionId,
        if (shareLink != null) 'shareLink': shareLink,
        'sortIndex': sortIndex,
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory VpnProfile.fromJson(Map<String, dynamic> j) {
    List<String>? alpnList;
    final alpnRaw = j['alpn'];
    if (alpnRaw is List) {
      alpnList = alpnRaw.map((e) => e.toString()).toList();
    } else if (alpnRaw is String && alpnRaw.isNotEmpty) {
      alpnList = alpnRaw.split(',').map((e) => e.trim()).toList();
    }
    return VpnProfile(
      id: j['id'] as String? ?? DateTime.now().microsecondsSinceEpoch.toString(),
      name: (j['name'] as String?)?.trim().isNotEmpty == true
          ? j['name'] as String
          : (j['host'] as String? ?? 'server'),
      protocol: VpnProtocol.tryParse(j['protocol']?.toString() ?? '') ??
          VpnProtocol.vless,
      host: j['host'] as String? ?? '',
      port: int.tryParse(j['port']?.toString() ?? '') ?? 443,
      userId: j['userId'] as String?,
      password: j['password'] as String?,
      method: j['method'] as String?,
      flow: j['flow'] as String?,
      transport: TransportType.parse(j['transport'] as String?),
      transportPath: j['transportPath'] as String?,
      transportHost: j['transportHost'] as String?,
      serviceName: j['serviceName'] as String?,
      grpcMulti: j['grpcMulti'] == true,
      xhttpMode: j['xhttpMode'] as String?,
      xhttpExtra: j['xhttpExtra'] as String?,
      kcpHeaderType: j['kcpHeaderType'] as String?,
      kcpSeed: j['kcpSeed'] as String?,
      quicSecurity: j['quicSecurity'] as String?,
      quicKey: j['quicKey'] as String?,
      security: SecurityType.parse(j['security'] as String?),
      sni: j['sni'] as String?,
      allowInsecure: j['allowInsecure'] == true,
      fingerprint: j['fingerprint'] as String?,
      alpn: alpnList,
      realityPublicKey: j['realityPublicKey'] as String?,
      realityShortId: j['realityShortId'] as String?,
      realitySpX: j['realitySpX'] as String?,
      obfsPassword: j['obfsPassword'] as String?,
      hysteriaUp: j['hysteriaUp'] as String?,
      hysteriaDown: j['hysteriaDown'] as String?,
      hysteriaPorts: j['hysteriaPorts'] as String?,
      udpEnabled: j['udpEnabled'] != false,
      subscriptionId: j['subscriptionId'] as String?,
      shareLink: j['shareLink'] as String?,
      sortIndex: int.tryParse(j['sortIndex']?.toString() ?? '') ?? 0,
      updatedAt: DateTime.tryParse(j['updatedAt'] as String? ?? '') ??
          DateTime.now(),
    );
  }

  String encode() => jsonEncode(toJson());
  static VpnProfile decode(String source) =>
      VpnProfile.fromJson(jsonDecode(source) as Map<String, dynamic>);
}
