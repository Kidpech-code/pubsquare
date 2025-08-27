import Flutter
import UIKit

public class CapsafePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var privacyView: UIView?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let messenger = registrar.messenger()
    let instance = CapsafePlugin()

    let methodChannel = FlutterMethodChannel(name: "capsafe/methods", binaryMessenger: messenger)
    methodChannel.setMethodCallHandler(instance.handle)

    let eventChannel = FlutterEventChannel(name: "capsafe/events", binaryMessenger: messenger)
    eventChannel.setStreamHandler(instance)

    NotificationCenter.default.addObserver(instance, selector: #selector(screenCapturedDidChange), name: UIScreen.capturedDidChangeNotification, object: nil)
    NotificationCenter.default.addObserver(instance, selector: #selector(userDidTakeScreenshot), name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "ios.setPrivacySnapshot":
      guard let enable = call.arguments as? Bool else { result(nil); return }
      if enable { installPrivacySnapshot() } else { uninstallPrivacySnapshot() }
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func screenCapturedDidChange() {
    let captured = UIScreen.main.isCaptured
    eventSink?(["type": "captured", "value": captured])
  }

  @objc private func userDidTakeScreenshot() {
    eventSink?(["type": "screenshot"])
  }

  // App Switcher snapshot privacy: add/remove black overlay when app resigns.
  private func installPrivacySnapshot() {
    NotificationCenter.default.addObserver(self, selector: #selector(willResignActive), name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.addObserver(self, selector: #selector(didBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
  }

  private func uninstallPrivacySnapshot() {
    NotificationCenter.default.removeObserver(self, name: UIApplication.willResignActiveNotification, object: nil)
    NotificationCenter.default.removeObserver(self, name: UIApplication.didBecomeActiveNotification, object: nil)
    removePrivacyOverlay()
  }

  @objc private func willResignActive() {
    addPrivacyOverlay()
  }

  @objc private func didBecomeActive() {
    removePrivacyOverlay()
  }

  private func addPrivacyOverlay() {
    guard let window = UIApplication.shared.connectedScenes
        .compactMap({ $0 as? UIWindowScene })
        .flatMap({ $0.windows })
        .first(where: { $0.isKeyWindow }) else { return }

    if privacyView == nil {
      let v = UIView(frame: window.bounds)
      v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
      v.backgroundColor = .black
      v.isUserInteractionEnabled = false
      privacyView = v
    }
    if let v = privacyView, v.superview == nil {
      window.addSubview(v)
    }
  }

  private func removePrivacyOverlay() {
    privacyView?.removeFromSuperview()
  }

  // FlutterStreamHandler
  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    events(["type": "captured", "value": UIScreen.main.isCaptured])
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }
}
