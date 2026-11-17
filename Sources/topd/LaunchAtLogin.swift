import Foundation
import Observation
import ServiceManagement

/// Launch at login through `SMAppService.mainApp`. Registration needs topd to run as an app bundle (see run.sh and the README).
@Observable
final class LaunchAtLogin {
    enum State: Equatable {
        case enabled
        case disabled
        case requiresApproval
    }

    private(set) var state: State = .disabled
    /// Message from the last failed register or unregister call. Cleared by the next attempt.
    private(set) var lastError: String?

    private let service = SMAppService.mainApp

    init() {
        refresh()
    }

    /// Reads the live status. The user can change it in System Settings at any time, so call this whenever a menu or panel opens.
    func refresh() {
        state = State(service.status)
    }

    func setEnabled(_ enabled: Bool) {
        lastError = nil
        do {
            if enabled {
                try service.register()
            } else {
                try service.unregister()
            }
        } catch {
            lastError = error.localizedDescription
        }
        refresh()
    }

    /// The line to show under the toggle, or nil when everything is fine.
    var message: String? {
        if let lastError {
            return "Could not change launch at login: \(lastError)"
        }
        if state == .requiresApproval {
            return "Allow topd in System Settings › General › Login Items."
        }
        return nil
    }
}

private extension LaunchAtLogin.State {
    /// `.notFound` is what an unregistered app reports, so it reads as disabled. Toggling on registers it.
    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled: self = .enabled
        case .requiresApproval: self = .requiresApproval
        case .notRegistered, .notFound: self = .disabled
        @unknown default: self = .disabled
        }
    }
}
