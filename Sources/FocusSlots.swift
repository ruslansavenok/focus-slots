import AppKit
import SwiftUI

@MainActor
final class SlotStore: ObservableObject {
    @Published private(set) var state: SlotState
    @Published private(set) var now = Date()
    @Published private(set) var justCompleted = false
    @Published private(set) var soundVolume: Double
    @Published private(set) var soundFailed = false
    var didChange: (() -> Void)?
    private var timer: Timer?
    private let sound: CompletionSoundPlaying?
    private var activity: NSObjectProtocol?
    private let defaults: UserDefaults
    // Keep the original preference keys across the Focus Slots rename.
    private let storageKey = "timeSlots.state.v1"

    init(defaults: UserDefaults = .standard, playSound: Bool = true, completionSound: CompletionSoundPlaying? = nil) {
        self.defaults = defaults
        // Apply the new 100% default once, including upgrades with a saved volume.
        // Later user adjustments must survive subsequent launches.
        if defaults.integer(forKey: "timeSlots.soundVolumeDefaultsVersion") < 2 {
            soundVolume = 1
            defaults.set(1.0, forKey: "timeSlots.soundVolume")
            defaults.set(2, forKey: "timeSlots.soundVolumeDefaultsVersion")
        } else {
            soundVolume = defaults.object(forKey: "timeSlots.soundVolume") == nil
                ? 1 : min(1, max(0.1, defaults.double(forKey: "timeSlots.soundVolume")))
        }
        sound = playSound ? (completionSound ?? CompletionSound()) : nil
        if let data = defaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode(SlotState.self, from: data) {
            state = saved
        } else {
            state = SlotState(now: Date())
        }
        refresh()
        updateActivity()
        timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        RunLoop.main.add(timer!, forMode: .common)
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(woke), name: NSWorkspace.didWakeNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(woke), name: NSNotification.Name.NSSystemTimeZoneDidChange, object: nil)
    }

    @objc private func woke() { refresh() }

    var isRunning: Bool { state.deadline != nil }
    var remaining: Int { state.remaining(at: now) }
    var progress: Double {
        guard isRunning else { return 0 }
        return min(1, max(0, 1 - Double(remaining) / (state.activeSeconds ?? Double(state.minutes * 60))))
    }

    func refresh() {
        now = Date()
        let previous = state
        let finished = state.reconcile(now: now)
        if state != previous {
            persist()
            updateActivity()
            if previous.day != state.day { justCompleted = false }
        }
        if finished {
            justCompleted = true
            previewSound()
        }
        didChange?()
    }

    func start() {
        refresh()
        guard !isRunning else { return }
        justCompleted = false
        state.start(now: now)
        persist()
        updateActivity()
        didChange?()
    }

    func stop() {
        refresh()
        guard isRunning else { return }
        state.stop()
        justCompleted = false
        persist()
        updateActivity()
        didChange?()
    }

    func saveSettings(target: Int, minutes: Int) {
        refresh()
        state.target = min(99, max(1, target))
        state.minutes = min(240, max(1, minutes))
        state.reconcile(now: now)
        justCompleted = false
        persist()
        didChange?()
    }

    func setSoundVolume(_ volume: Double) {
        soundVolume = min(1, max(0.1, volume))
        defaults.set(soundVolume, forKey: "timeSlots.soundVolume")
    }

    func previewSound(volume: Double? = nil) {
        guard let sound else { return }
        soundFailed = !sound.play(volume: Float(min(1, max(0.1, volume ?? soundVolume))))
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func updateActivity() {
        if isRunning && activity == nil {
            activity = ProcessInfo.processInfo.beginActivity(
                options: .userInitiatedAllowingIdleSystemSleep, reason: "Timing a focus slot")
        } else if !isRunning, let current = activity {
            ProcessInfo.processInfo.endActivity(current)
            activity = nil
        }
    }
}

// Draw the timer action explicitly rather than relying on the prominent
// system button's tint/label treatment, which differs between macOS versions.
private struct TimerActionButtonStyle: ButtonStyle {
    let fill: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(Color.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 11)
            .background(fill.opacity(configuration.isPressed ? 0.85 : 1), in: RoundedRectangle(cornerRadius: 9))
            .contentShape(RoundedRectangle(cornerRadius: 9))
    }
}

