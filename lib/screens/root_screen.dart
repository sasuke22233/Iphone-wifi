import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/gradient_background.dart';
import 'home_screen.dart';
import 'hotspot_screen.dart';
import 'servers_screen.dart';
import 'settings_screen.dart';

/// Оболочка с нижней навигацией (стек экранов).
class RootScreen extends StatefulWidget {
  const RootScreen({super.key});

  @override
  State<RootScreen> createState() => _RootScreenState();
}

class _RootScreenState extends State<RootScreen> {
  int _index = 0;

  List<Widget> _screens() => [
        HomeScreen(onNavigate: (i) => setState(() => _index = i)),
        const ServersScreen(),
        const HotspotScreen(),
        const SettingsScreen(),
      ];

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GradientBackground(
      glow: false,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        resizeToAvoidBottomInset: false,
        body: SafeArea(
          bottom: false,
          child: IndexedStack(index: _index, children: _screens()),
        ),
        bottomNavigationBar: _GlassNavBar(
          index: _index,
          onChanged: (i) => setState(() => _index = i),
          labels: [
            s('nav_home'),
            s('nav_servers'),
            s('nav_hotspot'),
            s('nav_settings'),
          ],
        ),
      ),
    );
  }
}

class _GlassNavBar extends StatelessWidget {
  const _GlassNavBar({
    required this.index,
    required this.onChanged,
    required this.labels,
  });

  final int index;
  final ValueChanged<int> onChanged;
  final List<String> labels;

  static const _icons = [
    Icons.home_rounded,
    Icons.dns_rounded,
    Icons.wifi_tethering_rounded,
    Icons.tune_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xF0141B2E),
        border: Border(
          top: BorderSide(color: Colors.white.withOpacity(0.07)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            children: List.generate(_icons.length, (i) {
              final active = i == index;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOut,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: active
                          ? LinearGradient(
                              colors: [
                                AuraColors.accent.withOpacity(0.20),
                                AuraColors.accent2.withOpacity(0.10),
                              ],
                            )
                          : null,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _icons[i],
                          size: 23,
                          color: active
                              ? AuraColors.accent2
                              : AuraColors.textFaint,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          labels[i],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight:
                                active ? FontWeight.w700 : FontWeight.w500,
                            color: active
                                ? AuraColors.accent2
                                : AuraColors.textFaint,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
