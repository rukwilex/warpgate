import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  private var titleBarHeight: CGFloat = 40
  private var observers: [NSObjectProtocol] = []

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    titleVisibility = .hidden
    titlebarAppearsTransparent = true
    styleMask.insert(.fullSizeContentView)
    backgroundColor = .windowBackgroundColor
    flutterViewController.backgroundColor = .windowBackgroundColor

    let channel = FlutterMethodChannel(
      name: "warpgate/window",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }
      switch call.method {
      case "setTitleBarHeight":
        if let height = call.arguments as? Double {
          self.titleBarHeight = CGFloat(height)
          self.layoutTrafficLights()
        }
        result(nil)
      case "titleBarDoubleClick":
        self.performTitleBarDoubleClick()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let keychain = FlutterMethodChannel(
      name: "warpgate/keychain",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    keychain.setMethodCallHandler { call, result in
      switch call.method {
      case "accessGroup":
        result(Bundle.main.object(forInfoDictionaryKey: "KeychainAccessGroup") as? String)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let relayout: [NSNotification.Name] = [
      NSWindow.didResizeNotification,
      NSWindow.didEndLiveResizeNotification,
      NSWindow.didExitFullScreenNotification,
      NSWindow.didBecomeKeyNotification,
      NSWindow.didResignKeyNotification,
      NSWindow.didChangeBackingPropertiesNotification,
    ]
    for name in relayout {
      observers.append(
        NotificationCenter.default.addObserver(forName: name, object: self, queue: .main) {
          [weak self] _ in self?.layoutTrafficLights()
        }
      )
    }

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
    layoutTrafficLights()
  }

  deinit {
    observers.forEach(NotificationCenter.default.removeObserver)
  }

  private func layoutTrafficLights() {
    if styleMask.contains(.fullScreen) { return }
    guard
      let close = standardWindowButton(.closeButton),
      let minimize = standardWindowButton(.miniaturizeButton),
      let zoom = standardWindowButton(.zoomButton),
      let titleBar = close.superview,
      let container = titleBar.superview
    else { return }
    var containerFrame = container.frame
    containerFrame.size.height = titleBarHeight
    containerFrame.origin.y = frame.height - titleBarHeight
    container.frame = containerFrame
    let size = close.frame.height
    let margin = ((titleBarHeight - size) / 2).rounded()
    let y = titleBar.isFlipped ? margin : titleBar.bounds.height - margin - size
    let spacing = minimize.frame.minX - close.frame.minX
    for (index, button) in [close, minimize, zoom].enumerated() {
      button.setFrameOrigin(NSPoint(x: margin + CGFloat(index) * spacing, y: y))
    }
  }

  private func performTitleBarDoubleClick() {
    let defaults = UserDefaults.standard
    let action = defaults.string(forKey: "AppleActionOnDoubleClick")
      ?? (defaults.bool(forKey: "AppleMiniaturizeOnDoubleClick") ? "Minimize" : "Maximize")
    switch action {
    case "Minimize":
      miniaturize(nil)
    case "None":
      break
    default:
      zoom(nil)
    }
  }
}
