import Darwin
import Foundation
import TopdCore

// Minimal check runner. Exits 1 if any check fails, so it can gate a release script.

var failures: [String] = []
var passed = 0

func check(_ name: String, _ condition: @autoclosure () -> Bool) {
    if condition() {
        passed += 1
    } else {
        failures.append(name)
        print("FAIL  \(name)")
    }
}

// MARK: System sampling math

// CPU_STATE order: user, system, idle, nice
check("busy share of ticks since last reading",
      SystemSampler.utilization(previous: [[100, 0, 100, 0]], current: [[150, 50, 200, 0]]) == [50])

let wrapped = SystemSampler.utilization(previous: [[UInt32.max - 10, 0, 0, 0]], current: [[10, 0, 30, 0]])[0]
check("counter wraparound gives the correct share", abs(wrapped - 21.0 / 51.0 * 100) < 0.0001)

check("flat ticks report zero",
      SystemSampler.utilization(previous: [[5, 5, 5, 5]], current: [[5, 5, 5, 5]]) == [0])

check("core-count change resets to zeros",
      SystemSampler.utilization(previous: [[1, 1, 1, 1]], current: [[2, 2, 2, 2], [3, 3, 3, 3]]) == [0, 0])

check("counter delta: normal", SystemSampler.counterDelta(500, 200) == 300)
check("counter delta: wraparound", SystemSampler.counterDelta(10, UInt32.max - 4) == 15)
// A reset from a small value wraps to a delta above 2^31, which counts as zero. A reset from a large value is
// indistinguishable from a real ~1.3 GB transfer in one interval, so that case is not claimed.
check("counter delta: reset from a small value treated as zero", SystemSampler.counterDelta(0, 100_000_000) == 0)

let firstSample = SystemSampler().sample()
check("first sample has zero network rate", firstSample.network.downloadBytesPerSecond == 0)
check("reports core count", firstSample.coreCount > 0 && firstSample.cpuPerCore.count == firstSample.coreCount)
check("memory total positive and used <= total", firstSample.memory.total > 0 && firstSample.memory.used <= firstSample.memory.total)
check("storage total positive", firstSample.storage.total > 0)
check("uptime and three load averages", firstSample.uptime > 0 && firstSample.loadAverage.count == 3)

// MARK: Process sampling (live)

let processSampler = ProcessSampler()
_ = processSampler.sample()
let mine = processSampler.sample().first { $0.pid == getpid() }
check("process sampling includes this process", mine != nil)
check("this process reports resident memory", (mine?.memoryBytes ?? 0) > 0)

// MARK: Process ranking

let rows = [
    ProcessRow(pid: 30, name: "Safari", cpuPercent: 12.5, memoryBytes: 900),
    ProcessRow(pid: 10, name: "kernel_task", cpuPercent: 40, memoryBytes: 100),
    ProcessRow(pid: 20, name: "Xcode", cpuPercent: 12.5, memoryBytes: 1_500),
    ProcessRow(pid: 40, name: "Finder", cpuPercent: 0.1, memoryBytes: 50),
]

check("top by CPU descending, lower PID wins ties",
      ProcessRanking.topByCPU(rows, count: 3).map(\.pid) == [10, 20, 30])
check("top by memory", ProcessRanking.topByMemory(rows, count: 2).map(\.pid) == [20, 30])
check("top is capped at available rows", ProcessRanking.topByCPU(rows).count == 4)
check("search matches name case-insensitively", ProcessRanking.filter(rows, query: "xcO").map(\.pid) == [20])
check("search matches PID digits", ProcessRanking.filter(rows, query: " 40 ").map(\.pid) == [40])
check("empty search keeps everything", ProcessRanking.filter(rows, query: "").count == 4)
check("no-match search is empty", ProcessRanking.filter(rows, query: "nothing").isEmpty)
check("name sort", ProcessRanking.sorted(rows, by: .name).map(\.name) == ["Finder", "kernel_task", "Safari", "Xcode"])
check("PID sort", ProcessRanking.sorted(rows, by: .pid).map(\.pid) == [10, 20, 30, 40])
check("memory sort puts largest first", ProcessRanking.sorted(rows, by: .memory).first?.pid == 20)

// MARK: History

var history = History(capacity: 3)
for value in [1.0, 2.0, 3.0, 4.0, 5.0] { history.append(value) }
check("history keeps the most recent samples", history.values == [3, 4, 5])

// MARK: Preferences rules

let defaults = Preferences()
check("defaults: all cards and sections on", defaults.cards == Set(Card.allCases) && defaults.sections == Set(ProcessSection.allCases))
check("defaults: at-a-glance OFF", defaults.glanceEnabled == false)
check("defaults: glance choice is CPU, GPU, memory", defaults.glance == [.cpu, .gpu, .memory])
check("defaults: menu bar icon is the topd logo", defaults.menuIcon == .topd)
check("menu icon choices: default plus four others", MenuIcon.allCases.count == 5)

var glanceSwitch = Preferences()
glanceSwitch.setGlanceEnabled(true)
check("at-a-glance switch turns on", glanceSwitch.glanceEnabled)
glanceSwitch.setMenuIcon(.waveform)
check("menu icon change applies", glanceSwitch.menuIcon == .waveform)

var lastCard = Preferences(cards: [.cpu], glance: [.cpu])
check("at least one card stays ON", lastCard.setCard(.cpu, enabled: false) == false && lastCard.cards == [.cpu])

var glanceOff = Preferences(cards: [.cpu, .gpu], glance: [.gpu])
check("turning off a glance card refills the strip",
      glanceOff.setCard(.gpu, enabled: false) && glanceOff.glance == [.cpu])

