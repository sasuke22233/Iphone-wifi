import 'package:flutter/material.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';

/// Логи ядра и туннеля.
class LogsScreen extends StatefulWidget {
  const LogsScreen({super.key});

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  bool _follow = true;
  final ScrollController _scrollCtrl = ScrollController();

  @override
  void dispose() {
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _autoScroll() {
    if (!_follow || !_scrollCtrl.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s('logs_title')),
          backgroundColor: Colors.transparent,
          actions: [
            IconButton(
              tooltip: s('logs_follow'),
              onPressed: () => setState(() => _follow = !_follow),
              icon: Icon(
                _follow
                    ? Icons.vertical_align_bottom_rounded
                    : Icons.pause_rounded,
                color: _follow ? AuraColors.accent2 : AuraColors.textSecondary,
              ),
            ),
            IconButton(
              tooltip: s('logs_clear'),
              onPressed: () => state.logger.clear(),
              icon: const Icon(Icons.delete_sweep_rounded,
                  color: AuraColors.textSecondary),
            ),
          ],
        ),
        body: ListenableBuilder(
          listenable: Listenable.merge([state, state.logger]),
          builder: (context, _) {
            final entries = state.logger.entries;
            _autoScroll();
            return Padding(
              padding:
                  const EdgeInsets.fromLTRB(16, kToolbarHeight + 56, 16, 16),
              child: entries.isEmpty
                  ? Center(
                      child: Text(
                        s('logs_empty'),
                        style: const TextStyle(color: AuraColors.textSecondary),
                      ),
                    )
                  : GlassCard(
                      padding: const EdgeInsets.all(12),
                      child: ListView.builder(
                        controller: _scrollCtrl,
                        itemCount: entries.length,
                        itemBuilder: (context, i) {
                          final e = entries[i];
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${e.time.hour.toString().padLeft(2, '0')}:${e.time.minute.toString().padLeft(2, '0')}:${e.time.second.toString().padLeft(2, '0')}',
                                  style: const TextStyle(
                                    color: AuraColors.textFaint,
                                    fontSize: 10,
                                    fontFamily: 'Menlo',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  e.levelTag,
                                  style: TextStyle(
                                    color: e.color,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    fontFamily: 'Menlo',
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    e.message,
                                    style: TextStyle(
                                      color: e.color,
                                      fontSize: 11,
                                      height: 1.35,
                                      fontFamily: 'Menlo',
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
            );
          },
        ),
      ),
    );
  }
}

/// Экран «О приложении» / версии ядра.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);
    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(s('settings_about')),
          backgroundColor: Colors.transparent,
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 60, 20, 24),
          children: [
            Center(
              child: Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: AuraColors.accentGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AuraColors.accent.withOpacity(0.4),
                      blurRadius: 30,
                    ),
                  ],
                ),
                child: const Icon(Icons.bolt_rounded,
                    color: Colors.white, size: 52),
              ),
            ),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'Aura VPN',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
              ),
            ),
            Center(
              child: Text(
                '${s('settings_version')} 1.0.0 (1)',
                style: const TextStyle(
                    color: AuraColors.textSecondary, fontSize: 12.5),
              ),
            ),
            const SizedBox(height: 24),
            GlassCard(
              child: Column(
                children: [
                  _AboutRow(
                    label: s('settings_core_version'),
                    value: state.coreVersion,
                  ),
                  const Divider(height: 20),
                  const _AboutRow(
                    label: 'Core',
                    value: 'Xray-core + hev-socks5-tunnel',
                  ),
                  const Divider(height: 20),
                  const _AboutRow(label: 'License', value: 'MIT'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogsScreen()),
              ),
              child: Row(
                children: [
                  const Icon(Icons.terminal_rounded,
                      color: AuraColors.accent2),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(s('logs_title'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  const Icon(Icons.chevron_right_rounded,
                      color: AuraColors.textFaint),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: const TextStyle(
                color: AuraColors.textSecondary, fontSize: 13)),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: const TextStyle(
                color: AuraColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
