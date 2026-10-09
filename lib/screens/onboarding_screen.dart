import 'package:flutter/material.dart';

import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/gradient_background.dart';

/// Красивый онбординг из трёх экранов.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next(S s) {
    if (_page >= 2) {
      widget.onDone();
      return;
    }
    _controller.nextPage(
      duration: const Duration(milliseconds: 340),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pages = [
      (
        icon: Icons.vpn_key_rounded,
        title: s('onb_1_title'),
        sub: s('onb_1_sub'),
      ),
      (
        icon: Icons.wifi_tethering_rounded,
        title: s('onb_2_title'),
        sub: s('onb_2_sub'),
      ),
      (
        icon: Icons.speed_rounded,
        title: s('onb_3_title'),
        sub: s('onb_3_sub'),
      ),
    ];

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Text(
                      'Aura VPN',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: widget.onDone,
                      child: Text(
                        s('onb_skip'),
                        style: const TextStyle(color: AuraColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: pages.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (context, i) {
                    final p = pages[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 148,
                            height: 148,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  AuraColors.accent.withOpacity(0.32),
                                  AuraColors.accent2.withOpacity(0.12),
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.12),
                              ),
                            ),
                            child: Icon(p.icon,
                                size: 64, color: AuraColors.accent2),
                          ),
                          const SizedBox(height: 36),
                          Text(
                            p.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.7,
                              height: 1.15,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            p.sub,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: AuraColors.textSecondary,
                              fontSize: 14.5,
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              // Точки-индикаторы
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(3, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: active ? 26 : 8,
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: active ? AuraColors.accentGradient : null,
                      color: active ? null : Colors.white.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
                child: FilledButton(
                  onPressed: () => _next(s),
                  child: Text(_page >= 2 ? s('onb_start') : s('onb_next')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
