import 'package:flutter/material.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_pill.dart';
import 'logs_screen.dart';

/// Настройки приложения.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              s('settings_title'),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 6),

            // --------------------------------------------------- general
            SectionHeader(title: s('settings_section_general')),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.language_rounded,
                      color: AuraColors.accent2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s('settings_language'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'ru', label: Text('RU')),
                      ButtonSegment(value: 'en', label: Text('EN')),
                    ],
                    selected: {state.settings.language},
                    onSelectionChanged: (v) =>
                        state.setLanguage(v.first),
                    showSelectedIcon: false,
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ),
            ),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  const Icon(Icons.dark_mode_rounded,
                      color: AuraColors.accent2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s('settings_theme'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Text(s('settings_theme_value'),
                      style: const TextStyle(
                          color: AuraColors.textSecondary, fontSize: 12.5)),
                ],
              ),
            ),
            SwitchRow(
              title: s('settings_auto_connect'),
              value: state.settings.autoConnect,
              onChanged: (v) =>
                  state.updateSettings((st) => st.autoConnect = v),
            ),
            SwitchRow(
              title: s('settings_auto_update_subs'),
              value: state.settings.autoUpdateSubs,
              onChanged: (v) =>
                  state.updateSettings((st) => st.autoUpdateSubs = v),
            ),

            // --------------------------------------------------- network
            SectionHeader(title: s('settings_section_network')),
            _TextSettingRow(
              icon: Icons.dns_rounded,
              label: s('settings_dns'),
              hint: s('settings_dns_hint'),
              value: state.settings.dnsServers.join(', '),
              onSubmitted: (v) => state.updateSettings((st) => st.dnsServers = v
                  .split(',')
                  .map((e) => e.trim())
                  .where((e) => e.isNotEmpty)
                  .toList()),
            ),
            _TextSettingRow(
              icon: Icons.height_rounded,
              label: s('settings_mtu'),
              value: '${state.settings.mtu}',
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final n = int.tryParse(v.trim());
                if (n != null && n >= 576 && n <= 9000) {
                  state.updateSettings((st) => st.mtu = n);
                }
              },
            ),
            _TextSettingRow(
              icon: Icons.settings_ethernet_rounded,
              label: s('settings_socks_port'),
              value: '${state.settings.socksPort}',
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final n = int.tryParse(v.trim());
                if (n != null && n > 0 && n < 65535) {
                  state.updateSettings((st) => st.socksPort = n);
                }
              },
            ),
            SwitchRow(
              title: s('settings_mux'),
              value: state.settings.mux,
              onChanged: (v) => state.updateSettings((st) => st.mux = v),
            ),

            // ------------------------------------------------------ share
            SectionHeader(title: s('settings_section_share')),
            _TextSettingRow(
              icon: Icons.wifi_tethering_rounded,
              label: s('settings_share_port'),
              value: '${state.settings.sharePort}',
              keyboardType: TextInputType.number,
              onSubmitted: (v) {
                final n = int.tryParse(v.trim());
                if (n != null && n > 0 && n < 65535) {
                  state.updateSettings((st) => st.sharePort = n);
                }
              },
            ),
            _TextSettingRow(
              icon: Icons.person_rounded,
              label: s('settings_share_user'),
              value: state.settings.shareUser ?? '',
              onSubmitted: (v) => state
                  .updateSettings((st) => st.shareUser = v.trim().isEmpty ? null : v.trim()),
            ),
            _TextSettingRow(
              icon: Icons.lock_rounded,
              label: s('settings_share_pass'),
              value: state.settings.sharePass ?? '',
              obscure: true,
              onSubmitted: (v) => state
                  .updateSettings((st) => st.sharePass = v.isEmpty ? null : v),
            ),

            // ------------------------------------------------------- core
            SectionHeader(title: s('settings_section_core')),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  const Icon(Icons.bug_report_rounded,
                      color: AuraColors.accent2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s('settings_log_level'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  DropdownButton<String>(
                    value: state.settings.logLevel,
                    dropdownColor: AuraColors.surfaceLight,
                    underline: const SizedBox.shrink(),
                    style: const TextStyle(
                        color: AuraColors.textPrimary, fontSize: 13),
                    items: const [
                      DropdownMenuItem(value: 'error', child: Text('error')),
                      DropdownMenuItem(value: 'warning', child: Text('warning')),
                      DropdownMenuItem(value: 'info', child: Text('info')),
                      DropdownMenuItem(value: 'debug', child: Text('debug')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        state.updateSettings((st) => st.logLevel = v);
                      }
                    },
                  ),
                ],
              ),
            ),
            GlassCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const AboutScreen()),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      color: AuraColors.accent2, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s('settings_about'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                  Text('${s('settings_version')} 1.0.0',
                      style: const TextStyle(
                          color: AuraColors.textSecondary, fontSize: 12)),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right_rounded,
                      color: AuraColors.textFaint, size: 18),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _TextSettingRow extends StatelessWidget {
  const _TextSettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onSubmitted,
    this.hint,
    this.keyboardType,
    this.obscure = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? hint;
  final TextInputType? keyboardType;
  final bool obscure;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AuraColors.accent2, size: 20),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 3,
            child: TextFormField(
              key: ValueKey('$label$value'),
              initialValue: value,
              keyboardType: keyboardType,
              obscureText: obscure,
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: AuraColors.textPrimary, fontSize: 13),
              decoration: InputDecoration(
                hintText: hint,
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onFieldSubmitted: onSubmitted,
            ),
          ),
        ],
      ),
    );
  }
}
