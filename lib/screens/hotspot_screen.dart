import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_pill.dart';

/// Экран «Раздача Wi-Fi с VPN»:
///  1. Личная точка доступа iPhone;
///  2. Общий SOCKS5-прокси для устройств;
///  3. includeAllNetworks для захвата трафика точки доступа.
class HotspotScreen extends StatefulWidget {
  const HotspotScreen({super.key});

  @override
  State<HotspotScreen> createState() => _HotspotScreenState();
}

class _HotspotScreenState extends State<HotspotScreen> {
  String? _gateway;

  @override
  void initState() {
    super.initState();
    _resolveGateway();
  }

  Future<void> _resolveGateway() async {
    final state = AppStateScope.of(context);
    final ip = await state.hotspotService.hotspotGatewayAddress();
    if (mounted) setState(() => _gateway = ip);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final shareOn = state.shareEnabled;
        final proxyUri = state.shareProxyUri(_gateway ?? '172.20.10.1');

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              s('hotspot_title'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 10),

            // Hero
            GlassCard(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AuraColors.accent.withOpacity(0.22),
                  AuraColors.accent2.withOpacity(0.08),
                ],
              ),
              borderColor: AuraColors.accent.withOpacity(0.3),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      gradient: AuraColors.accentGradient,
                      boxShadow: [
                        BoxShadow(
                          color: AuraColors.accent.withOpacity(0.4),
                          blurRadius: 22,
                        ),
                      ],
                    ),
                    child: const Icon(Icons.wifi_tethering_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      s('hotspot_hero'),
                      style: const TextStyle(
                        color: AuraColors.textPrimary,
                        fontSize: 12.5,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Статус раздачи
            Row(
              children: [
                StatPill(
                  icon: Icons.wifi_rounded,
                  label: s('hotspot_address'),
                  value: _gateway ?? '172.20.10.1',
                  color: AuraColors.success,
                ),
                const SizedBox(width: 10),
                StatPill(
                  icon: Icons.shield_rounded,
                  label: s('nav_hotspot'),
                  value: shareOn && state.isConnected
                      ? s('hotspot_active')
                      : s('hotspot_needs_connection'),
                  color: shareOn && state.isConnected
                      ? AuraColors.success
                      : AuraColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Шаг 1 — личная точка доступа
            _StepCard(
              step: '1',
              title: s('hotspot_personal_title'),
              subtitle: s('hotspot_personal_sub'),
              icon: Icons.router_rounded,
            ),
            const SizedBox(height: 12),

            // Шаг 2 — общий прокси
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _StepBadge(step: '2'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          s('hotspot_proxy_title'),
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 14.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    s('hotspot_proxy_sub'),
                    style: const TextStyle(
                      color: AuraColors.textSecondary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SwitchRow(
                    title: s('hotspot_share_switch'),
                    subtitle: shareOn
                        ? 'SOCKS5 · ${_gateway ?? '172.20.10.1'}:${state.settings.sharePort}'
                        : null,
                    value: shareOn,
                    onChanged: (v) {
                      state.shareEnabled = v;
                      if (v && !state.isConnected) {
                        state.connect();
                      }
                    },
                  ),
                  if (shareOn) ...[
                    const SizedBox(height: 4),
                    // Адрес + копирование
                    GlassCard(
                      padding: const EdgeInsets.all(12),
                      radius: 16,
                      child: Row(
                        children: [
                          const Icon(Icons.link_rounded,
                              size: 18, color: AuraColors.accent2),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              proxyUri,
                              style: const TextStyle(
                                color: AuraColors.textPrimary,
                                fontSize: 12.5,
                                fontFamily: 'Menlo',
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              Clipboard.setData(
                                  ClipboardData(text: proxyUri));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(s('copied'))),
                              );
                            },
                            icon: const Icon(Icons.copy_rounded,
                                size: 18, color: AuraColors.accent2),
                            visualDensity: VisualDensity.compact,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    // QR
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: QrImageView(
                          data: proxyUri,
                          size: 148,
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        s('hotspot_qr_hint'),
                        style: const TextStyle(
                          color: AuraColors.textFaint,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Инструкции
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s('hotspot_guide_title'),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _GuideRow(
                      icon: Icons.phone_iphone_rounded,
                      text: s('hotspot_guide_ios')),
                  _GuideRow(
                      icon: Icons.phone_android_rounded,
                      text: s('hotspot_guide_android')),
                  _GuideRow(
                      icon: Icons.laptop_mac_rounded,
                      text: s('hotspot_guide_pc')),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Сетевые опции
            SectionHeader(title: s('settings_section_network')),
            SwitchRow(
              title: s('hotspot_include_all'),
              subtitle: s('hotspot_include_all_sub'),
              value: state.settings.includeAllNetworks,
              onChanged: (v) =>
                  state.updateSettings((st) => st.includeAllNetworks = v),
            ),
            SwitchRow(
              title: s('hotspot_exclude_local'),
              subtitle: s('hotspot_exclude_local_sub'),
              value: state.settings.excludeLocalNetworks,
              onChanged: (v) =>
                  state.updateSettings((st) => st.excludeLocalNetworks = v),
            ),
            const SizedBox(height: 12),

            // Предупреждение про iOS
            GlassCard(
              borderColor: AuraColors.warning.withOpacity(0.35),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AuraColors.warning, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        s('hotspot_ios_limit_title'),
                        style: const TextStyle(
                          color: AuraColors.warning,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    s('hotspot_ios_limit'),
                    style: const TextStyle(
                      color: AuraColors.textSecondary,
                      fontSize: 11.5,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepBadge(step: step),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AuraColors.textSecondary,
                    fontSize: 12,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: AuraColors.accent2, size: 22),
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.step});

  final String step;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        gradient: AuraColors.accentGradient,
        borderRadius: BorderRadius.circular(9),
      ),
      child: Center(
        child: Text(
          step,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AuraColors.accent2),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: AuraColors.textSecondary,
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
