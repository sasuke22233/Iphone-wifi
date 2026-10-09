import Foundation
import NetworkExtension

/// Packet Tunnel Network Extension:
///   пакеты utun ⇄ socketpair ⇄ hev-socks5-tunnel ⇄ SOCKS5 ⇄ Xray-core ⇄ VPN-сервер.
class PacketTunnelProvider: NEPacketTunnelProvider {

  private var packetFd: Int32 = -1
  private var tunFd: Int32 = -1
  private var statsTimer: DispatchSourceTimer?
  private let workQueue = DispatchQueue(label: "com.auravpn.app.tunnel")
  private var started = false

  // MARK: - Lifecycle

  override func startTunnel(
    options: [String: NSObject]?,
    completionHandler: @escaping (Error?) -> Void
  ) {
    SharedConstants.appendTunnelLog("startTunnel")

    guard let cfg = protocolConfiguration as? NETunnelProviderProtocol,
          let config = cfg.providerConfiguration else {
      SharedConstants.appendTunnelLog("error: missing providerConfiguration")
      completionHandler(TunnelError.badConfig)
      return
    }

    func cfgStr(_ key: String, _ fallback: String = "") -> String {
      return config[key] as? String ?? fallback
    }
    func cfgInt(_ key: String, _ fallback: Int) -> Int {
      return (config[key] as? NSNumber)?.intValue ?? fallback
    }

    let xrayJsonRaw = cfgStr("xrayJson")
    let hevYaml = cfgStr("hevYaml")
    let serverAddress = cfgStr("serverAddress", "127.0.0.1")
    let mtu = cfgInt("mtu", 1500)
    let shareProxy = (config["shareProxy"] as? Bool) ?? false
    let dnsServers = (config["dnsServers"] as? [String]) ?? ["1.1.1.1"]

    guard !xrayJsonRaw.isEmpty, !hevYaml.isEmpty else {
      completionHandler(TunnelError.badConfig)
      return
    }

    // Подставляем реальный путь общего контейнера в конфиг логов.
    let containerPath =
      SharedConstants.containerURL()?.path ?? NSTemporaryDirectory()
    let xrayJson = xrayJsonRaw.replacingOccurrences(
      of: "__APP_GROUP__", with: containerPath)

    // Исключаем адрес сервера из туннеля (защита от петли) и,
    // при необходимости, локальные сети.
    var excludedRoutes = [NEIPv4Route]()
    let serverIps = resolve(host: serverAddress)
    for ip in serverIps {
      excludedRoutes.append(
        NEIPv4Route(destinationAddress: ip, subnetMask: "255.255.255.255"))
    }
    let excludeLocal = (config["excludeLocalNetworks"] as? Bool) ?? true
    if excludeLocal {
      for (net, mask) in Self.localNetworks {
        excludedRoutes.append(
          NEIPv4Route(destinationAddress: net, subnetMask: mask))
      }
    }

    let settings = Self.makeSettings(
      mtu: mtu,
      dnsServers: dnsServers,
      excludedRoutes: excludedRoutes
    )

    setTunnelNetworkSettings(settings) { [weak self] error in
      guard let self = self else { return }
      if let error = error {
        SharedConstants.appendTunnelLog("settings error: \(error)")
        completionHandler(error)
        return
      }
      self.workQueue.async {
        self.launchCore(
          xrayJson: xrayJson,
          hevYaml: hevYaml,
          shareProxy: shareProxy,
          completionHandler: completionHandler
        )
      }
    }
  }

  override func stopTunnel(
    with reason: NEProviderStopReason,
    completionHandler: @escaping () -> Void
  ) {
    SharedConstants.appendTunnelLog("stopTunnel reason=\(reason.rawValue)")
    started = false
    statsTimer?.cancel()
    statsTimer = nil

    HevTunnel.quit()
    XrayCore.stop()

    if tunFd >= 0 { close(tunFd); tunFd = -1 }
    if packetFd >= 0 { close(packetFd); packetFd = -1 }

    SharedConstants.appendTunnelLog("stopped")
    completionHandler()
  }

  // MARK: - Core startup

  private func launchCore(
    xrayJson: String,
    hevYaml: String,
    shareProxy: Bool,
    completionHandler: @escaping (Error?) -> Void
  ) {
    // 1. Запускаем Xray-core (SOCKS-инбаунд на 127.0.0.1 или 0.0.0.0).
    let maxMemory = Int64(64 * 1024 * 1024)
    if let error = XrayCore.run(xrayJson: xrayJson, maxMemory: maxMemory) {
      SharedConstants.appendTunnelLog("xray error: \(error)")
      completionHandler(TunnelError.coreFailed(error))
      return
    }
    SharedConstants.appendTunnelLog(
      "xray started, version=\(XrayCore.version())")

    // 2. socketpair: одна сторона — «tun fd» для hev, вторая — мост к packetFlow.
    var fds: [Int32] = [0, 0]
    if socketpair(AF_UNIX, SOCK_DGRAM, 0, &fds) != 0 {
      XrayCore.stop()
      completionHandler(TunnelError.socketPair)
      return
    }
    packetFd = fds[0]
    tunFd = fds[1]

    // 3. Мост packetFlow ⇄ socketpair.
    startPacketBridge()

    // 4. hev-socks5-tunnel (блокирующий вызов — в фоне).
    let hevTunFd = self.tunFd
    workQueue.async {
      let rc = HevTunnel.run(configYaml: hevYaml, tunFd: hevTunFd)
      SharedConstants.appendTunnelLog("hev exited rc=\(rc)")
    }

    started = true
    startStatsTimer()
    SharedConstants.appendTunnelLog("tunnel ready (shareProxy=\(shareProxy))")
    completionHandler(nil)
  }

