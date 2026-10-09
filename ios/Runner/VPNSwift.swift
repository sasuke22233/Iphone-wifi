import Flutter
import Foundation
import NetworkExtension

/// Управляет VPN-профилем (NETunnelProviderManager) и отвечает
/// на вызовы MethodChannel из Flutter.
@objc class VPNManager: NSObject, FlutterStreamHandler {
  @objc static let shared = VPNManager()

  private var manager: NETunnelProviderManager?
  private var eventSink: FlutterEventSink?
  private var statusObserver: NSObjectProtocol?

  private let queue = DispatchQueue(label: "com.auravpn.app.vpn")

  // ------------------------------------------------------------- attach

  @objc func attach(methodChannel: FlutterMethodChannel,
                    eventChannel: FlutterEventChannel) {
    methodChannel.setMethodCallHandler { [weak self] call, result in
      self?.handle(call, result: result)
    }
    eventChannel.setStreamHandler(self)

    statusObserver = NotificationCenter.default.addObserver(
      forName: .NEVPNStatusDidChange,
      object: nil,
      queue: .main
    ) { [weak self] _ in
      self?.emitStatus()
    }

    loadManager { _ in }
  }

  // ------------------------------------------------------- method calls

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "prepare":
      loadManager { manager in
        if manager != nil {
          result(true)
        } else {
          self.createManager { created in
            result(created != nil)
          }
        }
      }

