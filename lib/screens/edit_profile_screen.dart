import 'package:flutter/material.dart';

import '../app.dart';
import '../core/strings.dart';
import '../core/theme.dart';
import '../models/vpn_profile.dart';
import '../widgets/gradient_background.dart';

/// Ручное создание/редактирование профиля.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key, this.profile});

  final VpnProfile? profile;

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _name;
  late final TextEditingController _host;
  late final TextEditingController _port;
  late final TextEditingController _userId;
  late final TextEditingController _password;
  late final TextEditingController _method;
  late final TextEditingController _sni;
  late final TextEditingController _flow;
  late final TextEditingController _fingerprint;
  late final TextEditingController _publicKey;
  late final TextEditingController _shortId;
  late final TextEditingController _path;
  late final TextEditingController _hostHeader;
  late final TextEditingController _serviceName;
  late final TextEditingController _alpn;
  late final TextEditingController _obfs;
  late final TextEditingController _extra;

  late VpnProtocol _protocol;
  late TransportType _transport;
  late SecurityType _security;
  late bool _allowInsecure;

  @override
  void initState() {
    super.initState();
    final p = widget.profile;
    _protocol = p?.protocol ?? VpnProtocol.vless;
    _transport = p?.transport ?? TransportType.tcp;
    _security = p?.security ?? SecurityType.tls;
    _allowInsecure = p?.allowInsecure ?? false;

    _name = TextEditingController(text: p?.name ?? '');
    _host = TextEditingController(text: p?.host ?? '');
    _port = TextEditingController(text: '${p?.port ?? 443}');
    _userId = TextEditingController(text: p?.userId ?? '');
    _password = TextEditingController(text: p?.password ?? '');
    _method = TextEditingController(text: p?.method ?? '');
    _sni = TextEditingController(text: p?.sni ?? '');
    _flow = TextEditingController(text: p?.flow ?? '');
    _fingerprint = TextEditingController(text: p?.fingerprint ?? '');
    _publicKey = TextEditingController(text: p?.realityPublicKey ?? '');
    _shortId = TextEditingController(text: p?.realityShortId ?? '');
    _path = TextEditingController(text: p?.transportPath ?? '');
    _hostHeader = TextEditingController(text: p?.transportHost ?? '');
    _serviceName = TextEditingController(text: p?.serviceName ?? '');
    _alpn = TextEditingController(text: (p?.alpn ?? []).join(','));
    _obfs = TextEditingController(text: p?.obfsPassword ?? '');
    _extra = TextEditingController(text: p?.xhttpExtra ?? '');
  }

  @override
  void dispose() {
    for (final c in [
      _name, _host, _port, _userId, _password, _method, _sni, _flow,
      _fingerprint, _publicKey, _shortId, _path, _hostHeader, _serviceName,
      _alpn, _obfs, _extra,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _save() {
    final s = S.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = AppStateScope.of(context);
    final existing = widget.profile;

    final profile = VpnProfile(
      id: existing?.id ??
          DateTime.now().microsecondsSinceEpoch.toString(),
      name: _name.text.trim().isEmpty ? _host.text.trim() : _name.text.trim(),
      protocol: _protocol,
      host: _host.text.trim(),
      port: int.tryParse(_port.text.trim()) ?? 443,
      userId: _userId.text.trim().isEmpty ? null : _userId.text.trim(),
      password: _password.text.isEmpty ? null : _password.text,
      method: _method.text.trim().isEmpty ? null : _method.text.trim(),
      flow: _flow.text.trim().isEmpty ? null : _flow.text.trim(),
      transport: _transport,
      transportPath:
          _path.text.trim().isEmpty ? null : _path.text.trim(),
      transportHost:
          _hostHeader.text.trim().isEmpty ? null : _hostHeader.text.trim(),
      serviceName:
          _serviceName.text.trim().isEmpty ? null : _serviceName.text.trim(),
      security: _security,
      sni: _sni.text.trim().isEmpty ? null : _sni.text.trim(),
      allowInsecure: _allowInsecure,
      fingerprint: _fingerprint.text.trim().isEmpty
          ? null
          : _fingerprint.text.trim(),
      alpn: _alpn.text.trim().isEmpty
          ? null
          : _alpn.text
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
      realityPublicKey: _publicKey.text.trim().isEmpty
          ? null
          : _publicKey.text.trim(),
      realityShortId: _shortId.text.trim().isEmpty
          ? null
          : _shortId.text.trim(),
      obfsPassword:
          _obfs.text.isEmpty ? null : _obfs.text,
      xhttpExtra: _extra.text.trim().isEmpty ? null : _extra.text.trim(),
      subscriptionId: existing?.subscriptionId,
    );

    if (existing == null) {
      state.addProfile(profile);
    } else {
      state.updateProfile(profile);
    }
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(s('save'))));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isEdit = widget.profile != null;

    return GradientBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title:
              Text(isEdit ? s('edit_title_edit') : s('edit_title_new')),
          backgroundColor: Colors.transparent,
        ),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, kToolbarHeight + 60, 20, 32),
            children: [
              _section(s('edit_protocol')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in VpnProtocol.values)
                    ChoiceChip(
                      label: Text(p.label),
                      selected: _protocol == p,
                      onSelected: (_) => setState(() => _protocol = p),
                      selectedColor: AuraColors.accent.withOpacity(0.3),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _protocol == p
                            ? AuraColors.accent2
                            : AuraColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _field(s('edit_name'), _name),
              _field(s('edit_server'), _host,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? '—' : null),
              _field(s('edit_port'), _port, isNumber: true),

              if (_protocol == VpnProtocol.vless ||
                  _protocol == VpnProtocol.vmess ||
                  _protocol == VpnProtocol.tuic)
                _field(
                  s('edit_uuid'),
                  _userId,
                  validator: (v) =>
                      _protocol == VpnProtocol.socks ? null : _required(v),
                ),
              if (_protocol == VpnProtocol.socks)
                _field(s('edit_uuid'), _userId),
              if (_protocol != VpnProtocol.vless &&
                  _protocol != VpnProtocol.vmess)
                _field(s('edit_password'), _password),
              if (_protocol == VpnProtocol.shadowsocks)
                _field(s('edit_method'), _method),
              if (_protocol == VpnProtocol.vless)
                _field(s('edit_flow'), _flow,
                    hint: 'xtls-rprx-vision'),
              if (_protocol == VpnProtocol.hysteria2)
                _field(s('edit_obfs_password'), _obfs),

              const SizedBox(height: 8),
              if (_protocol != VpnProtocol.hysteria2 &&
                  _protocol != VpnProtocol.tuic) ...[
                _section(s('edit_transport')),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final t in TransportType.values)
                      ChoiceChip(
                        label: Text(t.label),
                        selected: _transport == t,
                        onSelected: (_) => setState(() => _transport = t),
                        selectedColor: AuraColors.accent.withOpacity(0.3),
                        backgroundColor: Colors.white.withOpacity(0.05),
                        side: BorderSide.none,
                        labelStyle: TextStyle(
                          color: _transport == t
                              ? AuraColors.accent2
                              : AuraColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _field(s('edit_path'), _path, hint: '/ws'),
                _field(s('edit_host_header'), _hostHeader),
                if (_transport == TransportType.grpc)
                  _field(s('edit_service_name'), _serviceName),
                if (_transport == TransportType.xhttp)
                  _field(s('edit_extra'), _extra, hint: '{"extra":1}'),
              ],

              const SizedBox(height: 8),
              _section(s('edit_security')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sec in SecurityType.values)
                    ChoiceChip(
                      label: Text(sec.label),
                      selected: _security == sec,
                      onSelected: (_) => setState(() => _security = sec),
                      selectedColor: AuraColors.accent.withOpacity(0.3),
                      backgroundColor: Colors.white.withOpacity(0.05),
                      side: BorderSide.none,
                      labelStyle: TextStyle(
                        color: _security == sec
                            ? AuraColors.accent2
                            : AuraColors.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _field(s('edit_sni'), _sni),
              _field(s('edit_fingerprint'), _fingerprint, hint: 'chrome'),
              _field(s('edit_alpn'), _alpn, hint: 'h2,http/1.1'),
              if (_security == SecurityType.reality) ...[
                _field(s('edit_public_key'), _publicKey),
                _field(s('edit_short_id'), _shortId),
              ],
              const SizedBox(height: 8),
              SwitchListTile(
                value: _allowInsecure,
                onChanged: (v) => setState(() => _allowInsecure = v),
                title: Text(s('edit_allow_insecure'),
                    style: const TextStyle(fontSize: 14)),
                contentPadding: EdgeInsets.zero,
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _save,
                icon: const Icon(Icons.check_rounded),
                label: Text(s('edit_save')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String? _required(String? v) =>
      (v == null || v.trim().isEmpty) ? '—' : null;

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.only(top: 18, bottom: 10),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
            color: AuraColors.textSecondary,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.1,
          ),
        ),
      );

  Widget _field(
    String label,
    TextEditingController controller, {
    String? hint,
    bool isNumber = false,
    String? Function(String?)? validator,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        style: const TextStyle(color: AuraColors.textPrimary, fontSize: 14),
        keyboardType: isNumber ? TextInputType.number : null,
        validator: validator,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
        ),
      ),
    );
  }
}
