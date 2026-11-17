import AppKit
import TopdCore

// Command-line helper for launch at login, for scripts and checks: `topd --login-item status|on|off`.
// It runs from the app bundle, because SMAppService only answers for the bundle that calls it.
if CommandLine.arguments.count >= 2, CommandLine.arguments[1] == "--login-item" {
    let launch = LaunchAtLogin()
    let action = CommandLine.arguments.count >= 3 ? CommandLine.arguments[2] : "status"
    switch action {
    case "on": launch.setEnabled(true)
    case "off": launch.setEnabled(false)
    default: break
    }
    print("state=\(launch.state) message=\(launch.message ?? "none")")
    exit(launch.lastError == nil ? 0 : 1)
}

// Menu bar only: accessory policy means no Dock icon and no app window.
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusController?
    private let monitor = Monitor()
    private let settings = SettingsModel()
    private let launch = LaunchAtLogin()

    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
        statusController = StatusController(settings: settings, monitor: monitor, launch: launch)
    }
}

let application = NSApplication.shared
let appDelegate = AppDelegate()
application.setActivationPolicy(.accessory)
application.delegate = appDelegate
application.run()
