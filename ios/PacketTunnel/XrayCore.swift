import Foundation

/// Тонкая обёртка над libXray (C API: CGoInvoke / CGoFree, apiVersion 3).
enum XrayCore {
  /// Invoke произвольного метода libXray.
  static func invoke(method: String,
                     payload: [String: Any] = [:]) -> [String: Any] {
    let request: [String: Any] = [
      "apiVersion": 3,
      "method": method,
      "payload": payload,
    ]
    guard let requestData = try? JSONSerialization.data(withJSONObject: request),
          let jsonString = String(data: requestData, encoding: .utf8) else {
      return ["success": false, "error": "encode failed"]
    }

    var cString = jsonString.cString(using: .utf8)
    let responsePtr: UnsafeMutablePointer<CChar>? =
      cString?.withUnsafeMutableBufferPointer { buf in
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
    return ["success": false, "error": "decode failed"]
  }

  /// Запуск Xray с JSON-конфигурацией.
  static func run(xrayJson: String, maxMemory: Int64) -> String? {
    let response = invoke(method: "runXray", payload: [
      "xrayJson": xrayJson,
      "maxMemory": maxMemory,
    ])
    if response["success"] as? Bool == true {
      return nil
    }
    return (response["error"] as? String) ?? "runXray failed"
  }

  static func stop() {
    _ = invoke(method: "stopXray")
  }

  static func version() -> String {
    let response = invoke(method: "xrayVersion")
    if let data = response["data"] as? [String: Any],
       let v = data["version"] as? String {
      return v
    }
    return "unknown"
  }
}
