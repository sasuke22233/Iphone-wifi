/// Состояние VPN-туннеля (зеркало NEVPNStatus).
enum TunnelStatus {
  disconnected,
  connecting,
  connected,
  reasserting,
  disconnecting,
  invalid;

  bool get isActive =>
      this == TunnelStatus.connected || this == TunnelStatus.connecting;

  static TunnelStatus fromRaw(int raw) {
    switch (raw) {
      case 0:
        return TunnelStatus.invalid;
      case 1:
        return TunnelStatus.disconnected;
      case 2:
        return TunnelStatus.connecting;
      case 3:
        return TunnelStatus.connected;
      case 4:
        return TunnelStatus.reasserting;
      case 5:
        return TunnelStatus.disconnecting;
      default:
        return TunnelStatus.disconnected;
    }
  }

  int toRaw() {
    switch (this) {
      case TunnelStatus.invalid:
        return 0;
      case TunnelStatus.disconnected:
        return 1;
      case TunnelStatus.connecting:
        return 2;
      case TunnelStatus.connected:
        return 3;
      case TunnelStatus.reasserting:
        return 4;
      case TunnelStatus.disconnecting:
        return 5;
    }
  }
}

/// Снимок статистики трафика.
class TrafficSnapshot {
  const TrafficSnapshot({
    this.rxBytes = 0,
    this.txBytes = 0,
    this.timestamp,
  });

  final int rxBytes;
  final int txBytes;
  final DateTime? timestamp;

  static const TrafficSnapshot zero = TrafficSnapshot();

  factory TrafficSnapshot.fromJson(Map<String, dynamic> j) => TrafficSnapshot(
        rxBytes: int.tryParse(j['rxBytes']?.toString() ?? '') ?? 0,
        txBytes: int.tryParse(j['txBytes']?.toString() ?? '') ?? 0,
        timestamp: DateTime.tryParse(j['timestamp']?.toString() ?? ''),
      );

  Map<String, dynamic> toJson() => {
        'rxBytes': rxBytes,
        'txBytes': txBytes,
        'timestamp': (timestamp ?? DateTime.now()).toIso8601String(),
      };

  TrafficSnapshot operator +(TrafficSnapshot other) => TrafficSnapshot(
        rxBytes: rxBytes + other.rxBytes,
        txBytes: txBytes + other.txBytes,
        timestamp: other.timestamp,
      );
}

/// Пара «скорость вниз/вверх» для графика.
class SpeedPoint {
  const SpeedPoint({required this.downBps, required this.upBps, required this.at});

  final double downBps;
  final double upBps;
  final DateTime at;
}
