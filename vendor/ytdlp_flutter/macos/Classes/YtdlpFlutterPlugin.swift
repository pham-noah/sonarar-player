import Cocoa
import FlutterMacOS

/// macOS entry point. Mirrors the iOS plugin: boots the embedded CPython
/// worker on request; everything else happens in Dart over the file-based
/// worker protocol. The vendored Python.framework is embedded in the app's
/// Frameworks directory with its stdlib inside the framework.
public class YtdlpFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ytdlp_flutter", binaryMessenger: registrar.messenger)
    let instance = YtdlpFlutterPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "startWorker":
      guard let args = call.arguments as? [String: Any],
            let workerDir = args["workerDir"] as? String else {
        result(FlutterError(
          code: "BAD_ARGS", message: "workerDir is required", details: nil))
        return
      }
      startWorker(workerDir: workerDir, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Pod resources live in the plugin's framework bundle under
  /// `use_frameworks!` and in the main bundle under static linkage.
  private func resourcePath(_ name: String, _ ext: String?) -> String? {
    return Bundle(for: YtdlpFlutterPlugin.self).path(forResource: name, ofType: ext)
      ?? Bundle.main.path(forResource: name, ofType: ext)
  }

  private func startWorker(workerDir: String, result: @escaping FlutterResult) {
    if PythonBridge.isRunning() {
      result(nil)
      return
    }
    // The stdlib lives inside the embedded Python.framework (classic macOS
    // framework build layout).
    guard let frameworks = Bundle.main.privateFrameworksPath else {
      result(FlutterError(
        code: "NO_STDLIB", message: "App has no Frameworks directory", details: nil))
      return
    }
    let stdlib = "\(frameworks)/Python.framework/Versions/3.13/lib/python3.13"
    guard FileManager.default.fileExists(atPath: stdlib) else {
      result(FlutterError(
        code: "NO_STDLIB",
        message: "Python.framework stdlib missing at \(stdlib) — "
          + "run pod install (its prepare_command fetches the framework)",
        details: nil))
      return
    }
    guard let script = resourcePath("worker", "py"),
          let pyz = resourcePath("yt-dlp", "pyz") else {
      result(FlutterError(
        code: "NO_RESOURCES",
        message: "worker.py / yt-dlp.pyz missing from app bundle "
          + "(pod install should have fetched them)",
        details: nil))
      return
    }
    let cert = resourcePath("cacert", "pem")

    let started = PythonBridge.startWorker(
      withStdlibPath: stdlib,
      scriptPath: script,
      workerDir: workerDir,
      pyzPath: pyz,
      certPath: cert)
    result(started ? nil : FlutterError(
      code: "PYTHON_INIT_FAILED",
      message: "Embedded CPython failed to initialize (see logs)",
      details: nil))
  }
}