  // MARK: - packetFlow bridge

  private func startPacketBridge() {
    let fd = packetFd

    // utun → socketpair → hev
    func pumpRead() {
      packetFlow.readPackets { [weak self] packets, _ in
        guard let self = self, self.started else { return }
        for packet in packets {
          packet.withUnsafeBytes { buf in
            if let base = buf.baseAddress {
              _ = write(fd, base, buf.count)
            }
          }
        }
        pumpRead()
      }
    }
    pumpRead()

    // hev → socketpair → utun
    workQueue.async { [weak self] in
      var buffer = [UInt8](repeating: 0, count: 65536)
      while true {
        let n = read(fd, &buffer, buffer.count)
        if n <= 0 {
          if self?.started != true { break }
          usleep(1000)
          continue
        }
        let data = Data(buffer[0..<n])
        let version = buffer[0] >> 4
        let proto: NSNumber =
          version == 6 ? NSNumber(value: AF_INET6) : NSNumber(value: AF_INET)
        self?.packetFlow.writePackets([data], withProtocols: [proto])
      }
    }
  }

  // MARK: - Stats

  private func startStatsTimer() {
    let timer = DispatchSource.makeTimerSource(queue: workQueue)
    timer.schedule(deadline: .now() + 1, repeating: 1)
    timer.setEventHandler { [weak self] in
      self?.writeStats()
    }
    timer.resume()
    statsTimer = timer
  }

  private func writeStats() {
    let (_, txBytes, _, rxBytes) = HevTunnel.stats()
    let payload: [String: Any] = [
      // hev: tx — в сторону интернета (upload), rx — к устройству (download).
      "rxBytes": UInt64(rxBytes),
      "txBytes": UInt64(txBytes),
      "timestamp": ISO8601DateFormatter().string(from: Date()),
      "shareProxy": (protocolConfiguration as? NETunnelProviderProtocol)?
        .providerConfiguration?["shareProxy"] as? Bool ?? false,
    ]
    guard let url = SharedConstants.fileURL(SharedConstants.statsFile),
          let data = try? JSONSerialization.data(withJSONObject: payload) else {
      return
    }
    try? data.write(to: url)
  }

  // MARK: - Network settings

  private static func makeSettings(
    mtu: Int,
    dnsServers: [String],
    excludedRoutes: [NEIPv4Route]
  ) -> NEPacketTunnelNetworkSettings {
    let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.1")
    settings.mtu = NSNumber(value: mtu)

    let ipv4 = NEIPv4Settings(
      addresses: ["198.18.0.2"],
      subnetMasks: ["255.255.255.0"]
    )
    ipv4.includedRoutes = [NEIPv4Route.default()]
    ipv4.excludedRoutes = excludedRoutes
    settings.ipv4Settings = ipv4

    let ipv6 = NEIPv6Settings(addresses: ["fc00::2"], networkPrefixLengths: [64])
    ipv6.includedRoutes = [NEIPv6Route.default()]
    settings.ipv6Settings = ipv6

    settings.dnsSettings = NEDNSSettings(servers: dnsServers)
    settings.dnsSettings?.matchDomains = [""]  // весь DNS через туннель
    return settings
  }

  private static let localNetworks: [(String, String)] = [
    ("10.0.0.0", "255.0.0.0"),
    ("172.16.0.0", "255.240.0.0"),
    ("192.168.0.0", "255.255.0.0"),
    ("169.254.0.0", "255.255.0.0"),
    ("127.0.0.0", "255.0.0.0"),
    ("224.0.0.0", "240.0.0.0"),
  ]

  // MARK: - DNS resolve (для исключения адреса сервера)

  private func resolve(host: String) -> [String] {
    if isIpAddress(host) { return [host] }
    var result = [String]()
    var hints = addrinfo(
      ai_flags: AI_ADDRCONFIG,
      ai_family: AF_UNSPEC,
      ai_socktype: SOCK_STREAM,
      ai_protocol: 0,
      ai_addrlen: 0,
      ai_canonname: nil,
      ai_addr: nil,
      ai_next: nil
    )
    var info: UnsafeMutablePointer<addrinfo>?
    if getaddrinfo(host, nil, &hints, &info) == 0, let first = info {
      var ptr: UnsafeMutablePointer<addrinfo>? = first
      while let current = ptr {
        var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        if getnameinfo(
          current.pointee.ai_addr,
          current.pointee.ai_addrlen,
          &hostname,
          socklen_t(hostname.count),
          nil,
          0,
          NI_NUMERICHOST
        ) == 0 {
          result.append(String(cString: hostname))
        }
        ptr = current.pointee.ai_next
      }
      freeaddrinfo(first)
    }
    return result
  }

  private func isIpAddress(_ value: String) -> Bool {
    var addr = in_addr()
    if inet_pton(AF_INET, value, &addr) == 1 { return true }
    var addr6 = in6_addr()
    return inet_pton(AF_INET6, value, &addr6) == 1
  }
}

// MARK: - Errors

enum TunnelError: LocalizedError {
  case badConfig
  case socketPair
  case coreFailed(String)

  var errorDescription: String? {
    switch self {
    case .badConfig: return "Missing tunnel configuration"
    case .socketPair: return "Cannot create socketpair"
    case .coreFailed(let message): return "Xray core failed: \(message)"
    }
  }
}
