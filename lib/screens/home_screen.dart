import 'package:flutter/material.dart';

import '../app.dart';
import '../core/formatters.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/connection_state.dart';
import '../widgets/connect_button.dart';
import '../widgets/glass_card.dart';
import '../widgets/protocol_badge.dart';
import '../widgets/stat_pill.dart';
import '../widgets/traffic_chart.dart';
import 'import_screen.dart';
import 'logs_screen.dart';

/// Главный экран: статус, кнопка подключения, статистика.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.onNavigate});

  /// Переключение вкладок нижней навигации.
  final ValueChanged<int>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final status = state.status;
        final isConnected = state.isConnected;
        final isConnecting = status == TunnelStatus.connecting ||
            status == TunnelStatus.disconnecting;

        final buttonState = isConnecting
            ? ConnectButtonState.connecting
            : isConnected
                ? ConnectButtonState.connected
                : ConnectButtonState.idle;

        final statusLabel = switch (status) {
          TunnelStatus.connected => s('status_connected'),
          TunnelStatus.connecting => s('status_connecting'),
          TunnelStatus.disconnecting => s('status_disconnecting'),
          TunnelStatus.reasserting => s('status_reconnecting'),
          TunnelStatus.invalid => s('status_error'),
          TunnelStatus.disconnected => s('status_disconnected'),
        };

        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            // Шапка
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: AuraColors.accentGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AuraColors.accent.withOpacity(0.35),
                        blurRadius: 18,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.bolt_rounded,
                      color: Colors.white, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aura VPN',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      Text(
                        isConnected ? s('home_protected') : s('home_unprotected'),
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isConnected
                              ? AuraColors.success
                              : AuraColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                GlassCard(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 8),
                  radius: 14,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  ),
                  child: const Icon(Icons.terminal_rounded,
                      color: AuraColors.textSecondary, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Статус-пилюля
            Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: (isConnected ? AuraColors.success : AuraColors.accent)
                      .withOpacity(0.13),
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: (isConnected
                            ? AuraColors.success
                            : AuraColors.accent)
                        .withOpacity(0.35),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isConnected
                            ? AuraColors.success
                            : isConnecting
                                ? AuraColors.warning
                                : AuraColors.textFaint,
                        boxShadow: [
                          if (isConnected)
                            BoxShadow(
                              color: AuraColors.success.withOpacity(0.8),
                              blurRadius: 8,
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: isConnected
                            ? AuraColors.success
                            : AuraColors.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Кнопка подключения
            Center(
              child: ConnectButton(
                state: buttonState,
                onTap: state.isBusy ? () {} : state.toggleConnection,
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                isConnected ? s('home_tap_to_disconnect') : s('home_tap_to_connect'),
                style: const TextStyle(
                  color: AuraColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            if (state.lastError != null) ...[
              const SizedBox(height: 12),
              GlassCard(
                borderColor: AuraColors.danger.withOpacity(0.4),
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AuraColors.danger, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        state.lastError!,
                        style: const TextStyle(
                            color: AuraColors.danger, fontSize: 12),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => state.connect(),
                      child: Text(
                        s('retry'),
                        style: const TextStyle(
                          color: AuraColors.accent2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 18),

            // Текущий сервер
            SectionHeader(title: s('home_current_server')),
            GlassCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
              child: state.selected == null
                  ? Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            color: Colors.white.withOpacity(0.06),
                          ),
                          child: const Icon(Icons.add_rounded,
                              color: AuraColors.accent2),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(s('home_no_server'),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14.5)),
                              const SizedBox(height: 2),
                              Text(s('home_no_server_sub'),
                                  style: const TextStyle(
                                      color: AuraColors.textSecondary,
                                      fontSize: 11.5)),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AuraColors.textFaint),
                      ],
                    )
                  : Row(
                      children: [
                        Container(
                          width: 46,
                          height: 46,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: AuraColors.accentGradient,
                          ),
                          child: const Icon(Icons.shield_rounded,
                              color: Colors.white),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                state.selected!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  ProtocolBadge(
                                      protocol: state.selected!.protocol,
                                      compact: true),
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      state.selected!.serverLabel,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                          color: AuraColors.textSecondary,
                                          fontSize: 11),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            color: AuraColors.textFaint),
                      ],
                    ),
            ),
            const SizedBox(height: 6),

            // Статистика
            SectionHeader(title: s('home_download')),
            Row(
              children: [
                StatPill(
                  icon: Icons.arrow_downward_rounded,
                  label: s('home_download'),
                  value: Fmt.speed(
                      state.speedHistory.isEmpty ? 0 : state.speedHistory.last.downBps),
                  color: AuraColors.accent2,
                ),
                const SizedBox(width: 10),
                StatPill(
                  icon: Icons.arrow_upward_rounded,
                  label: s('home_upload'),
                  value: Fmt.speed(
                      state.speedHistory.isEmpty ? 0 : state.speedHistory.last.upBps),
                  color: AuraColors.accent,
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                StatPill(
                  icon: Icons.timelapse_rounded,
                  label: s('home_duration'),
                  value: Fmt.duration(state.sessionDuration),
                  color: AuraColors.success,
                ),
                const SizedBox(width: 10),
                StatPill(
                  icon: Icons.data_usage_rounded,
                  label: '${Fmt.bytes(state.traffic.rxBytes)} / ${Fmt.bytes(state.traffic.txBytes)}',
                  value: 'Rx / Tx',
                  color: AuraColors.warning,
                ),
              ],
            ),
            const SizedBox(height: 12),

            GlassCard(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed_rounded,
                          size: 16, color: AuraColors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        '${s('home_download')} · ${s('home_upload')}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: AuraColors.textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TrafficChart(points: state.speedHistory),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Быстрые действия
            Row(
              children: [
                _QuickAction(
                  icon: Icons.file_download_done_rounded,
                  label: s('home_quick_import'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ImportScreen()),
                  ),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.wifi_tethering_rounded,
                  label: s('home_quick_hotspot'),
                  onTap: () => onNavigate?.call(2),
                ),
                const SizedBox(width: 10),
                _QuickAction(
                  icon: Icons.terminal_rounded,
                  label: s('home_quick_logs'),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LogsScreen()),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        onTap: onTap,
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Column(
          children: [
            Icon(icon, color: AuraColors.accent2, size: 22),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AuraColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
