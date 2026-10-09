import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../core/constants.dart';
import '../models/connection_state.dart';
import '../models/log_entry.dart';
import '../models/subscription.dart';
import '../models/vpn_profile.dart';
import '../services/app_logger.dart';
import '../services/core_config_builder.dart';
import '../services/hotspot_service.dart';
import '../services/share_link_parser.dart';
import '../services/store_service.dart';
import '../services/subscription_service.dart';
import '../services/vpn_service.dart';

/// Пользовательские настройки.
class AppSettings {
  AppSettings({
    this.language = 'ru',
    this.dnsServers = AppConstants.defaultDns,
    this.mtu = AppConstants.defaultMtu,
    this.socksPort = AppConstants.defaultSocksPort,
    this.sharePort = AppConstants.defaultSharePort,
    this.shareUser,
    this.sharePass,
    this.includeAllNetworks = true,
    this.excludeLocalNetworks = true,
    this.autoConnect = false,
    this.autoUpdateSubs = true,
    this.mux = false,
    this.logLevel = 'warning',
  });

  String language;
  List<String> dnsServers;
  int mtu;
  int socksPort;
  int sharePort;
  String? shareUser;
  String? sharePass;
  bool includeAllNetworks;
  bool excludeLocalNetworks;
  bool autoConnect;
  bool autoUpdateSubs;
  bool mux;
  String logLevel;

  Map<String, dynamic> toJson() => {
        'language': language,
        'dnsServers': dnsServers,
        'mtu': mtu,
        'socksPort': socksPort,
        'sharePort': sharePort,
        'shareUser': shareUser,
        'sharePass': sharePass,
        'includeAllNetworks': includeAllNetworks,
        'excludeLocalNetworks': excludeLocalNetworks,
        'autoConnect': autoConnect,
        'autoUpdateSubs': autoUpdateSubs,
        'mux': mux,
        'logLevel': logLevel,
      };

  static AppSettings fromJson(Map<String, dynamic> j) => AppSettings(
        language: j['language'] as String? ?? 'ru',
        dnsServers: (j['dnsServers'] as List?)?.map((e) => e.toString()).toList() ??
            AppConstants.defaultDns,
        mtu: int.tryParse(j['mtu']?.toString() ?? '') ?? AppConstants.defaultMtu,
        socksPort: int.tryParse(j['socksPort']?.toString() ?? '') ??
            AppConstants.defaultSocksPort,
        sharePort: int.tryParse(j['sharePort']?.toString() ?? '') ??
            AppConstants.defaultSharePort,
        shareUser: j['shareUser'] as String?,
        sharePass: j['sharePass'] as String?,
        includeAllNetworks: j['includeAllNetworks'] != false,
        excludeLocalNetworks: j['excludeLocalNetworks'] != false,
        autoConnect: j['autoConnect'] == true,
        autoUpdateSubs: j['autoUpdateSubs'] != false,
        mux: j['mux'] == true,
        logLevel: j['logLevel'] as String? ?? 'warning',
      );
}

/// Главный ChangeNotifier: связывает UI, сервисы и нативную часть.
class AppState extends ChangeNotifier {
  AppState({
    required StoreService store,
    required VpnService vpn,
    required SubscriptionService subscriptions,
    required HotspotService hotspot,
    required AppLogger logger,
  })  : _store = store,
        _vpn = vpn,
        _subs = subscriptions,
        _hotspot = hotspot,
        _log = logger {
    _bootstrap();
  }

  final StoreService _store;
  final VpnService _vpn;
  final SubscriptionService _subs;
  final HotspotService _hotspot;
  final AppLogger _log;

  // ------------------------------------------------------------ состояние
  List<VpnProfile> profiles = [];
  List<Subscription> subscriptionList = [];
  VpnProfile? selected;
  AppSettings settings = AppSettings();
  TunnelStatus status = TunnelStatus.disconnected;
  TrafficSnapshot traffic = TrafficSnapshot.zero;
  final List<SpeedPoint> speedHistory = [];
  DateTime? connectedAt;
  String? lastError;
  bool busy = false;
  Locale locale = const Locale('ru');
  String coreVersion = '—';
  Map<String, int> pingCache = {};
  List<String> recentLogs = [];
  bool onboardingDone = false;

