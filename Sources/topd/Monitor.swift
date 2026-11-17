import Foundation
import Observation
import TopdCore

/// Samples on a background queue and publishes results on the main queue.
/// Sampling is paused while the popover is closed; the menu bar keeps a slow 2s cadence.
private final class SamplingEngine {
    private let queue = DispatchQueue(label: "topd.sampling", qos: .utility)
    private let system = SystemSampler()
    private let processes = ProcessSampler()
    private let deliver: (SystemSnapshot, [ProcessRow]?) -> Void
    private var timer: DispatchSourceTimer?
    private var interval: TimeInterval = 2
    private var includesProcesses = false

    init(deliver: @escaping (SystemSnapshot, [ProcessRow]?) -> Void) {
        self.deliver = deliver
    }

    func start() {
        queue.async { self.schedule() }
    }

    func configure(interval: TimeInterval, includesProcesses: Bool) {
        queue.async {
            if includesProcesses && !self.includesProcesses { self.processes.reset() }
            self.includesProcesses = includesProcesses
            self.interval = interval
            self.schedule()
        }
    }

    private func schedule() {
        timer?.cancel()
        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(200))
        source.setEventHandler { [weak self] in self?.tick() }
        source.resume()
        timer = source
    }

    private func tick() {
        let snapshot = system.sample()
        let rows = includesProcesses ? processes.sample() : nil
        deliver(snapshot, rows)
    }
}

@Observable
final class Monitor {
    static let historyLength = 60

    private(set) var snapshot = SystemSnapshot()
    private(set) var processes: [ProcessRow] = []
    private(set) var cpuHistory = History(capacity: Monitor.historyLength)
    private(set) var gpuHistory = History(capacity: Monitor.historyLength)
    private(set) var downloadHistory = History(capacity: Monitor.historyLength)
    private(set) var uploadHistory = History(capacity: Monitor.historyLength)

    /// Called on the main queue after each update. The status item uses it to refresh the glance strip.
    @ObservationIgnored var onUpdate: (() -> Void)?
    @ObservationIgnored private var engine: SamplingEngine?

    func start() {
        let engine = SamplingEngine { [weak self] snapshot, rows in
            DispatchQueue.main.async { self?.apply(snapshot, rows) }
        }
        self.engine = engine
        engine.start()
    }

    func setPopoverVisible(_ visible: Bool) {
        engine?.configure(interval: visible ? 1 : 2, includesProcesses: visible)
    }

    private func apply(_ latest: SystemSnapshot, _ rows: [ProcessRow]?) {
        snapshot = latest
        cpuHistory.append(latest.cpuTotal)
        if let gpu = latest.gpuPercent { gpuHistory.append(gpu) }
        downloadHistory.append(latest.network.downloadBytesPerSecond)
        uploadHistory.append(latest.network.uploadBytesPerSecond)
        if let rows { processes = rows }
        onUpdate?()
    }
}
