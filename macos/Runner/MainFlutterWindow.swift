import Cocoa
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate  {
    override func awakeFromNib() {
        self.isOpaque = true
        self.backgroundColor = NSColor.windowBackgroundColor
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true
        self.styleMask.insert(.fullSizeContentView)
        self.hasShadow = true
        let flutterViewController = FlutterViewController()
        let windowFrame = self.frame
        self.contentViewController = flutterViewController
        self.setFrame(windowFrame, display: true)

        RegisterGeneratedPlugins(registry: flutterViewController)
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.setupStatusBarChannel(controller: flutterViewController)
        }

        super.awakeFromNib()
        self.delegate = self
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if let appDelegate = NSApp.delegate as? AppDelegate {
            appDelegate.hideMainWindow()
        } else {
            sender.orderOut(nil)
        }
        return false
    }
}