struct SlotPopover: View {
    @ObservedObject var store: SlotStore
    @State private var settings = false
    @State private var history = false
    @State private var targetInput: String
    @State private var minutesInput: String
    @State private var soundVolumeInput: Double
    private let onStart: () -> Void
    private let accent = Color(red: 0.22, green: 0.49, blue: 0.40)

    init(store: SlotStore, initiallyShowingSettings: Bool = false, initiallyShowingHistory: Bool = false, onStart: @escaping () -> Void = {}) {
        self.store = store
        self.onStart = onStart
        _settings = State(initialValue: initiallyShowingSettings)
        _history = State(initialValue: initiallyShowingHistory)
        _targetInput = State(initialValue: String(store.state.target))
        _minutesInput = State(initialValue: String(store.state.minutes))
        _soundVolumeInput = State(initialValue: store.soundVolume)
    }

    private var validSettings: Bool {
        guard let target = Int(targetInput), let minutes = Int(minutesInput) else { return false }
        return (1...99).contains(target) && (1...240).contains(minutes)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "circle.dotted.circle.fill").foregroundColor(accent)
                Text(settings ? "Settings" : (history ? "History" : "Focus Slots")).font(.system(size: 14, weight: .semibold))
                Spacer()
                if !settings && !history {
                    Button {
                        store.refresh()
                        history = true
                    } label: { Image(systemName: "list.bullet.rectangle") }
                    .buttonStyle(.plain)
                    .help("History")
                    .accessibilityLabel("History")
                    .padding(.trailing, 8)
                    Button {
                        targetInput = String(store.state.target)
                        minutesInput = String(store.state.minutes)
                        soundVolumeInput = store.soundVolume
                        settings = true
                    } label: { Image(systemName: "gearshape") }
                    .buttonStyle(.plain)
                    .help("Settings")
                    .accessibilityLabel("Settings")
                } else if history {
                    Button("Back") { history = false }
                        .buttonStyle(.plain)
                        .foregroundColor(.primary)
                        .help("Back to timer")
                }
            }
            .padding(.bottom, 22)

            if settings {
                VStack(alignment: .leading, spacing: 18) {
                    settingRow("Slots per day", value: $targetInput, range: 1...99)
                    settingRow("Minutes per slot", value: $minutesInput, range: 1...240)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Completion sound").font(.system(size: 13))
                            Spacer()
                            Button("Test sound") { store.previewSound(volume: soundVolumeInput) }
                                .font(.system(size: 12))
                        }
                        HStack {
                            Image(systemName: "speaker.wave.1").foregroundColor(.secondary)
                            Slider(value: $soundVolumeInput, in: 0.1...1)
                                .accessibilityLabel("Completion sound volume")
                            Text("\(Int((soundVolumeInput * 100).rounded()))%")
                                .font(.system(size: 11)).monospacedDigit().frame(width: 34, alignment: .trailing)
                        }
                        Text(store.soundFailed ? "Couldn't play the sound. Please try again." : "Uses your Mac’s current output and volume.")
                            .font(.system(size: 11)).foregroundColor(store.soundFailed ? .red : .secondary)
                    }
                    Text(store.isRunning ? "Changes apply to the next slot. Your current timer will keep running." : "Each slot starts when you press Start. No automatic breaks.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack {
                        Button("Cancel") { settings = false }
                        Spacer()
                        Button("Save") {
                            guard let target = Int(targetInput), let minutes = Int(minutesInput), validSettings else { return }
                            store.setSoundVolume(soundVolumeInput)
                            store.saveSettings(target: target, minutes: minutes)
                            settings = false
                        }
                        .keyboardShortcut(.defaultAction)
                        .tint(accent)
                        .disabled(!validSettings)
                    }
                }
            } else if history {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Completed slots / daily target")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.state.historyEntries) { entry in
                                HStack {
                                    Text(entry.dateLabel(relativeTo: store.now))
                                    Spacer()
                                    Text("\(entry.completed)/\(entry.target)")
                                        .monospacedDigit()
                                        .fontWeight(entry.completed >= entry.target ? .semibold : .regular)
                                }
                                .font(.system(size: 13))
                                .padding(.vertical, 12)
                                Divider()
                            }
                        }
                        .padding(.trailing, 4)
                    }
                    .frame(height: min(280, CGFloat(max(1, store.state.historyEntries.count)) * 42))
                }
            } else {
                VStack(spacing: 12) {
                    Text("\(store.state.completed) of \(store.state.target) slots today")
                        .font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    Text(SlotState.clock(store.remaining))
                        .font(.system(size: 51, weight: .light, design: .rounded))
                        .monospacedDigit()
                        .accessibilityLabel("Time remaining")
                        .accessibilityValue(SlotState.clock(store.remaining))
                    ProgressView(value: store.progress)
                        .tint(accent)
                        .padding(.horizontal, 10)
                    Text(status)
                        .font(.system(size: 12)).foregroundColor(.secondary)
                        .frame(height: 18)
                    Button {
                        if store.isRunning {
                            store.stop()
                        } else {
                            store.start()
                            onStart()
                        }
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: store.isRunning ? "stop.fill" : "play.fill")
                                .symbolRenderingMode(.monochrome)
                            Text(store.isRunning ? "Stop" : "Start")
                        }
                        .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(TimerActionButtonStyle(fill: store.isRunning
                        ? Color(red: 0.30, green: 0.32, blue: 0.36) : accent))
                    .accessibilityLabel(store.isRunning ? "Stop" : "Start")
                    .help(store.isRunning ? "Discard this unfinished slot" : "Start a new focus slot")
                }
            }

            Divider().padding(.top, 20).padding(.bottom, 12)
            HStack {
                Text(settings ? AppVersion.display : (history ? "Saved on this Mac" : "Resets daily at midnight"))
                    .font(.system(size: 10)).foregroundColor(.secondary)
                Spacer()
                Button("Quit") { NSApplication.shared.terminate(nil) }
                    .font(.system(size: 11)).buttonStyle(.plain).foregroundColor(.secondary)
                    .help("Quit Focus Slots; a running slot resumes on launch")
            }
        }
        .padding(22)
        .frame(width: 324)
        .onAppear { store.refresh() }
    }

    private var status: String {
        if store.isRunning { return "One slot. One thing at a time." }
        if store.justCompleted { return "Slot complete. Ready for another." }
        if store.state.completed >= store.state.target { return "Daily target reached. Keep going if you like." }
        return "Ready when you are."
    }

    private func settingRow(_ title: String, value: Binding<String>, range: ClosedRange<Int>) -> some View {
        HStack {
            Text(title).font(.system(size: 13))
            Spacer()
            TextField("", text: value)
                .multilineTextAlignment(.trailing)
                .frame(width: 44)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel(title)
            Stepper(title, value: Binding(
                get: { min(range.upperBound, max(range.lowerBound, Int(value.wrappedValue) ?? range.lowerBound)) },
                set: { value.wrappedValue = String($0) }
            ), in: range).labelsHidden().fixedSize()
                .accessibilityLabel(title)
                .help("\(range.lowerBound)–\(range.upperBound)")
        }
    }

}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()
    private var store: SlotStore!
    private var lastTitle = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Keep a second launch from creating another menu bar item.
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "local.timeslots.app")
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        if let existing = others.first {
            existing.activate(options: [])
            NSApp.terminate(nil)
            return
        }
        NSApp.setActivationPolicy(.accessory)
        store = SlotStore()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.font = .monospacedDigitSystemFont(ofSize: 12, weight: .medium)
            button.target = self
            button.action = #selector(togglePopover)
        }
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: SlotPopover(store: store, onStart: { [weak self] in
            self?.popover.performClose(nil)
        }))
        store.didChange = { [weak self] in self?.updateTitle() }
        updateTitle()
    }

    private func updateTitle() {
        let counter = "\(store.state.completed)/\(store.state.target)"
        let title = store.isRunning ? "\(counter)  ·  \(SlotState.clock(store.remaining))" : counter
        if title != lastTitle {
            statusItem.button?.title = title
            statusItem.button?.setAccessibilityLabel("Focus Slots: \(store.state.completed) of \(store.state.target) completed" + (store.isRunning ? ", \(SlotState.clock(store.remaining)) remaining" : ""))
            lastTitle = title
        }
        statusItem.button?.toolTip = store.isRunning ? "Focus Slots — \(SlotState.clock(store.remaining)) remaining" : "Focus Slots — \(counter) today"
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.isShown { popover.performClose(nil) }
        else {
            store.refresh()
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }
}

#if !TIME_SLOTS_UI_TEST
@main
enum FocusSlotsApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
