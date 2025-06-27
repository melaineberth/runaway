// CornerRadiusPlugin.swift (dans Runner target)
import Flutter
import UIKit

@objc public class CornerRadiusPlugin: NSObject, FlutterPlugin {
  @objc public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(
      name: "corner_radius",
      binaryMessenger: registrar.messenger()
    )
    registrar.addMethodCallDelegate(CornerRadiusPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall,
                     result: @escaping FlutterResult) {
    if call.method == "getCornerRadius" {
      // ⚠️ API non publique – à vos risques
      if let r = UIScreen.main
              .value(forKey: "_displayCornerRadius") as? CGFloat {
        result(r)
      } else { result(0) }
    } else { result(FlutterMethodNotImplemented) }
  }
}