var limits = Preferences(glance: [.cpu, .memory, .network])
check("fourth glance card refused", limits.toggleGlance(.gpu) == false)
check("glance card removable above minimum", limits.toggleGlance(.memory) && limits.glance == [.cpu, .network])
check("re-add up to three", limits.toggleGlance(.memory) && limits.glance.count == 3)
var single = Preferences(glance: [.cpu])
check("last glance card cannot be removed", single.toggleGlance(.cpu) == false && single.glance == [.cpu])

var offCard = Preferences(cards: [.cpu], glance: [.cpu])
check("glance card must be ON", offCard.toggleGlance(.gpu) == false)

check("bad glance input normalized", Preferences(cards: [.cpu], glance: [.gpu, .cpu, .cpu, .memory]).glance == [.cpu])
check("empty cards normalized to all", Preferences(cards: [], glance: []).cards == Set(Card.allCases))
check("empty glance normalized to first ON card", Preferences(cards: [.memory], glance: []).glance == [.memory])

let suite = UserDefaults(suiteName: "topd.checks.\(UUID().uuidString)")!
var saved = Preferences(cards: [.cpu, .system], sections: [.topMemory], glance: [.system], glanceEnabled: true, menuIcon: .chip)
saved.toggleGlance(.cpu)
saved.save(to: suite)
check("preferences round-trip through UserDefaults", Preferences(defaults: suite) == saved)

// MARK: Card order

var ordered = Preferences()
check("default card order is the enum order", ordered.cardOrder == Card.allCases)
check("moving the first card up is refused", ordered.moveCard(.cpu, by: -1) == false)
check("moving the last card down is refused", ordered.moveCard(.network, by: 1) == false)
check("moving CPU down swaps it with Memory", ordered.moveCard(.cpu, by: 1) && ordered.cardOrder.prefix(2) == [.memory, .cpu])
var hidden = Preferences(cards: [.cpu, .memory, .gpu], glance: [.cpu])
hidden.moveCard(.gpu, by: -2)
check("ordered cards follow the saved order and skip OFF cards", hidden.orderedCards == [.gpu, .cpu, .memory])
check("a short saved order is completed", Preferences(cardOrder: [.gpu]).cardOrder.first == .gpu && Preferences(cardOrder: [.gpu]).cardOrder.count == 6)
check("a duplicated saved order is de-duplicated", Preferences(cardOrder: [.gpu, .gpu]).cardOrder.count == 6)
let orderSuite = UserDefaults(suiteName: "topd.checks.order.\(UUID().uuidString)")!
var reordered = Preferences()
reordered.moveCard(.network, by: -3)
reordered.save(to: orderSuite)
check("card order persists", Preferences(defaults: orderSuite).cardOrder == reordered.cardOrder)

// MARK: Icon dropdown labels are lowercase alphanumeric

// Only the icon dropdown labels are constrained: lowercase letters and digits.
for icon in MenuIcon.allCases {
    let label = icon.title
    check("icon dropdown label is lowercase alphanumeric: \(label)", !label.isEmpty && label.allSatisfy { ($0.isLetter && $0.isLowercase) || $0.isNumber })
}

// MARK: Theme

check("theme defaults to the translucent default", Preferences().theme == .glass)
check("there are twelve themes", AppTheme.allCases.count == 12)
check("theme raw values are unique", Set(AppTheme.allCases.map(\.rawValue)).count == 12)
var themed = Preferences()
themed.setTheme(.nord)
let themeSuite = UserDefaults(suiteName: "topd.checks.theme.\(UUID().uuidString)")!
themed.save(to: themeSuite)
check("theme persists", Preferences(defaults: themeSuite).theme == .nord)
check("unknown saved theme falls back to default", { () -> Bool in
    themeSuite.set("not-a-theme", forKey: "topd.theme")
    return Preferences(defaults: themeSuite).theme == .glass
}())

// MARK: System theme

var systemPref = Preferences(theme: .system)
check("system follows the dark choice in dark mode", systemPref.resolvedTheme(isDark: true) == .dracula)
check("system follows the light choice in light mode", systemPref.resolvedTheme(isDark: false) == .gitHubLight)
check("system dark choice rejects a light theme", systemPref.setSystemDarkTheme(.gitHubLight) == false && systemPref.systemDarkTheme == .dracula)
check("system light choice rejects a dark theme", systemPref.setSystemLightTheme(.nord) == false && systemPref.systemLightTheme == .gitHubLight)
check("system dark choice accepts a dark theme", systemPref.setSystemDarkTheme(.ocean) && systemPref.resolvedTheme(isDark: true) == .ocean)
check("a fixed theme ignores the system appearance", Preferences(theme: .nord).resolvedTheme(isDark: false) == .nord)
check("the default translucent theme ignores the system appearance", Preferences(theme: .glass).resolvedTheme(isDark: true) == .glass)
let systemSuite = UserDefaults(suiteName: "topd.checks.system.\(UUID().uuidString)")!
var savedSystem = Preferences(theme: .system)
savedSystem.setSystemDarkTheme(.slate)
savedSystem.setSystemLightTheme(.ayuLight)
savedSystem.save(to: systemSuite)
check("system choices persist", Preferences(defaults: systemSuite).systemDarkTheme == .slate && Preferences(defaults: systemSuite).systemLightTheme == .ayuLight)
check("twelve themes, with System in place of Match system", AppTheme.allCases.count == 12 && AppTheme.allCases.contains(.system))
check("dark and light choices are the right sizes", AppTheme.darkChoices.count == 7 && AppTheme.lightChoices.count == 3)
check("dark and light choices match their isDark", AppTheme.darkChoices.allSatisfy(\.isDark) && AppTheme.lightChoices.allSatisfy { !$0.isDark })

// MARK: Report

print("\(passed) passed, \(failures.count) failed")
exit(failures.isEmpty ? 0 : 1)