  Timer? _statsTimer;
  StreamSubscription<TunnelStatus>? _statusSub;

  AppLogger get logger => _log;
  HotspotService get hotspotService => _hotspot;

  bool get isConnected => status == TunnelStatus.connected;
  bool get isBusy =>
      status == TunnelStatus.connecting ||
      status == TunnelStatus.disconnecting;

  Duration get sessionDuration =>
      connectedAt == null ? Duration.zero : DateTime.now().difference(connectedAt!);

  Future<void> _bootstrap() async {
    profiles = _store.loadProfiles();
    subscriptionList = _store.loadSubscriptions();
    settings = AppSettings.fromJson(_store.loadSettings());
    locale = Locale(settings.language);
    onboardingDone = _store.onboardingDone;
    final selectedId = _store.selectedProfileId;
    if (selectedId != null) {
      try {
        selected = profiles.firstWhere((p) => p.id == selectedId);
      } catch (_) {
        selected = profiles.isNotEmpty ? profiles.first : null;
      }
    } else if (profiles.isNotEmpty) {
      selected = profiles.first;
    }

    _statusSub = _vpn.statusStream.listen((s) {
      _applyStatus(s);
    });

    await _vpn.prepare();
    final s = await _vpn.status();
    _applyStatus(s, silent: true);
    coreVersion = await _vpn.coreVersion();

    if (settings.autoUpdateSubs && subscriptionList.isNotEmpty) {
      unawaited(updateAllSubscriptions(silent: true));
    }
    if (settings.autoConnect && selected != null && !isConnected) {
      unawaited(connect());
    }
    notifyListeners();
  }

  void _applyStatus(TunnelStatus s, {bool silent = false}) {
    final previous = status;
    status = s;
    if (s == TunnelStatus.connected && previous != TunnelStatus.connected) {
      connectedAt = DateTime.now();
      _startStatsTimer();
      lastError = null;
      _log.info('VPN подключён', source: 'tunnel');
    }
    if (s == TunnelStatus.disconnected) {
      connectedAt = null;
      _stopStatsTimer();
      traffic = TrafficSnapshot.zero;
      speedHistory.clear();
    }
    if (s == TunnelStatus.connecting) {
      lastError = null;
    }
    if (!silent) notifyListeners();
  }

