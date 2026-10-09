import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription.dart';
import '../models/vpn_profile.dart';

/// Локальное хранилище (SharedPreferences): профили, подписки, настройки.
class StoreService {
  StoreService(this._prefs);

  final SharedPreferences _prefs;

  static const _kProfiles = 'profiles';
  static const _kSubs = 'subscriptions';
  static const _kSelected = 'selected_profile';
  static const _kSettings = 'settings';
  static const _kOnboarding = 'onboarding_done';

  static Future<StoreService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return StoreService(prefs);
  }

  // ------------------------------------------------------------ profiles

  List<VpnProfile> loadProfiles() {
    final raw = _prefs.getString(_kProfiles);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => VpnProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveProfiles(List<VpnProfile> profiles) async {
    final raw = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await _prefs.setString(_kProfiles, raw);
  }

  // ------------------------------------------------------- subscriptions

  List<Subscription> loadSubscriptions() {
    final raw = _prefs.getString(_kSubs);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Subscription.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveSubscriptions(List<Subscription> subs) async {
    final raw = jsonEncode(subs.map((s) => s.toJson()).toList());
    await _prefs.setString(_kSubs, raw);
  }

  // ------------------------------------------------------------ selected

  String? get selectedProfileId => _prefs.getString(_kSelected);

  Future<void> setSelectedProfile(String? id) async {
    if (id == null) {
      await _prefs.remove(_kSelected);
    } else {
      await _prefs.setString(_kSelected, id);
    }
  }

  // ------------------------------------------------------------- settings

  Map<String, dynamic> loadSettings() {
    final raw = _prefs.getString(_kSettings);
    if (raw == null || raw.isEmpty) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> saveSettings(Map<String, dynamic> settings) async {
    await _prefs.setString(_kSettings, jsonEncode(settings));
  }

  // ---------------------------------------------------------- onboarding

  bool get onboardingDone => _prefs.getBool(_kOnboarding) ?? false;

  Future<void> setOnboardingDone() async => _prefs.setBool(_kOnboarding, true);
}
