import 'package:flutter/material.dart';

import '../core/formatters.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/vpn_profile.dart';
import 'glass_card.dart';
import 'protocol_badge.dart';

/// Строка сервера в списке.
class ServerTile extends StatelessWidget {
  const ServerTile({
    super.key,
    required this.profile,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.pingMs,
  });

  final VpnProfile profile;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final int? pingMs;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pingColor = pingMs == null
        ? AuraColors.textFaint
        : pingMs! < 0
            ? AuraColors.danger
            : pingMs! < 120
                ? AuraColors.success
                : pingMs! < 250
                    ? AuraColors.warning
                    : AuraColors.danger;

    return GlassCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      onTap: onTap,
      borderColor: selected ? AuraColors.accent.withOpacity(0.55) : null,
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: selected
                  ? AuraColors.accentGradient
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.white.withOpacity(0.03),
                      ],
                    ),
            ),
            child: Center(
              child: Icon(
                selected ? Icons.shield_rounded : Icons.dns_rounded,
                color: selected ? Colors.white : AuraColors.textSecondary,
                size: 22,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        profile.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AuraColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ProtocolBadge(protocol: profile.protocol, compact: true),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(Icons.language_rounded,
                        size: 12, color: AuraColors.textFaint),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        profile.serverLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AuraColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (profile.security != SecurityType.none)
                      TagChip(
                        label: profile.security.label,
                        color: profile.security == SecurityType.reality
                            ? AuraColors.accent2
                            : AuraColors.success,
                      ),
                    const SizedBox(width: 6),
                    if (profile.transport != TransportType.tcp)
                      TagChip(label: profile.transport.label),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Icon(Icons.bolt_rounded, size: 14, color: pingColor),
              const SizedBox(height: 2),
              Text(
                pingMs == null ? '—' : (pingMs! < 0 ? s('error') : '${pingMs!} мс'),
                style: TextStyle(
                  color: pingColor,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                Fmt.latencyLabel(pingMs),
                style: const TextStyle(
                  color: AuraColors.textFaint,
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
          const SizedBox(width: 2),
          IconButton(
            onPressed: onLongPress,
            icon: const Icon(Icons.more_vert_rounded,
                color: AuraColors.textFaint, size: 20),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
