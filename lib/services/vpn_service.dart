import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/constants.dart';
import '../models/connection_state.dart';

/// Мост к нативной части iOS (NETunnelProviderManager + Network Extension).
class VpnService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.vpnChannel);
  static const EventChannel _events =
      EventChannel(AppConstants.vpnEventsChannel);

  final StreamController<TunnelStatus> _statusController =
      StreamController<TunnelStatus>.broadcast();
  StreamSubscription<dynamic>? _eventSub;

  TunnelStatus _lastStatus = TunnelStatus.disconnected;

  /// Поток изменений статуса туннеля.
  Stream<TunnelStatus> get statusStream {
    _ensureEvents();
    return _statusController.stream;
  }

  TunnelStatus get lastStatus => _lastStatus;

  void _ensureEvents() {
    _eventSub ??= _events.receiveBroadcastStream().listen((event) {
      if (event is Map) {
        final raw = int.tryParse(event['status']?.toString() ?? '') ?? 1;
        final status = TunnelStatus.fromRaw(raw);
        _lastStatus = status;
        _statusController.add(status);
      }
    }, onError: (_) {
      // События могут быть недоступны (симулятор) — не критично.
    });
  }

  /// Проверяет, что VPN-профиль инициализирован (один раз на старте).
  Future<bool> prepare() async {
    try {
      final ok = await _channel.invokeMethod<bool>('prepare');
      return ok ?? false;
    } on PlatformException {
      return false;
    }
  }

  /// Запускает туннель. [payload] — словарь из CoreConfigBuilder.buildTunnelPayload.
  Future<bool> connect(Map<String, dynamic> payload) async {
    _ensureEvents();
    try {
      final ok = await _channel.invokeMethod<bool>('connect', payload);
      return ok ?? false;
    } on PlatformException catch (e) {
      throw VpnException(e.message ?? 'connect failed: ${e.code}');
    }
  }

  Future<void> disconnect() async {
    try {
      await _channel.invokeMethod('disconnect');
    } on PlatformException {
      // ignore
    }
  }

  Future<TunnelStatus> status() async {
    try {
      final raw = await _channel.invokeMethod<int>('status');
      final s = TunnelStatus.fromRaw(raw ?? 1);
      _lastStatus = s;
      return s;
    } on PlatformException {
      return TunnelStatus.disconnected;
    }
  }

  /// Статистика из общего контейнера (пишет расширение).
  Future<TrafficSnapshot> stats() async {
    try {
      final raw = await _channel.invokeMethod<Map>('stats');
      if (raw == null) return TrafficSnapshot.zero;
      return TrafficSnapshot.fromJson(
        raw.map((k, v) => MapEntry(k.toString(), v)),
      );
    } on PlatformException {
      return TrafficSnapshot.zero;
    }
  }

  /// Последние строки лога туннеля/ядра.
  Future<List<String>> logs({int tail = 200}) async {
    try {
      final raw = await _channel.invokeMethod<String>('logs', {'tail': tail});
      if (raw == null || raw.isEmpty) return const [];
      return raw
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
    } on PlatformException {
      return const [];
    }
  }

  Future<void> clearLogs() async {
    try {
      await _channel.invokeMethod('clearLogs');
    } on PlatformException {
      // ignore
    }
  }

  /// Версия встроенного ядра Xray.
  Future<String> coreVersion() async {
    try {
      final v = await _channel.invokeMethod<String>('coreVersion');
      return v ?? '—';
    } on PlatformException {
      return '—';
    }
  }

  /// Разбор ссылок нативным libXray (fallback/валидация для сложных подписок).
  Future<List<String>> nativeParseLinks(String text) async {
    try {
      final raw = await _channel.invokeMethod<String>('parseLinks', {
        'text': text,
      });
      if (raw == null) return const [];
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.map((e) => e.toString()).toList();
    } on PlatformException {
      return const [];
    }
  }

  Future<void> dispose() async {
    await _eventSub?.cancel();
    await _statusController.close();
  }
}

class VpnException implements Exception {
  VpnException(this.message);
  final String message;

  @override
  String toString() => message;
}