  void _startStatsTimer() {
    _stopStatsTimer();
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _pollStats();
      _pollLogs();
    });
    _pollStats();
  }

  void _stopStatsTimer() {
    _statsTimer?.cancel();
    _statsTimer = null;
  }

  Future<void> _pollStats() async {
    final snap = await _vpn.stats();
    if (snap.rxBytes == 0 && snap.txBytes == 0) {
      notifyListeners();
      return;
    }
    // Считаем мгновенную скорость относительно предыдущего снимка.
    final prev = traffic;
    final dt = snap.timestamp == null || prev.timestamp == null
        ? 1.0
        : (snap.timestamp!.difference(prev.timestamp!).inMilliseconds / 1000.0)
            .clamp(0.2, 5.0);
    final down = ((snap.rxBytes - prev.rxBytes).clamp(0, 1 << 40)) / dt;
    final up = ((snap.txBytes - prev.txBytes).clamp(0, 1 << 40)) / dt;
    traffic = snap;
    speedHistory.add(SpeedPoint(
      downBps: down,
      upBps: up,
      at: DateTime.now(),
    ));
    if (speedHistory.length > 60) {
      speedHistory.removeRange(0, speedHistory.length - 60);
    }
    notifyListeners();
  }

  Future<void> _pollLogs() async {
    final lines = await _vpn.logs(tail: 120);
    if (lines.isNotEmpty && lines.length != recentLogs.length) {
      recentLogs = lines;
      _log.addCoreLines(lines);
      notifyListeners();
    }
  }

  // ------------------------------------------------------------- выбор

  void selectProfile(VpnProfile profile) {
    selected = profile;
    _store.setSelectedProfile(profile.id);
    notifyListeners();
  }

  // ------------------------------------------------------------ connect

  Future<void> connect({VpnProfile? profile}) async {
    final target = profile ?? selected;
    if (target == null) {
      lastError = 'Нет выбранного сервера';
      notifyListeners();
      return;
    }
    if (profile != null) selectProfile(profile);
    if (isBusy) return;

    busy = true;
    lastError = null;
    _applyStatus(TunnelStatus.connecting);
    notifyListeners();

    try {
      final payload = CoreConfigBuilder.buildTunnelPayload(
        profile: target,
        socksPort: settings.socksPort,
        shareProxy: _shareEnabled,
        sharePort: settings.sharePort,
        shareUser: settings.shareUser,
        sharePass: settings.sharePass,
        dnsServers: settings.dnsServers,
        mtu: settings.mtu,
        mux: settings.mux,
        logLevel: settings.logLevel,
      );
      // Опции захвата трафика (Personal Hotspot) и раздачи.
      payload['includeAllNetworks'] = settings.includeAllNetworks;
      payload['excludeLocalNetworks'] = settings.excludeLocalNetworks;
      payload['shareProxy'] = _shareEnabled;
      payload['sharePort'] = settings.sharePort;
      payload['shareUser'] = settings.shareUser ?? '';
      payload['sharePass'] = settings.sharePass ?? '';

      _log.info('Подключение: ${target.name} (${target.protocol.label})');
      final ok = await _vpn.connect(payload);
      if (!ok) {
        lastError = 'Не удалось запустить туннель';
        _applyStatus(TunnelStatus.disconnected);
      }
    } on VpnException catch (e) {
      lastError = e.message;
      _log.error('Ошибка подключения: ${e.message}');
      _applyStatus(TunnelStatus.disconnected);
    } catch (e) {
      lastError = e.toString();
      _log.error('Ошибка подключения: $e');
      _applyStatus(TunnelStatus.disconnected);
    } finally {
      busy = false;
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _log.info('Отключение…');
    await _vpn.disconnect();
    _applyStatus(TunnelStatus.disconnected);
    notifyListeners();
  }

  Future<void> toggleConnection() async {
    if (isConnected || status == TunnelStatus.connecting) {
      await disconnect();
    } else {
      await connect();
    }
  }

  // -------------------------------------------------------- раздача Wi-Fi

  bool _shareEnabled = false;
  bool get shareEnabled => _shareEnabled;

  set shareEnabled(bool value) {
    _shareEnabled = value;
    notifyListeners();
    if (isConnected) {
      // Для применения настроек раздачи нужно переподключение.
      reconnect();
    }
  }

  Future<void> reconnect() async {
    if (!isConnected && status != TunnelStatus.connecting) return;
    await disconnect();
    await Future<void>.delayed(const Duration(milliseconds: 600));
    await connect();
  }

  // ----------------------------------------------------- импорт профилей

  /// Импорт из текста (ссылки) — возвращает количество добавленных.
  int importLinks(String text, {String? subscriptionId}) {
    final parsed = ShareLinkParser.parseText(text, subscriptionId: subscriptionId);
    if (parsed.isEmpty) return 0;
    profiles.addAll(parsed);
    _persistProfiles();
    if (selected == null && profiles.isNotEmpty) {
      selectProfile(profiles.first);
    }
    notifyListeners();
    return parsed.length;
  }

  void addProfile(VpnProfile profile) {
    profiles.add(profile);
    _persistProfiles();
    if (selected == null) selectProfile(profile);
    notifyListeners();
  }

  void updateProfile(VpnProfile profile) {
    final i = profiles.indexWhere((p) => p.id == profile.id);
    if (i >= 0) {
      profiles[i] = profile;
      if (selected?.id == profile.id) selected = profile;
      _persistProfiles();
      notifyListeners();
    }
  }

  void deleteProfile(VpnProfile profile) {
    profiles.removeWhere((p) => p.id == profile.id);
    if (selected?.id == profile.id) {
      selected = profiles.isNotEmpty ? profiles.first : null;
      _store.setSelectedProfile(selected?.id);
    }
    _persistProfiles();
    notifyListeners();
  }

  void _persistProfiles() => _store.saveProfiles(profiles);

  // -------------------------------------------------------- подписки

  Future<Subscription> addSubscription(String name, String url,
      {int intervalHours = 24}) async {
    final sub = Subscription(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      name: name.trim().isEmpty ? 'Подписка' : name.trim(),
      url: url.trim(),
      updateIntervalHours: intervalHours,
    );
    subscriptionList.add(sub);
    await _store.saveSubscriptions(subscriptionList);
    notifyListeners();
    await updateSubscription(sub);
    return sub;
  }

  Future<void> updateSubscription(Subscription sub, {bool silent = false}) async {
    try {
      final result = await _subs.update(sub);
      // Удаляем старые профили этой подписки и добавляем новые.
      profiles.removeWhere((p) => p.subscriptionId == sub.id);
      profiles.addAll(result);
      await _store.saveSubscriptions(subscriptionList);
      _persistProfiles();
      _log.info('Подписка «${sub.name}»: ${result.length} серверов');
    } catch (e) {
      if (!silent) {
        lastError = e.toString();
        _log.error('Ошибка подписки «${sub.name}»: $e');
      }
    }
    notifyListeners();
  }

  Future<void> updateAllSubscriptions({bool silent = false}) async {
    for (final sub in subscriptionList) {
      await updateSubscription(sub, silent: silent);
    }
  }

  Future<void> deleteSubscription(Subscription sub) async {
    subscriptionList.removeWhere((s) => s.id == sub.id);
    profiles.removeWhere((p) => p.subscriptionId == sub.id);
    if (selected?.subscriptionId == sub.id) {
      selected = profiles.isNotEmpty ? profiles.first : null;
      _store.setSelectedProfile(selected?.id);
    }
    await _store.saveSubscriptions(subscriptionList);
    _persistProfiles();
    notifyListeners();
  }

  // ------------------------------------------------------- задержка

  Future<int> measurePing(VpnProfile profile,
      {Duration timeout = const Duration(seconds: 3)}) async {
    try {
      final sw = Stopwatch()..start();
      final socket = await Socket.connect(
        profile.host,
        profile.port,
        timeout: timeout,
      );
      sw.stop();
      socket.destroy();
      final ms = sw.elapsedMilliseconds;
      pingCache[profile.id] = ms;
      notifyListeners();
      return ms;
    } catch (_) {
      pingCache[profile.id] = -1;
      notifyListeners();
      return -1;
    }
  }

  Future<void> measureAllPings({List<VpnProfile>? only}) async {
    final targets = only ?? profiles.take(30).toList();
    for (final p in targets) {
      await measurePing(p);
    }
  }

  // ------------------------------------------------------- настройки

  Future<void> updateSettings(void Function(AppSettings) mutate) async {
    mutate(settings);
    await _store.saveSettings(settings.toJson());
    locale = Locale(settings.language);
    notifyListeners();
  }

  Future<void> setLanguage(String code) =>
      updateSettings((s) => s.language = code);

  Future<void> completeOnboarding() async {
    onboardingDone = true;
    await _store.setOnboardingDone();
    notifyListeners();
  }

  // ------------------------------------------------------- утилиты UI

  List<VpnProfile> profilesFor(Subscription? sub) {
    if (sub == null) return profiles;
    return profiles.where((p) => p.subscriptionId == sub.id).toList();
  }

  String shareProxyUri(String host) {
    final user = settings.shareUser;
    final pass = settings.sharePass;
    final auth = (user != null && user.isNotEmpty)
        ? '${Uri.encodeComponent(user)}:${Uri.encodeComponent(pass ?? '')}@'
        : '';
    return 'socks5://$auth$host:${settings.sharePort}';
  }

  @override
  void dispose() {
    _statsTimer?.cancel();
    _statusSub?.cancel();
    _vpn.dispose();
    _log.dispose();
    super.dispose();
  }
}
