import 'dart:io';

import 'package:flutter/services.dart';

import '../core/constants.dart';

/// Информация для раздачи VPN по Wi-Fi:
///  - «Личная точка доступа» iPhone + общий SOCKS5-прокси;
///  - адреса интерфейсов (портативная точка обычно 172.20.10.x).
class HotspotService {
  static const MethodChannel _channel =
      MethodChannel(AppConstants.vpnChannel);

  /// Список IPv4-адресов устройства (кроме loopback).
  Future<List<HostAddress>> localAddresses() async {
    final result = <HostAddress>[];
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final iface in interfaces) {
        for (final addr in iface.addresses) {
          result.add(HostAddress(iface.name, addr.address));
        }
      }
    } catch (_) {
      // Нет разрешений/сети — вернём хотя бы стандартный адрес точки доступа.
    }
    return result;
  }

  /// Наиболее вероятный адрес iPhone для устройств на личной точке доступа.
  Future<String?> hotspotGatewayAddress() async {
    final addrs = await localAddresses();
    // Личная точка доступа iOS: 172.20.10.1 (маска /28).
    for (final a in addrs) {
      if (a.address.startsWith('172.20.10.')) return a.address;
    }
    for (final a in addrs) {
      if (a.address.startsWith('172.20.')) return a.address;
    }
    if (addrs.isNotEmpty) return addrs.first.address;
    return '172.20.10.1';
  }

  /// Активна ли сейчас раздача (по данным туннеля).
  Future<bool> isShareActive() async {
    try {
      final raw =
          await _channel.invokeMethod<bool>('isShareActive');
      return raw ?? false;
    } on PlatformException {
      return false;
    }
  }
}

class HostAddress {
  const HostAddress(this.interface, this.address);
  final String interface;
  final String address;

  @override
  String toString() => '$interface: $address';
}
