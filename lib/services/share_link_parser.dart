import 'dart:convert';

import '../models/vpn_profile.dart';

/// Парсер share-ссылок: vless://, vmess://, trojan://, ss://,
/// hysteria2://, tuic://, socks:// — плюс base64-подписки.
class ShareLinkParser {
  ShareLinkParser._();

  /// Превращает «сырой» текст (одна ссылка, много ссылок или подписку)
  /// в список профилей. Нераспознанные строки пропускаются.
  static List<VpnProfile> parseText(String raw, {String? subscriptionId}) {
    final out = <VpnProfile>[];
    var text = raw.trim();
    if (text.isEmpty) return out;

    // Подписка целиком в base64?
    final decoded = _tryDecodeBase64(text);
    if (decoded != null && decoded.contains('://')) {
      text = decoded;
    }

    for (final line in text.split(RegExp(r'[\r\n]+'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
      // Строки подписки могут быть склеены — ищем схемы.
      for (final link in _splitSchemes(trimmed)) {
        final profile = parseSingle(link, subscriptionId: subscriptionId);
        if (profile != null) out.add(profile);
      }
    }
    return out;
  }

  /// Разбирает одну ссылку. Возвращает null, если формат не поддерживается.
  static VpnProfile? parseSingle(String link, {String? subscriptionId}) {
    final trimmed = link.trim();
    try {
      final lower = trimmed.toLowerCase();
      if (lower.startsWith('vless://')) {
        return _parseVless(trimmed, subscriptionId);
      }
      if (lower.startsWith('vmess://')) {
        return _parseVmess(trimmed, subscriptionId);
      }
      if (lower.startsWith('trojan://')) {
        return _parseTrojan(trimmed, subscriptionId);
      }
      if (lower.startsWith('ss://')) {
        return _parseShadowsocks(trimmed, subscriptionId);
      }
      if (lower.startsWith('hysteria2://') || lower.startsWith('hy2://')) {
        return _parseHysteria2(trimmed, subscriptionId);
      }
      if (lower.startsWith('tuic://')) {
        return _parseTuic(trimmed, subscriptionId);
      }
      if (lower.startsWith('socks://') ||
          lower.startsWith('socks5://') ||
          lower.startsWith('socks5h://')) {
        return _parseSocks(trimmed, subscriptionId);
      }
    } catch (_) {
      // Кривая ссылка — тихо пропускаем, как это делают клиенты.
      return null;
    }
    return null;
  }

  // ---------------------------------------------------------------- vless

  static VpnProfile _parseVless(String link, String? subId) {
    final uri = _toUri(link);
    final q = uri.queryParameters;
    final name = _fragment(link);

    final transport = TransportType.parse(q['type'] ?? q['headerType']);
    final security = SecurityType.parse(q['security']);

    return VpnProfile(
      id: _newId(),
      name: name.isNotEmpty
          ? name
          : '${uri.host}:${uri.port == 0 ? 443 : uri.port}',
      protocol: VpnProtocol.vless,
      host: uri.host,
      port: uri.port == 0 ? 443 : uri.port,
      userId: uri.userInfo,
      flow: _nonEmpty(q['flow']),
      transport: transport,
      transportPath: _nonEmpty(q['path']),
      transportHost: _nonEmpty(q['host']) ?? _nonEmpty(q['authority']),
      serviceName: _nonEmpty(q['serviceName']),
      grpcMulti: (q['mode'] ?? '').toLowerCase() == 'multi',
      xhttpMode: transport == TransportType.xhttp
          ? _nonEmpty(q['mode']) ?? 'auto'
          : null,
      xhttpExtra: _nonEmpty(q['extra']),
      kcpHeaderType: _nonEmpty(q['headerType']),
      kcpSeed: _nonEmpty(q['seed']),
      quicSecurity: _nonEmpty(q['quicSecurity'] ?? q['security']),
      quicKey: _nonEmpty(q['key']),
      security: security,
      sni: _nonEmpty(q['sni']) ?? _nonEmpty(q['peer']),
      allowInsecure: _boolValue(q['allowInsecure']),
      fingerprint: _nonEmpty(q['fp']),
      alpn: _splitList(q['alpn']),
      realityPublicKey: _nonEmpty(q['pbk']),
      realityShortId: _nonEmpty(q['sid']),
      realitySpX: _nonEmpty(q['spx']),
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // ---------------------------------------------------------------- vmess

  static VpnProfile _parseVmess(String link, String? subId) {
    var payload = link.substring('vmess://'.length).trim();
    payload = _tryDecodeBase64(payload) ?? payload;
    final j = jsonDecode(payload) as Map<String, dynamic>;

    final net = (j['net'] ?? 'tcp').toString();
    final tls = (j['tls'] ?? '').toString().toLowerCase();
    final security = tls == 'reality'
        ? SecurityType.reality
        : (tls == 'tls' ? SecurityType.tls : SecurityType.none);

    final port = int.tryParse(j['port']?.toString() ?? '') ?? 443;

    return VpnProfile(
      id: _newId(),
      name: (j['ps']?.toString().isNotEmpty ?? false)
          ? j['ps'].toString()
          : '${j['add']}:$port',
      protocol: VpnProtocol.vmess,
      host: j['add']?.toString() ?? '',
      port: port,
      userId: j['id']?.toString(),
      method: _nonEmpty(j['scy']?.toString()),
      transport: TransportType.parse(net),
      transportPath: _nonEmpty(j['path']?.toString()),
      transportHost: _nonEmpty(j['host']?.toString()),
      serviceName: _nonEmpty(j['serviceName']?.toString()),
      grpcMulti: (j['mode']?.toString() ?? '').toLowerCase() == 'multi',
      xhttpMode: TransportType.parse(net) == TransportType.xhttp
          ? _nonEmpty(j['mode']?.toString()) ?? 'auto'
          : null,
      xhttpExtra: _nonEmpty(j['extra']?.toString()),
      kcpHeaderType: _nonEmpty(j['type']?.toString()) != 'none'
          ? _nonEmpty(j['type']?.toString())
          : null,
      kcpSeed: _nonEmpty(j['seed']?.toString()),
      security: security,
      sni: _nonEmpty(j['sni']?.toString()) ?? _nonEmpty(j['peer']?.toString()),
      allowInsecure: _boolValue(j['allowInsecure']),
      fingerprint: _nonEmpty(j['fp']?.toString()),
      alpn: _splitList(j['alpn']?.toString()),
      realityPublicKey: _nonEmpty(j['pbk']?.toString()),
      realityShortId: _nonEmpty(j['sid']?.toString()),
      realitySpX: _nonEmpty(j['spx']?.toString()),
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // --------------------------------------------------------------- trojan

  static VpnProfile _parseTrojan(String link, String? subId) {
    final uri = _toUri(link);
    final q = uri.queryParameters;
    final name = _fragment(link);
    final transport = TransportType.parse(q['type']);

    return VpnProfile(
      id: _newId(),
      name: name.isNotEmpty ? name : '${uri.host}:${uri.port == 0 ? 443 : uri.port}',
      protocol: VpnProtocol.trojan,
      host: uri.host,
      port: uri.port == 0 ? 443 : uri.port,
      password: _decodeComponent(uri.userInfo),
      transport: transport,
      transportPath: _nonEmpty(q['path']),
      transportHost: _nonEmpty(q['host']) ?? _nonEmpty(q['authority']),
      serviceName: _nonEmpty(q['serviceName']),
      grpcMulti: (q['mode'] ?? '').toLowerCase() == 'multi',
      kcpHeaderType: _nonEmpty(q['headerType']),
      kcpSeed: _nonEmpty(q['seed']),
      security: SecurityType.parse(
          q['security'] == 'reality' ? 'reality' : (q['security'] == 'none' ? 'none' : 'tls')),
      sni: _nonEmpty(q['sni']) ?? _nonEmpty(q['peer']),
      allowInsecure: _boolValue(q['allowInsecure']),
      fingerprint: _nonEmpty(q['fp']),
      alpn: _splitList(q['alpn']),
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // --------------------------------------------------------- shadowsocks

  static VpnProfile _parseShadowsocks(String link, String? subId) {
    var rest = link.substring('ss://'.length);
    String? name;
    final hashIdx = rest.indexOf('#');
    if (hashIdx >= 0) {
      name = _decodeComponent(rest.substring(hashIdx + 1));
      rest = rest.substring(0, hashIdx);
    }

    String? queryPart;
    final qIdx = rest.indexOf('?');
    if (qIdx >= 0) {
      queryPart = rest.substring(qIdx + 1);
      rest = rest.substring(0, qIdx);
    }

    String method;
    String password;
    String host;
    int port;

    if (rest.contains('@')) {
      // SIP002: base64(method:password)@host:port
      final at = rest.lastIndexOf('@');
      var userInfo = rest.substring(0, at);
      final hostPort = rest.substring(at + 1);
      final hp = _splitHostPort(hostPort);
      host = hp.$1;
      port = hp.$2;
      if (userInfo.contains(':')) {
        final i = userInfo.indexOf(':');
        method = _decodeComponent(userInfo.substring(0, i));
        password = _decodeComponent(userInfo.substring(i + 1));
      } else {
        final decoded =
            _tryDecodeBase64(_padBase64(userInfo)) ?? userInfo;
        final i = decoded.indexOf(':');
        method = i >= 0 ? decoded.substring(0, i) : decoded;
        password = i >= 0 ? decoded.substring(i + 1) : '';
      }
    } else {
      // Legacy: base64(method:password@host:port)
      final decoded = _tryDecodeBase64(_padBase64(rest)) ?? rest;
      final at = decoded.lastIndexOf('@');
      if (at < 0) throw const FormatException('bad ss link');
      final userInfo = decoded.substring(0, at);
      final hp = _splitHostPort(decoded.substring(at + 1));
      host = hp.$1;
      port = hp.$2;
      final i = userInfo.indexOf(':');
      method = i >= 0 ? userInfo.substring(0, i) : userInfo;
      password = i >= 0 ? userInfo.substring(i + 1) : '';
    }

    return VpnProfile(
      id: _newId(),
      name: (name != null && name.isNotEmpty) ? name : '$host:$port',
      protocol: VpnProtocol.shadowsocks,
      host: host,
      port: port,
      method: method,
      password: password,
      transport: queryPart != null && queryPart.contains('plugin=')
          ? TransportType.tcp
          : TransportType.tcp,
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // ------------------------------------------------------------ hysteria2

  static VpnProfile _parseHysteria2(String link, String? subId) {
    final normalized = link.replaceFirst(RegExp(r'^hy2://', caseSensitive: false),
        'hysteria2://');
    final uri = _toUri(normalized);
    final q = uri.queryParameters;
    final name = _fragment(normalized);
    final port = uri.port == 0 ? 443 : uri.port;

    return VpnProfile(
      id: _newId(),
      name: name.isNotEmpty ? name : '${uri.host}:$port',
      protocol: VpnProtocol.hysteria2,
      host: uri.host,
      port: port,
      password: _decodeComponent(uri.userInfo),
      security: SecurityType.tls,
      sni: _nonEmpty(q['sni']) ?? _nonEmpty(q['peer']),
      allowInsecure: _boolValue(q['insecure']) ||
          _boolValue(q['allowInsecure']),
      alpn: _splitList(q['alpn']),
      obfsPassword: _nonEmpty(q['obfs-password']) ?? _nonEmpty(q['obfsPassword']),
      hysteriaUp: _nonEmpty(q['upmbps']) ?? _nonEmpty(q['up']),
      hysteriaDown: _nonEmpty(q['downmbps']) ?? _nonEmpty(q['down']),
      hysteriaPorts: _nonEmpty(q['mport']) ?? _nonEmpty(q['ports']),
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // ----------------------------------------------------------------- tuic

  static VpnProfile _parseTuic(String link, String? subId) {
    final uri = _toUri(link);
    final q = uri.queryParameters;
    final name = _fragment(link);
    final port = uri.port == 0 ? 443 : uri.port;

    String? uuid;
    String? password;
    final userInfo = uri.userInfo;
    final i = userInfo.indexOf(':');
    if (i >= 0) {
      uuid = _decodeComponent(userInfo.substring(0, i));
      password = _decodeComponent(userInfo.substring(i + 1));
    } else {
      uuid = _decodeComponent(userInfo);
    }

    return VpnProfile(
      id: _newId(),
      name: name.isNotEmpty ? name : '${uri.host}:$port',
      protocol: VpnProtocol.tuic,
      host: uri.host,
      port: port,
      userId: uuid,
      password: password,
      security: SecurityType.tls,
      sni: _nonEmpty(q['sni']) ?? _nonEmpty(q['peer']),
      allowInsecure:
          _boolValue(q['allow_insecure']) || _boolValue(q['allowInsecure']),
      alpn: _splitList(q['alpn']),
      fingerprint: _nonEmpty(q['congestion_control']),
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // ---------------------------------------------------------------- socks

  static VpnProfile _parseSocks(String link, String? subId) {
    final uri = _toUri(link.replaceFirst(RegExp(r'^socks5h://', caseSensitive: false),
        'socks://').replaceFirst(RegExp(r'^socks5://', caseSensitive: false),
        'socks://'));
    final name = _fragment(link);
    final port = uri.port == 0 ? 1080 : uri.port;
    String? user;
    String? pass;
    if (uri.userInfo.isNotEmpty) {
      final i = uri.userInfo.indexOf(':');
      if (i >= 0) {
        user = _decodeComponent(uri.userInfo.substring(0, i));
        pass = _decodeComponent(uri.userInfo.substring(i + 1));
      } else {
        user = _decodeComponent(uri.userInfo);
      }
    }
    return VpnProfile(
      id: _newId(),
      name: name.isNotEmpty ? name : '${uri.host}:$port',
      protocol: VpnProtocol.socks,
      host: uri.host,
      port: port,
      userId: user,
      password: pass,
      subscriptionId: subId,
      shareLink: link,
    );
  }

  // ------------------------------------------------------------- helpers

  static int _idCounter = 0;

  static String _newId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    _idCounter = (_idCounter + 1) % 100000;
    return '${now}_$_idCounter';
  }

  static Uri _toUri(String link) {
    // Uri.parse плохо переносит некоторые символы в userInfo — чиним.
    var fixed = link.replaceAll(' ', '%20');
    final uri = Uri.parse(fixed);
    return uri;
  }

  static String _fragment(String link) {
    final i = link.indexOf('#');
    if (i < 0) return '';
    return _decodeComponent(link.substring(i + 1));
  }

  static String _decodeComponent(String raw) {
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  static String? _nonEmpty(String? v) {
    if (v == null) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  static bool _boolValue(dynamic v) {
    if (v == null) return false;
    if (v is bool) return v;
    final s = v.toString().toLowerCase();
    return s == '1' || s == 'true' || s == 'yes';
  }

  static List<String>? _splitList(String? raw) {
    final v = _nonEmpty(raw);
    if (v == null) return null;
    return v
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static (String, int) _splitHostPort(String input) {
    var s = input.trim();
    if (s.startsWith('[')) {
      final end = s.indexOf(']');
      final host = s.substring(1, end);
      final rest = s.substring(end + 1);
      final port = rest.startsWith(':') ? int.tryParse(rest.substring(1)) ?? 443 : 443;
      return (host, port);
    }
    final i = s.lastIndexOf(':');
    if (i < 0) return (s, 443);
    final host = s.substring(0, i);
    final port = int.tryParse(s.substring(i + 1)) ?? 443;
    return (host, port);
  }

  static String _padBase64(String input) {
    var s = input.replaceAll('-', '+').replaceAll('_', '/');
    final mod = s.length % 4;
    if (mod == 2) s = '$s==';
    if (mod == 3) s = '$s=';
    return s;
  }

  static String? _tryDecodeBase64(String input) {
    try {
      final compact = input.replaceAll(RegExp(r'\s'), '');
      if (compact.isEmpty) return null;
      final normalized = _padBase64(compact);
      final bytes = base64.decode(normalized);
      final text = utf8.decode(bytes, allowMalformed: true).trim();
      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }

  /// Разбивает склеенные ссылки в одну строку.
  static Iterable<String> _splitSchemes(String line) sync* {
    final pattern = RegExp(
        r'(vless|vmess|trojan|ss|hysteria2|hy2|tuic|socks5h|socks5|socks)://',
        caseSensitive: false);
    final matches = pattern.allMatches(line).toList();
    if (matches.isEmpty) {
      yield line;
      return;
    }
    for (var i = 0; i < matches.length; i++) {
      final start = matches[i].start;
      final end = i + 1 < matches.length ? matches[i + 1].start : line.length;
      yield line.substring(start, end);
    }
  }
}
