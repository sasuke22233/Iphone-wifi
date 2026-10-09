import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/vpn_profile.dart';
import '../widgets/glass_card.dart';
import '../widgets/server_tile.dart';
import 'edit_profile_screen.dart';
import 'import_screen.dart';

/// Список серверов: поиск, фильтр по подпискам, ping, действия.
class ServersScreen extends StatefulWidget {
  const ServersScreen({super.key});

  @override
  State<ServersScreen> createState() => _ServersScreenState();
}

class _ServersScreenState extends State<ServersScreen> {
  String _query = '';

  /// null = «Все», иначе id подписки.
  String? _filterSubId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final state = AppStateScope.of(context);

    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final profiles = _filter(_selectProfiles(state));
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s('servers_title'),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.6,
                      ),
                    ),
                  ),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    radius: 14,
                    onTap: () => state.updateAllSubscriptions(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.refresh_rounded,
                            size: 18, color: AuraColors.accent2),
                        const SizedBox(width: 6),
                        Text(
                          s('servers_update_subs'),
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: AuraColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  GlassCard(
                    padding: const EdgeInsets.all(8),
                    radius: 14,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ImportScreen()),
                    ),
                    child: const Icon(Icons.add_rounded,
                        color: AuraColors.accent2, size: 22),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                style: const TextStyle(color: AuraColors.textPrimary),
                decoration: InputDecoration(
                  hintText: s('search_hint'),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: AuraColors.textFaint),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            _SubFilterChips(
              state: state,
              s: s,
              selectedSubId: _filterSubId,
              onSelected: (id) => setState(() => _filterSubId = id),
            ),
            const SizedBox(height: 6),
            Expanded(
              child: state.profiles.isEmpty
                  ? _EmptyState(s: s)
                  : profiles.isEmpty
                      ? Center(
                          child: Text(
                            s('servers_empty'),
                            style: const TextStyle(
                                color: AuraColors.textSecondary),
                          ),
                        )
                      : RefreshIndicator(
                          color: AuraColors.accent,
                          onRefresh: () => state.updateAllSubscriptions(),
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                            itemCount: profiles.length,
                            itemBuilder: (context, i) {
                              final profile = profiles[i];
                              return ServerTile(
                                profile: profile,
                                selected:
                                    state.selected?.id == profile.id,
                                pingMs: state.pingCache[profile.id],
                                onTap: () async {
                                  state.selectProfile(profile);
                                  await state.connect(profile: profile);
                                },
                                onLongPress: () =>
                                    _showMenu(context, state, s, profile),
                              );
                            },
                          ),
                        ),
            ),
          ],
        );
      },
    );
  }

  List<VpnProfile> _selectProfiles(AppState state) {
    if (_filterSubId == null) return state.profiles;
    return state.profiles
        .where((p) => p.subscriptionId == _filterSubId)
        .toList();
  }

  List<VpnProfile> _filter(List<VpnProfile> profiles) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return profiles;
    return profiles.where((p) {
      return p.name.toLowerCase().contains(q) ||
          p.host.toLowerCase().contains(q) ||
          p.protocol.label.toLowerCase().contains(q);
    }).toList();
  }

  void _showMenu(
      BuildContext context, AppState state, S s, VpnProfile profile) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AuraColors.surface,
      builder: (sheetContext) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  profile.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  profile.serverLabel,
                  style: const TextStyle(
                      color: AuraColors.textSecondary, fontSize: 12.5),
                ),
                const SizedBox(height: 16),
                _MenuTile(
                  icon: Icons.power_settings_new_rounded,
                  label: s('menu_connect'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    state.selectProfile(profile);
                    state.connect(profile: profile);
                  },
                ),
                _MenuTile(
                  icon: Icons.bolt_rounded,
                  label: s('menu_speed_test'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    state.measurePing(profile);
                  },
                ),
                _MenuTile(
                  icon: Icons.link_rounded,
                  label: s('menu_share'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final link = profile.shareLink;
                    if (link != null) {
                      Clipboard.setData(ClipboardData(text: link));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(s('copied'))),
                      );
                    }
                  },
                ),
                _MenuTile(
                  icon: Icons.edit_rounded,
                  label: s('edit'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => EditProfileScreen(profile: profile),
                      ),
                    );
                  },
                ),
                _MenuTile(
                  icon: Icons.delete_outline_rounded,
                  label: s('delete'),
                  color: AuraColors.danger,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    state.deleteProfile(profile);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SubFilterChips extends StatelessWidget {
  const _SubFilterChips({
    required this.state,
    required this.s,
    required this.selectedSubId,
    required this.onSelected,
  });

  final AppState state;
  final S s;
  final String? selectedSubId;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: Text(s('servers_all')),
          selected: selectedSubId == null,
          onSelected: (_) => onSelected(null),
          selectedColor: AuraColors.accent.withOpacity(0.25),
          labelStyle: TextStyle(
            color: selectedSubId == null
                ? AuraColors.accent2
                : AuraColors.textSecondary,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          backgroundColor: Colors.white.withOpacity(0.05),
          side: BorderSide.none,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ),
      ),
      for (final sub in state.subscriptionList)
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(sub.name),
            selected: selectedSubId == sub.id,
            onSelected: (_) => onSelected(sub.id),
            selectedColor: AuraColors.accent.withOpacity(0.25),
            labelStyle: TextStyle(
              color: selectedSubId == sub.id
                  ? AuraColors.accent2
                  : AuraColors.textSecondary,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
            backgroundColor: Colors.white.withOpacity(0.05),
            side: BorderSide.none,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        ),
    ];

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        children: chips,
      ),
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? AuraColors.textPrimary;
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: c),
      title:
          Text(label, style: TextStyle(color: c, fontWeight: FontWeight.w600)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.s});

  final S s;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    AuraColors.accent.withOpacity(0.22),
                    AuraColors.accent2.withOpacity(0.08),
                  ],
                ),
              ),
              child: const Icon(Icons.cloud_off_rounded,
                  size: 42, color: AuraColors.accent2),
            ),
            const SizedBox(height: 18),
            Text(
              s('servers_empty'),
              textAlign: TextAlign.center,
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              s('servers_empty_sub'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AuraColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const ImportScreen()),
              ),
              icon: const Icon(Icons.add_rounded),
              label: Text(s('servers_add')),
            ),
          ],
        ),
      ),
    );
  }
}
