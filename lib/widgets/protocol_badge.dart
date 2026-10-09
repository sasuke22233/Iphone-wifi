import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../models/vpn_profile.dart';

/// Цветной бейдж протокола (VLESS, VMess, …).
class ProtocolBadge extends StatelessWidget {
  const ProtocolBadge({super.key, required this.protocol, this.compact = false});

  final VpnProtocol protocol;
  final bool compact;

  (Color, Color) get _colors {
    switch (protocol) {
      case VpnProtocol.vless:
        return (AuraColors.accent, const Color(0x227C5CFF));
      case VpnProtocol.vmess:
        return (AuraColors.accent2, const Color(0x2200C2FF));
      case VpnProtocol.trojan:
        return (const Color(0xFFFF7AB6), const Color(0x22FF7AB6));
      case VpnProtocol.shadowsocks:
        return (const Color(0xFFFFB454), const Color(0x22FFB454));
      case VpnProtocol.hysteria2:
        return (AuraColors.success, const Color(0x222CE5A6));
      case VpnProtocol.tuic:
        return (const Color(0xFF9C8CFF), const Color(0x229C8CFF));
      case VpnProtocol.socks:
        return (AuraColors.textSecondary, const Color(0x229AA3C0));
    }
  }

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = _colors;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 10,
        vertical: compact ? 3 : 4,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        protocol.label,
        style: TextStyle(
          color: fg,
          fontSize: compact ? 10 : 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

/// Бейдж транспорта/безопасности.
class TagChip extends StatelessWidget {
  const TagChip({super.key, required this.label, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: (color ?? AuraColors.textSecondary).withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color ?? AuraColors.textSecondary,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
