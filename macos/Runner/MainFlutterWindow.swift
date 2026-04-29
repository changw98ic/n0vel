import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  static let defaultContentSize = NSSize(width: 1440, height: 1024)
  static let minimumContentSize = NSSize(width: 1280, height: 960)

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    self.contentViewController = flutterViewController
    self.minSize = Self.minimumContentSize
    self.setContentSize(Self.defaultContentSize)
    self.center()

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
