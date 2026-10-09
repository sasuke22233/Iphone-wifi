import Foundation

/// Обёртка над hev-socks5-tunnel (tun2socks) через C-shim (HevShim.c).
enum HevTunnel {
  /// Запускает tun2socks: блокирующий вызов, выполнять в фоновом потоке.
  static func run(configYaml: String, tunFd: Int32) -> Int32 {
    var bytes = Array(configYaml.utf8)
    return bytes.withUnsafeBufferPointer { buf in
      guard let base = buf.baseAddress else { return -1 }
      return aura_hev_run(
        UnsafeRawPointer(base).assumingMemoryBound(to: UInt8.self),
        UInt32(buf.count),
        tunFd
      )
    }
  }

  static func quit() {
    aura_hev_quit()
  }

  /// (txPackets, txBytes, rxPackets, rxBytes)
  static func stats() -> (UInt64, UInt64, UInt64, UInt64) {
    var txPackets: UInt64 = 0
    var txBytes: UInt64 = 0
    var rxPackets: UInt64 = 0
    var rxBytes: UInt64 = 0
    aura_hev_stats(&txPackets, &txBytes, &rxPackets, &rxBytes)
    return (txPackets, txBytes, rxPackets, rxBytes)
  }
}
