import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow {
  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)

    // Avoid initial white flash before Flutter paints its first frame.
    self.isOpaque = true
    self.backgroundColor = NSColor(calibratedRed: 0.0588, green: 0.0902, blue: 0.1882, alpha: 1.0)

    RegisterGeneratedPlugins(registry: flutterViewController)

    super.awakeFromNib()
  }
}
