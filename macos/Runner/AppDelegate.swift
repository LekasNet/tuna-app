import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var statusItem: NSStatusItem?
  private var statusBarChannel: FlutterMethodChannel?
  private var lastTunnels: [[String: Any]] = []
  private var hasRunningTunnels = false

  override func applicationDidFinishLaunching(_ notification: Notification) {
    super.applicationDidFinishLaunching(notification)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }

  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  override func applicationShouldHandleReopen(
    _ sender: NSApplication,
    hasVisibleWindows flag: Bool
  ) -> Bool {
    showMainWindow()
    return false
  }

  func setupStatusBarChannel(controller: FlutterViewController) {
    if statusBarChannel != nil {
      return
    }

    let channel = FlutterMethodChannel(
      name: "ru.lek4s.tuna/status_bar",
      binaryMessenger: controller.engine.binaryMessenger
    )

    statusBarChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else {
        result(nil)
        return
      }

      switch call.method {
      case "initialize":
        self.ensureStatusItem()
        result(nil)
      case "updateMenu":
        self.updateMenu(arguments: call.arguments)
        result(nil)
      case "hideWindow":
        self.hideMainWindow()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func ensureStatusItem() {
    if statusItem != nil {
      rebuildStatusMenu()
      return
    }

    let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    item.button?.title = "tuna"
    statusItem = item
    rebuildStatusMenu()
  }

  private func updateMenu(arguments: Any?) {
    guard let args = arguments as? [String: Any] else {
      return
    }

    lastTunnels = args["tunnels"] as? [[String: Any]] ?? []
    hasRunningTunnels = args["hasRunningTunnels"] as? Bool ?? false
    ensureStatusItem()
  }

  private func rebuildStatusMenu() {
    let menu = NSMenu()

    if lastTunnels.isEmpty {
      let emptyItem = NSMenuItem(title: "Нет сохранённых тоннелей", action: nil, keyEquivalent: "")
      emptyItem.isEnabled = false
      menu.addItem(emptyItem)
    } else {
      for tunnel in lastTunnels {
        let id = tunnel["id"] as? String ?? ""
        let name = tunnel["name"] as? String ?? "Тоннель"
        let type = tunnel["type"] as? String ?? ""
        let port = tunnel["localPort"] as? Int ?? 0
        let running = tunnel["running"] as? Bool ?? false
        let actionTitle = running ? "Остановить" : "Запустить"
        let title = "\(actionTitle): \(name) (\(type) \(port))"
        let item = NSMenuItem(
          title: title,
          action: #selector(toggleTunnel(_:)),
          keyEquivalent: ""
        )
        item.target = self
        item.representedObject = id
        menu.addItem(item)
      }
    }

    menu.addItem(NSMenuItem.separator())

    let openItem = NSMenuItem(
      title: "Открыть программу",
      action: #selector(openProgram(_:)),
      keyEquivalent: ""
    )
    openItem.target = self
    menu.addItem(openItem)

    let stopAllItem = NSMenuItem(
      title: "Остановить все тоннели",
      action: #selector(stopAllTunnels(_:)),
      keyEquivalent: ""
    )
    stopAllItem.target = self
    stopAllItem.isEnabled = hasRunningTunnels
    menu.addItem(stopAllItem)

    statusItem?.menu = menu
  }

  @objc private func toggleTunnel(_ sender: NSMenuItem) {
    guard let id = sender.representedObject as? String else {
      return
    }

    statusBarChannel?.invokeMethod("statusBarToggleTunnel", arguments: id)
  }

  @objc private func openProgram(_ sender: NSMenuItem) {
    showMainWindow()
  }

  @objc private func stopAllTunnels(_ sender: NSMenuItem) {
    statusBarChannel?.invokeMethod("statusBarStopAll", arguments: nil)
  }

  func hideMainWindow() {
    mainFlutterWindow?.orderOut(nil)
    NSApp.setActivationPolicy(.accessory)
  }

  func showMainWindow() {
    NSApp.setActivationPolicy(.regular)
    if let window = mainFlutterWindow {
      window.makeKeyAndOrderFront(nil)
      window.orderFrontRegardless()
    }
    NSApp.activate(ignoringOtherApps: true)
  }
}
