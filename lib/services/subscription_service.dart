import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/subscription.dart';
import '../models/vpn_profile.dart';
import 'share_link_parser.dart';

/// Загрузка и обновление подписок.
class SubscriptionService {
  SubscriptionService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Тело подписки + распарсенные профили + мета из заголовков.
  Future<SubscriptionFetchResult> fetch(Subscription sub,
      {Duration timeout = const Duration(seconds: 25)}) async {
    final uri = Uri.tryParse(sub.url.trim());
    if (uri == null) {
      throw SubscriptionException('Invalid subscription URL');
    }

    final request = http.Request('GET', uri);
    request.headers['User-Agent'] =
        'aura-vpn/1.0 (CFNetwork; iOS) clash/2.0 v2ray/1.8';
    request.headers['Accept'] = '*/*';

    final streamed = await _client.send(request).timeout(timeout);
    final body = await streamed.stream.bytesToString().timeout(timeout);

    if (streamed.statusCode >= 400) {
      throw SubscriptionException(
          'HTTP ${streamed.statusCode} for ${sub.name}');
    }

    final profiles = ShareLinkParser.parseText(body, subscriptionId: sub.id);

    final meta = _parseUserinfo(streamed.headers);

    return SubscriptionFetchResult(
      profiles: profiles,
      upload: meta.upload ?? sub.upload,
      download: meta.download ?? sub.download,
      total: meta.total ?? sub.total,
      expireAt: meta.expireAt ?? sub.expireAt,
    );
  }

  /// Обновляет подписку на месте (мета-данные), профили возвращает отдельно.
  Future<List<VpnProfile>> update(Subscription sub) async {
    final result = await fetch(sub);
    sub
      ..upload = result.upload
      ..download = result.download
      ..total = result.total
      ..expireAt = result.expireAt
      ..lastUpdated = DateTime.now();
    return result.profiles;
  }

  _UserinfoMeta _parseUserinfo(Map<String, String> headers) {
    final raw = headers['subscription-userinfo'] ??
        headers['subscription-userinfo'.toLowerCase()];
    if (raw == null || raw.isEmpty) return const _UserinfoMeta();
    int? upload, download, total;
    DateTime? expire;
    for (final part in raw.split(';')) {
      final kv = part.trim().split('=');
      if (kv.length != 2) continue;
      final key = kv[0].trim().toLowerCase();
      final value = int.tryParse(kv[1].trim());
      if (value == null) continue;
      if (key == 'upload') {
        upload = value;
      } else if (key == 'download') {
        download = value;
      } else if (key == 'total') {
        total = value;
      } else if (key == 'expire') {
        expire = DateTime.fromMillisecondsSinceEpoch(value * 1000);
      }
    }
    return _UserinfoMeta(
      upload: upload,
      download: download,
      total: total,
      expireAt: expire,
    );
  }

  /// Попытка распознать формат Clash/Mihomo YAML — сообщаем, что не поддерживается.
  static bool looksLikeClash(String body) {
    final head = body.substring(0, body.length.clamp(0, 400));
    return head.contains('proxies:') &&
        head.contains('- name:') &&
        !body.contains('://');
  }

  /// Проверка, что текст вообще похож на подписку/ссылки.
  static bool looksLikeShareLinks(String body) {
    return RegExp(r'(vless|vmess|trojan|ss|hysteria2|hy2|tuic|socks)://',
            caseSensitive: false)
        .hasMatch(body) ||
        RegExp(r'(vless|vmess|trojan|ss|hysteria2|hy2|tuic|socks)://',
                caseSensitive: false)
            .hasMatch(_tryB64(body) ?? '');
  }

  static String? _tryB64(String input) {
    try {
      final compact = input.replaceAll(RegExp(r'\s'), '');
      var s = compact.replaceAll('-', '+').replaceAll('_', '/');
      final mod = s.length % 4;
      if (mod == 2) s = '$s==';
      if (mod == 3) s = '$s=';
      return utf8.decode(base64.decode(s), allowMalformed: true);
    } catch (_) {
      return null;
    }
  }

  void dispose() => _client.close();
}

class SubscriptionFetchResult {
  const SubscriptionFetchResult({
    required this.profiles,
    required this.upload,
    required this.download,
    required this.total,
    required this.expireAt,
  });

  final List<VpnProfile> profiles;
  final int upload;
  final int download;
  final int total;
  final DateTime? expireAt;
}

class _UserinfoMeta {
  const _UserinfoMeta({this.upload, this.download, this.total, this.expireAt});

  final int? upload;
  final int? download;
  final int? total;
  final DateTime? expireAt;
}

class SubscriptionException implements Exception {
  SubscriptionException(this.message);
  final String message;

  @override
  String toString() => message;
}
