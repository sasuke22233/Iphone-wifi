import Foundation

/// Константы, общие для приложения и Network Extension.
@objc class SharedConstants: NSObject {
  static let appGroup = "group.com.auravpn.app"
  static let tunnelBundleId = "com.auravpn.app.packet-tunnel"
  static let statsFile = "stats.json"
  static let accessLogFile = "access.log"
  static let errorLogFile = "error.log"
  static let tunnelLogFile = "tunnel.log"

  /// Каталог общего контейнера (App Group).
  @objc static func containerURL() -> URL? {
    FileManager.default
      .containerURL(forSecurityApplicationGroupIdentifier: appGroup)
  }

  @objc static func fileURL(_ name: String) -> URL? {
    containerURL()?.appendingPathComponent(name)
  }

  /// Запись строки в общий лог туннеля (с ротацией ~512 КБ).
  @objc static func appendTunnelLog(_ line: String) {
    guard let url = fileURL(tunnelLogFile) else { return }
    let stamp = ISO8601DateFormatter().string(from: Date())
    let entry = "[\(stamp)] \(line)\n"
    let fm = FileManager.default
    if !fm.fileExists(atPath: url.path) {
      try? entry.data(using: .utf8)?.write(to: url)
      return
    }
    if let handle = try? FileHandle(forWritingTo: url) {
      defer { try? handle.close() }
      try? handle.seekToEnd()
      if let data = entry.data(using: .utf8) {
        try? handle.write(contentsOf: data)
      }
    }
    // Ротация
    if let attrs = try? fm.attributesOfItem(atPath: url.path),
       let size = attrs[.size] as? Int,
       size > 512 * 1024 {
      try? fm.removeItem(at: url)
    }
  }

  /// Чтение последних строк одного файла.
  @objc static func tail(_ name: String, maxLines: Int) -> String {
    guard let url = fileURL(name),
          let data = try? Data(contentsOf: url),
          let text = String(data: data, encoding: .utf8) else {
      return ""
    }
    let lines = text.split(separator: "\n", omittingEmptySubsequences: true)
    let tail = lines.suffix(maxLines)
    return tail.joined(separator: "\n")
  }

  @objc static func clearLogs() {
    for name in [tunnelLogFile, accessLogFile, errorLogFile] {
      if let url = fileURL(name) {
        try? FileManager.default.removeItem(at: url)
      }
    }
  }
}
