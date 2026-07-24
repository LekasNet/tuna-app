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
    configureStatusButton(item.button)
    statusItem = item
    rebuildStatusMenu()
  }

  private func configureStatusButton(_ button: NSStatusBarButton?) {
    guard let button = button else {
      return
    }

    button.title = ""
    button.image = NSImage(named: "StatusIcon")
    button.image?.size = NSSize(width: 18, height: 18)
    button.imagePosition = .imageOnly
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
    let menu = statusItem?.menu ?? NSMenu()
    menu.removeAllItems()

    if lastTunnels.isEmpty {
      let emptyItem = NSMenuItem(title: "Нет сохранённых тоннелей", action: nil, keyEquivalent: "")
      emptyItem.isEnabled = false
      menu.addItem(emptyItem)
    } else {
      for tunnel in lastTunnels {
        menu.addItem(tunnelMenuItem(tunnel))
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

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: "Закрыть TU client",
      action: #selector(quitApplication(_:)),
      keyEquivalent: "q"
    )
    quitItem.target = self
    menu.addItem(quitItem)

    if statusItem?.menu == nil {
      statusItem?.menu = menu
    }
  }

  private func tunnelMenuItem(_ tunnel: [String: Any]) -> NSMenuItem {
    let item = NSMenuItem()
    let view = StatusTunnelMenuItemView(tunnel: tunnel, target: self)
    item.view = view
    return item
  }

  @objc fileprivate func openTunnelFromStatusButton(_ sender: NSButton) {
    guard let id = sender.identifier?.rawValue else {
      return
    }

    showMainWindow()
    statusBarChannel?.invokeMethod("statusBarOpenTunnel", arguments: id)
  }

  @objc fileprivate func toggleTunnelFromStatusButton(_ sender: NSButton) {
    guard let id = sender.identifier?.rawValue else {
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

  @objc private func quitApplication(_ sender: NSMenuItem) {
    NSApp.terminate(nil)
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

private final class StatusTunnelMenuItemView: NSView {
  private static let width: CGFloat = 300
  private static let height: CGFloat = 48

  init(tunnel: [String: Any], target: AppDelegate) {
    super.init(frame: NSRect(x: 0, y: 0, width: Self.width, height: Self.height))

    let id = tunnel["id"] as? String ?? ""
    let name = tunnel["name"] as? String ?? "Тоннель"
    let running = tunnel["running"] as? Bool ?? false
    let status = tunnel["status"] as? String ?? ""
    let starting = status == "starting"
    let localAddress = tunnel["localAddress"] as? String ?? ""
    let publicUrl = tunnel["publicUrl"] as? String ?? ""
    let subtitle = running && !publicUrl.isEmpty ? Self.stripProtocol(publicUrl) : localAddress

    let openButton = NSButton(frame: NSRect(x: 0, y: 0, width: 246, height: Self.height))
    openButton.identifier = NSUserInterfaceItemIdentifier(id)
    openButton.target = target
    openButton.action = #selector(AppDelegate.openTunnelFromStatusButton(_:))
    openButton.isBordered = false
    openButton.bezelStyle = .regularSquare
    openButton.imagePosition = .noImage
    openButton.title = ""

    let titleLabel = NSTextField(labelWithString: name)
    titleLabel.frame = NSRect(x: 12, y: 25, width: 224, height: 17)
    titleLabel.font = NSFont.menuFont(ofSize: 13)
    titleLabel.lineBreakMode = .byTruncatingTail

    let subtitleLabel = NSTextField(labelWithString: subtitle)
    subtitleLabel.frame = NSRect(x: 12, y: 8, width: 224, height: 15)
    subtitleLabel.font = NSFont.menuFont(ofSize: 11)
    subtitleLabel.textColor = running && !publicUrl.isEmpty
      ? NSColor.linkColor
      : NSColor.secondaryLabelColor
    subtitleLabel.lineBreakMode = NSLineBreakMode.byTruncatingMiddle

    openButton.addSubview(titleLabel)
    openButton.addSubview(subtitleLabel)
    addSubview(openButton)

    if starting {
      let progress = NSProgressIndicator(frame: NSRect(x: 263, y: 14, width: 18, height: 18))
      progress.style = .spinning
      progress.controlSize = .small
      progress.isIndeterminate = true
      progress.startAnimation(nil)
      addSubview(progress)
    } else {
      let actionButton = NSButton(frame: NSRect(x: 254, y: 9, width: 36, height: 30))
      actionButton.identifier = NSUserInterfaceItemIdentifier(id)
      actionButton.target = target
      actionButton.action = #selector(AppDelegate.toggleTunnelFromStatusButton(_:))
      actionButton.isBordered = false
      actionButton.bezelStyle = .regularSquare
      actionButton.title = running ? "■" : "▶"
      actionButton.toolTip = running ? "Остановить" : "Запустить"
      actionButton.font = NSFont.systemFont(ofSize: running ? 15 : 18, weight: .semibold)
      addSubview(actionButton)
    }
  }

  required init?(coder: NSCoder) {
    nil
  }

  private static func stripProtocol(_ url: String) -> String {
    if url.hasPrefix("https://") {
      return String(url.dropFirst("https://".count))
    }
    if url.hasPrefix("http://") {
      return String(url.dropFirst("http://".count))
    }
    return url
  }
}
