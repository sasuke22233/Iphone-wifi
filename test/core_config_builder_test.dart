import 'dart:convert';

import 'package:aura_vpn/models/vpn_profile.dart';
import 'package:aura_vpn/services/core_config_builder.dart';
import 'package:flutter_test/flutter_test.dart';

VpnProfile _vlessProfile() => VpnProfile(
      id: '1',
      name: 'test',
      protocol: VpnProtocol.vless,
      host: 'srv.example.com',
      port: 443,
      userId: '11111111-2222-3333-4444-555555555555',
      flow: 'xtls-rprx-vision',
      transport: TransportType.xhttp,
      transportPath: '/xh',
      transportHost: 'cdn.example.com',
      xhttpMode: 'auto',
      security: SecurityType.reality,
      sni: 'www.google.com',
      fingerprint: 'chrome',
      realityPublicKey: 'PUBKEY',
      realityShortId: 'abcd',
    );

void main() {
  group('CoreConfigBuilder', () {
    test('builds valid xray config for VLESS+REALITY+XHTTP', () {
      final cfg = CoreConfigBuilder.buildXrayConfig(
        profile: _vlessProfile(),
        socksPort: 10808,
      );

      final json = jsonEncode(cfg);
      expect(json.contains('vless'), isTrue);
      expect(json.contains('xhttp'), isTrue);
      expect(json.contains('reality'), isTrue);

      final outbounds = cfg['outbounds'] as List;
      final proxy = outbounds.first as Map<String, dynamic>;
      expect(proxy['protocol'], 'vless');
      final stream = proxy['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], 'xhttp');
      expect(stream['security'], 'reality');
      final reality = stream['realitySettings'] as Map<String, dynamic>;
      expect(reality['publicKey'], 'PUBKEY');
      expect(reality['shortId'], 'abcd');
      expect(reality['serverName'], 'www.google.com');

      // Маршрутизация: сервер — напрямую.
      final routing = cfg['routing'] as Map<String, dynamic>;
      final rules = routing['rules'] as List;
      expect(rules.isNotEmpty, isTrue);
    });

    test('share proxy binds 0.0.0.0', () {
      final cfg = CoreConfigBuilder.buildXrayConfig(
        profile: _vlessProfile(),
        socksPort: 10808,
        listenAll: true,
        sharePort: 10809,
        shareUser: 'user',
        sharePass: 'pass',
      );
      final inbounds = cfg['inbounds'] as List;
      final socks = inbounds.first as Map<String, dynamic>;
      expect(socks['listen'], '0.0.0.0');
      final share = inbounds.last as Map<String, dynamic>;
      expect(share['port'], 10809);
    });

    test('builds hysteria2 outbound', () {
      final p = VpnProfile(
        id: '2',
        name: 'hy2',
        protocol: VpnProtocol.hysteria2,
        host: 'hy.example.com',
        port: 8443,
        password: 'pw',
        obfsPassword: 'obfs',
        security: SecurityType.tls,
        sni: 'hy.example.com',
      );
      final outbound = CoreConfigBuilder.buildOutbound(p);
      expect(outbound['protocol'], 'hysteria2');
      final settings = outbound['settings'] as Map<String, dynamic>;
      final servers = settings['servers'] as List;
      final server = servers.first as Map<String, dynamic>;
      expect(server['password'], 'pw');
      expect((server['obfs'] as Map)['type'], 'salamander');
    });

    test('builds trojan+ws outbound', () {
      final p = VpnProfile(
        id: '3',
        name: 'tr',
        protocol: VpnProtocol.trojan,
        host: 'tr.example.com',
        port: 443,
        password: 'secret',
        transport: TransportType.ws,
        transportPath: '/trojan',
        transportHost: 'cdn.example.com',
        security: SecurityType.tls,
        sni: 'cdn.example.com',
      );
      final outbound = CoreConfigBuilder.buildOutbound(p);
      expect(outbound['protocol'], 'trojan');
      final stream = outbound['streamSettings'] as Map<String, dynamic>;
      expect(stream['network'], 'ws');
      expect(stream['security'], 'tls');
    });

    test('hev config contains socks port and low-memory settings', () {
      final yaml = CoreConfigBuilder.buildHevConfig(socksPort: 12345);
      expect(yaml.contains('port: 12345'), isTrue);
      expect(yaml.contains('max-session-count'), isTrue);
    });
  });
}
