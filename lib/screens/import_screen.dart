import 'package:flutter/material.dart';

import 'package:mobile_scanner/mobile_scanner.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../services/share_link_parser.dart';
import '../widgets/glass_card.dart';
import '../widgets/gradient_background.dart';
import 'edit_profile_screen.dart';

/// Импорт: ссылка, подписка, QR-код, ручное создание профиля.
class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs =
      TabController(length: 4, vsync: this);

  final TextEditingController _linkCtrl = TextEditingController();
  final TextEditingController _subUrlCtrl = TextEditingController();
  final TextEditingController _subNameCtrl = TextEditingController();
  bool _scanning = false;

  @override
  void dispose() {
    _tabs.dispose();
    _linkCtrl.dispose();
    _subUrlCtrl.dispose();
    _subNameCtrl.dispose();
    super.dispose();
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _importLinks() {
    final s = S.of(context);
    final text = _linkCtrl.text.trim();
    if (text.isEmpty) {
      _toast(s('import_paste_error'));
      return;
    }
    final count = AppStateScope.of(context).importLinks(text);
    if (count == 0) {
      _toast(s('import_invalid'));
      return;
    }
    _toast(count == 1
        ? s('import_success_one')
        : '${s('import_success_many')}$count');
    _linkCtrl.clear();
  }

  Future<void> _importSubscription() async {
    final s = S.of(context);
    final url = _subUrlCtrl.text.trim();
    if (url.isEmpty) {
      _toast(s('import_paste_error'));
      return;
    }
    final state = AppStateScope.of(context);
    final sub = await state.addSubscription(
      _subNameCtrl.text.trim().isEmpty ? 'Подписка' : _subNameCtrl.text.trim(),
      url,
    );
    _toast('${s('import_sub_success')}${sub.name}');
    _subUrlCtrl.clear();
    _subNameCtrl.clear();
    if (mounted && state.profiles.isNotEmpty) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return GradientBackground(
      child: Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(s('import_title')),
        backgroundColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 60, 20, 0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabs,
                indicator: BoxDecoration(
                  color: AuraColors.accent.withOpacity(0.22),
                  borderRadius: BorderRadius.circular(14),
                ),
                dividerColor: Colors.transparent,
                labelColor: AuraColors.accent2,
                unselectedLabelColor: AuraColors.textSecondary,
                labelStyle:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                tabs: [
                  Tab(text: s('import_tab_link')),
                  Tab(text: s('import_tab_sub')),
                  Tab(text: s('import_tab_qr')),
                  Tab(text: s('import_tab_manual')),
                ],
              ),
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildLinkTab(s),
                _buildSubTab(s),
                _buildQrTab(s),
                _buildManualTab(s),
              ],
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ------------------------------------------------------------ ссылка

  Widget _buildLinkTab(S s) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s('import_link_label'),
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14)),
              const SizedBox(height: 12),
              TextField(
                controller: _linkCtrl,
                maxLines: 5,
                style: const TextStyle(
                    color: AuraColors.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  hintText: s('import_link_hint'),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _importLinks,
                icon: const Icon(Icons.download_rounded),
                label: Text(s('import_add')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Row(
            children: [
              const Icon(Icons.info_outline_rounded,
                  color: AuraColors.accent2, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'VLESS (Reality) · VMess · Trojan · Shadowsocks · '
                  'Hysteria2 · TUIC · SOCKS',
                  style: const TextStyle(
                      color: AuraColors.textSecondary, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------- подписка

  Widget _buildSubTab(S s) {
    final state = AppStateScope.of(context);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _subNameCtrl,
                style: const TextStyle(color: AuraColors.textPrimary),
                decoration: InputDecoration(labelText: s('import_sub_name')),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _subUrlCtrl,
                style: const TextStyle(color: AuraColors.textPrimary),
                decoration: InputDecoration(labelText: s('import_sub_url')),
                keyboardType: TextInputType.url,
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _importSubscription,
                icon: const Icon(Icons.cloud_download_rounded),
                label: Text(s('import_add')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        for (final sub in state.subscriptionList)
          GlassCard(
            margin: const EdgeInsets.only(bottom: 10),
            onTap: () => state.updateSubscription(sub),
            child: Row(
              children: [
                const Icon(Icons.rss_feed_rounded, color: AuraColors.accent2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(sub.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14)),
                      const SizedBox(height: 3),
                      Text(
                        sub.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AuraColors.textFaint, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => state.deleteSubscription(sub),
                  icon: const Icon(Icons.delete_outline_rounded,
                      color: AuraColors.danger, size: 20),
                ),
              ],
            ),
          ),
      ],
    );
  }

  // ---------------------------------------------------------------- QR

  Widget _buildQrTab(S s) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          GlassCard(
            child: Column(
              children: [
                Text(s('import_scan_hint'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        color: AuraColors.textSecondary, fontSize: 13)),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => setState(() => _scanning = !_scanning),
                  icon: Icon(_scanning
                      ? Icons.close_rounded
                      : Icons.qr_code_scanner_rounded),
                  label: Text(_scanning ? s('close') : s('import_scan_qr')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_scanning)
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: MobileScanner(
                  onDetect: (capture) {
                    final raw = capture.barcodes.isNotEmpty
                        ? capture.barcodes.first.rawValue
                        : null;
                    if (raw == null || raw.isEmpty) return;
                    setState(() => _scanning = false);
                    final count =
                        AppStateScope.of(context).importLinks(raw);
                    if (count > 0) {
                      _toast(S.of(context).import_success_one);
                      Navigator.of(context).pop();
                    } else {
                      _toast(S.of(context).import_invalid);
                    }
                  },
                ),
              ),
            )
          else
            Expanded(
              child: Center(
                child: Icon(Icons.qr_code_2_rounded,
                    size: 120,
                    color: AuraColors.textFaint.withOpacity(0.3)),
              ),
            ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------ вручную

  Widget _buildManualTab(S s) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        GlassCard(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EditProfileScreen()),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: AuraColors.accentGradient,
                ),
                child: const Icon(Icons.edit_note_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s('import_tab_manual'),
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(
                      s('edit_title_new'),
                      style: const TextStyle(
                          color: AuraColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AuraColors.textFaint),
            ],
          ),
        ),
        const SizedBox(height: 12),
        GlassCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Поддерживаемые протоколы',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in [
                    'VLESS',
                    'VLESS + REALITY',
                    'VMess',
                    'Trojan',
                    'Shadowsocks',
                    'Hysteria2',
                    'TUIC',
                    'SOCKS5',
                  ])
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: AuraColors.accent.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        p,
                        style: const TextStyle(
                            color: AuraColors.accent2,
                            fontSize: 11,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                'Транспорты: TCP, WebSocket, gRPC, HTTP/2, XHTTP, '
                'HTTPUpgrade, mKCP, QUIC. Защита: TLS, REALITY, uTLS.',
                style: TextStyle(
                    color: AuraColors.textSecondary, fontSize: 11.5),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Переиспользуемая проверка ссылки (для редактора).
bool isValidShareLink(String link) =>
    ShareLinkParser.parseSingle(link.trim()) != null;