    case "connect":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "args", message: "missing args", details: nil))
        return
      }
      startTunnel(args: args, result: result)

    case "disconnect":
      manager?.connection.stopVPNTunnel()
      result(true)

    case "status":
      result(currentStatusRaw())

    case "stats":
      result(readStats())

    case "logs":
      let tail = (call.arguments as? [String: Any])?["tail"] as? Int ?? 200
      result(readLogs(tail: tail))

    case "clearLogs":
      SharedConstants.clearLogs()
      result(true)

    case "coreVersion":
      result(XrayNative.xrayVersion())

    case "parseLinks":
      let text = (call.arguments as? [String: Any])?["text"] as? String ?? ""
      result(XrayNative.convertLinks(text))

    case "isShareActive":
      if currentStatusRaw() == 3 {
        let cfg = manager?.protocolConfiguration as? NETunnelProviderProtocol
        result(cfg?.providerConfiguration?["shareProxy"] as? Bool ?? false)
      } else {
        result(false)
      }

    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // ------------------------------------------------------------- status

  private func currentStatusRaw() -> Int {
    let status = manager?.connection.status ?? .invalid
    switch status {
    case .disconnected: return 1
    case .connecting: return 2
    case .connected: return 3
    case .reasserting: return 4
    case .disconnecting: return 5
    case .invalid: return 0
    @unknown default: return 0
    }
  }

  private func emitStatus() {
    eventSink?(currentStatusRaw())
  }

  // ------------------------------------------------------ manager logic

  private func loadManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
      let existing = managers?.first {
        ($0.protocolConfiguration as? NETunnelProviderProtocol)?
          .providerBundleIdentifier == SharedConstants.tunnelBundleId
      }
      self?.manager = existing
      completion(existing)
    }
  }

  private func createManager(completion: @escaping (NETunnelProviderManager?) -> Void) {
    let manager = NETunnelProviderManager()
    let proto = NETunnelProviderProtocol()
    proto.providerBundleIdentifier = SharedConstants.tunnelBundleId
    proto.serverAddress = "Aura VPN"
    manager.protocolConfiguration = proto
    manager.localizedDescription = "Aura VPN"
    manager.isEnabled = true
    manager.saveToPreferences { [weak self] error in
      if error == nil {
        self?.manager = manager
      }
      completion(error == nil ? manager : nil)
    }
  }

  private func startTunnel(args: [String: Any],
                           result: @escaping FlutterResult) {
    loadManager { manager in
      let apply: (NETunnelProviderManager) -> Void = { manager in
        guard let proto =
            manager.protocolConfiguration as? NETunnelProviderProtocol else {
          result(FlutterError(code: "config", message: "bad protocol", details: nil))
          return
        }
        proto.providerBundleIdentifier = SharedConstants.tunnelBundleId
        proto.serverAddress = (args["serverAddress"] as? String) ?? "Aura VPN"
        // Провайдер-конфигурация: только plist-совместимые значения.
        var cfg: [String: Any] = [:]
        for (key, value) in args {
          if value is String || value is NSNumber || value is Bool {
            cfg[key] = value
          } else if let list = value as? [Any] {
            cfg[key] = list.compactMap { $0 as? String }
          }
        }
        proto.providerConfiguration = cfg

        // Захват всего трафика (для раздачи через Personal Hotspot).
        if #available(iOS 14.0, *) {
          proto.includeAllNetworks = (args["includeAllNetworks"] as? Bool) ?? true
          proto.excludeLocalNetworks =
            (args["excludeLocalNetworks"] as? Bool) ?? true
        }
        if #available(iOS 15.2, *) {
          proto.enforceRoutes = true
        }

        manager.isEnabled = true
        manager.saveToPreferences { error in
          if let error = error {
            result(FlutterError(
              code: "save",
              message: error.localizedDescription,
              details: nil
            ))
            return
          }
          manager.loadFromPreferences { error in
            if let error = error {
              result(FlutterError(
                code: "load",
                message: error.localizedDescription,
                details: nil
              ))
              return
            }
            do {
              try manager.connection.startVPNTunnel()
              result(true)
            } catch {
              result(FlutterError(
                code: "start",
                message: error.localizedDescription,
                details: nil
              ))
            }
          }
        }
      }

      if let manager = manager {
        apply(manager)
      } else {
        self.createManager { created in
          if let created = created {
            apply(created)
          } else {
            result(FlutterError(
              code: "manager",
              message: "cannot create VPN manager",
              details: nil
            ))
          }
        }
      }
    }
  }

  // -------------------------------------------------------------- stats

  private func readStats() -> [String: Any] {
    guard let url = SharedConstants.fileURL(SharedConstants.statsFile),
          let data = try? Data(contentsOf: url),
          let obj = try? JSONSerialization.jsonObject(with: data)
              as? [String: Any] else {
      return [
        "rxBytes": 0,
        "txBytes": 0,
        "timestamp": ISO8601DateFormatter().string(from: Date()),
      ]
    }
    return obj
  }

  private func readLogs(tail: Int) -> String {
    let parts = [
      SharedConstants.tail(SharedConstants.tunnelLogFile, maxLines: tail),
      SharedConstants.tail(SharedConstants.errorLogFile, maxLines: tail),
      SharedConstants.tail(SharedConstants.accessLogFile, maxLines: tail),
    ]
    return parts.filter { !$0.isEmpty }.joined(separator: "\n")
  }

  // ------------------------------------------------------- event stream

  func onListen(withArguments arguments: Any?,
                eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    emitStatus()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

// MARK: - LibXray (приложение: версия ядра, разбор ссылок)

@objc class XrayNative: NSObject {
  /// Вызов libXray Invoke (apiVersion 3).
  static func invoke(_ request: [String: Any]) -> [String: Any] {
    guard let requestData = try? JSONSerialization.data(withJSONObject: request),
          var cString = String(data: requestData, encoding: .utf8)?.cString(using: .utf8)
    else {
      return ["success": false, "error": "bad request"]
    }

    let responsePtr: UnsafeMutablePointer<CChar>? = cString.withUnsafeMutableBufferPointer {
      buf in
      CGoInvoke(buf.baseAddress)
    }

    guard let responsePtr = responsePtr else {
      return ["success": false, "error": "nil response"]
    }
    defer { CGoFree(responsePtr) }

    let response = String(cString: responsePtr)
    if let data = response.data(using: .utf8),
       let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
      return obj
    }
    return ["success": false, "error": "bad response"]
  }

  @objc static func xrayVersion() -> String {
    let response = invoke([
      "apiVersion": 3,
      "method": "xrayVersion",
      "payload": [String: String](),
    ])
    if let data = response["data"] as? [String: Any],
       let version = data["version"] as? String {
      return version
    }
    return "—"
  }

  @objc static func convertLinks(_ text: String) -> String {
    let response = invoke([
      "apiVersion": 3,
      "method": "convertShareLinksToXrayJson",
      "payload": ["text": text],
    ])
    guard response["success"] as? Bool == true,
          let data = response["data"] as? [String: Any],
          let outbounds = data["outbounds"] as? [[String: Any]] else {
      return "[]"
    }
    if let encoded = try? JSONSerialization.data(withJSONObject: outbounds),
       let json = String(data: encoded, encoding: .utf8) {
      return json
    }
    return "[]"
  }
}
