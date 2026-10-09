import 'package:aura_vpn/models/vpn_profile.dart';
import 'package:aura_vpn/services/share_link_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ShareLinkParser', () {
    test('parses vless link with reality', () {
      const link =
          'vless://11111111-2222-3333-4444-555555555555@www.example.com:443'
          '?encryption=none&flow=xtls-rprx-vision&security=reality'
          '&sni=www.google.com&fp=chrome&pbk=PUBKEY&sid=abcd&spx=%2F#My%20Server';
      final p = ShareLinkParser.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.protocol, VpnProtocol.vless);
      expect(p.host, 'www.example.com');
      expect(p.port, 443);
      expect(p.userId, '11111111-2222-3333-4444-555555555555');
      expect(p.flow, 'xtls-rprx-vision');
      expect(p.security, SecurityType.reality);
      expect(p.realityPublicKey, 'PUBKEY');
      expect(p.realityShortId, 'abcd');
      expect(p.name, 'My Server');
    });

    test('parses vmess base64', () {
      final payload = Uri.encodeComponent(
        '{"v":"2","ps":"VMess Node","add":"1.2.3.4","port":"8443",'
        '"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","aid":"0","scy":"auto",'
        '"net":"ws","type":"none","host":"cdn.example.com","path":"/ws",'
        '"tls":"tls","sni":"cdn.example.com"}',
      );
      // vmess:// требует base64, не URL-encoded JSON.
      final b64 = base64Of(
        '{"v":"2","ps":"VMess Node","add":"1.2.3.4","port":"8443",'
        '"id":"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee","aid":"0","scy":"auto",'
        '"net":"ws","type":"none","host":"cdn.example.com","path":"/ws",'
        '"tls":"tls","sni":"cdn.example.com"}',
      );
      // ignore: unused_local_variable
      final unused = payload;
      final p = ShareLinkParser.parseSingle('vmess://$b64');
      expect(p, isNotNull);
      expect(p!.protocol, VpnProtocol.vmess);
      expect(p.host, '1.2.3.4');
      expect(p.port, 8443);
      expect(p.transport, TransportType.ws);
      expect(p.security, SecurityType.tls);
      expect(p.name, 'VMess Node');
    });

    test('parses trojan link', () {
      const link = 'trojan://secret@host.example.com:443'
          '?security=tls&sni=host.example.com&type=grpc'
          '&serviceName=GunService#Trojan%20Node';
      final p = ShareLinkParser.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.protocol, VpnProtocol.trojan);
      expect(p.password, 'secret');
      expect(p.transport, TransportType.grpc);
      expect(p.serviceName, 'GunService');
    });

    test('parses shadowsocks SIP002', () {
      final userInfo = base64Of('aes-256-gcm:p@ssw0rd');
      final link = 'ss://$userInfo@ss.example.com:8388#SS%20Node';
      final p = ShareLinkParser.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.protocol, VpnProtocol.shadowsocks);
      expect(p.method, 'aes-256-gcm');
      expect(p.password, 'p@ssw0rd');
      expect(p.host, 'ss.example.com');
      expect(p.port, 8388);
    });

    test('parses hysteria2 link', () {
      const link = 'hysteria2://pass@hy.example.com:8443'
          '?sni=hy.example.com&obfs=salamander&obfs-password=obfs1'
          '&insecure=1#HY2';
      final p = ShareLinkParser.parseSingle(link);
      expect(p, isNotNull);
      expect(p!.protocol, VpnProtocol.hysteria2);
      expect(p.password, 'pass');
      expect(p.obfsPassword, 'obfs1');
      expect(p.allowInsecure, isTrue);
    });

    test('parses subscription text with multiple links', () {
      const text = '''
# comment
vless://11111111-2222-3333-4444-555555555555@a.example.com:443?encryption=none&security=tls&sni=a.example.com#Node1
trojan://pw@b.example.com:443?security=tls#Node2
''';
      final list = ShareLinkParser.parseText(text);
      expect(list.length, 2);
      expect(list[0].name, 'Node1');
      expect(list[1].name, 'Node2');
    });

    test('skips unknown scheme', () {
      expect(ShareLinkParser.parseSingle('unknown://foo'), isNull);
    });
  });
}

/// Мини-base64 без dart:convert в тесте — но проще через convert.
String base64Of(String input) {
  // ignore: depend_on_referenced_packages
  return _b64(input);
}

String _b64(String input) {
  final bytes = input.codeUnits;
  // utf8-совместимо для ASCII-тестов
  const chars =
      'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/';
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i += 3) {
    final b0 = bytes[i];
    final b1 = i + 1 < bytes.length ? bytes[i + 1] : 0;
    final b2 = i + 2 < bytes.length ? bytes[i + 2] : 0;
    out.write(chars[b0 >> 2]);
    out.write(chars[((b0 & 3) << 4) | (b1 >> 4)]);
    out.write(i + 1 < bytes.length ? chars[((b1 & 15) << 2) | (b2 >> 6)] : '=');
    out.write(i + 2 < bytes.length ? chars[b2 & 63] : '=');
  }
  return out.toString();
}
