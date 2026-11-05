import Flutter
import UIKit

/// iOS entry point. The heavy lifting happens in Dart (`YtdlpIos`) over a
/// file-based protocol; the only native duty is booting the embedded CPython
/// worker on request.
public class YtdlpFlutterPlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "ytdlp_flutter", binaryMessenger: registrar.messenger())
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
  /// `use_frameworks!` and in the main bundle under static linkage —
  /// search both.
  private func resourcePath(_ name: String, _ ext: String?) -> String? {
    return Bundle(for: YtdlpFlutterPlugin.self).path(forResource: name, ofType: ext)
      ?? Bundle.main.path(forResource: name, ofType: ext)
  }

  private func startWorker(workerDir: String, result: @escaping FlutterResult) {
    if PythonBridge.isRunning() {
      result(nil)
      return
    }
    // python-stdlib is installed into the app bundle by the
    // install_python_stdlib.sh build phase (see plugin README).
    guard let stdlib = Bundle.main.path(forResource: "python-stdlib", ofType: nil) else {
      result(FlutterError(
        code: "NO_STDLIB",
        message: "python-stdlib missing from app bundle — add the "
          + "install_python_stdlib.sh build phase (see ytdlp_flutter README)",
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
    if started {
      result(nil)
    } else {
      result(FlutterError(
        code: "PYTHON_INIT_FAILED",
        message: "Embedded CPython failed to initialize (see device logs)",
        details: nil))
    }
  }
}
