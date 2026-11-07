import AppKit
import SwiftUI
import AVFoundation

@MainActor
final class SoundSpy: CompletionSoundPlaying {
    var volumes: [Float] = []
    let real: CompletionSound
    init(real: CompletionSound) { self.real = real }
    func play(volume: Float) -> Bool {
        volumes.append(volume)
        return real.play(volume: volume)
    }
}

@main
enum AppUITests {
    @MainActor static func main() throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let suite = "local.timeslots.tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let output = CommandLine.arguments[1]
        let realSound = CompletionSound()
        let soundSpy = SoundSpy(real: realSound)
        // Upgrade from an older saved volume; completion should use 100%.
        defaults.set(0.7, forKey: "timeSlots.soundVolume")
        let store = SlotStore(defaults: defaults, playSound: false)
        assert(store.soundVolume == 1, "Upgrade did not apply the new 100% volume")
        store.saveSettings(target: 6, minutes: 25)
        store.start()
        assert(store.isRunning && store.remaining == 1500)
        store.saveSettings(target: 4, minutes: 45)
        assert(store.remaining == 1500, "Settings changed active timer")
        store.stop()
        assert(!store.isRunning && store.state.completed == 0)
        let restored = SlotStore(defaults: defaults, playSound: false)
        assert(restored.state.target == 4 && restored.state.minutes == 45)

        var nearEnd = SlotState(now: Date())
        nearEnd.completed = 4
        let previousDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let previousKey = SlotState.dayKey(previousDate, calendar: .current)
        nearEnd.history[previousKey] = DailySlotProgress(day: previousKey, completed: 3, target: 4)
        let olderDate = Calendar.current.date(byAdding: .day, value: -2, to: Date())!
        let olderKey = SlotState.dayKey(olderDate, calendar: .current)
        nearEnd.history[olderKey] = DailySlotProgress(day: olderKey, completed: 4, target: 4)
        nearEnd.deadline = Date().addingTimeInterval(0.5)
        nearEnd.activeSeconds = 60
        defaults.set(try JSONEncoder().encode(nearEnd), forKey: "timeSlots.state.v1")
        let finishing = SlotStore(defaults: defaults, completionSound: soundSpy)
        assert(finishing.isRunning)
        RunLoop.main.run(until: Date().addingTimeInterval(2))
        assert(!finishing.isRunning && finishing.state.completed == 5 && finishing.justCompleted)
        assert(soundSpy.volumes.count == 1 && abs(soundSpy.volumes[0] - 1) < 0.001)
        assert(finishing.remaining == 2700 && finishing.progress == 0, "Completed slot did not reset to a full next timer")
        assert(finishing.state.history[finishing.state.day]?.completed == 5)
        assert(realSound.finishedSuccessfully == true, "Completion did not finish playing through audio output")
        finishing.refresh()
        assert(finishing.state.completed == 5, "Duplicate completion")
        assert(soundSpy.volumes.count == 1, "Duplicate completion sound")
        finishing.setSoundVolume(0.55)
        finishing.previewSound()
        assert(soundSpy.volumes.count == 2 && abs(soundSpy.volumes[1] - 0.55) < 0.001)
        assert(finishing.state.completed == 5, "Preview changed progress")
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        assert(realSound.finishedSuccessfully == true && !finishing.soundFailed)
        finishing.start()
        finishing.stop()
        assert(soundSpy.volumes.count == 2, "Stopping played completion audio")
        let completed = SlotStore(defaults: defaults, playSound: false)
        assert(completed.state.completed == 5 && !completed.isRunning)
        assert(abs(completed.soundVolume - 0.55) < 0.001, "Sound volume did not persist")
        assert(completed.state.history[completed.state.day]?.completed == 5)
        assert(completed.state.history[previousKey]?.completed == 3 && completed.state.history[previousKey]?.target == 4)
        assert(completed.state.history[olderKey]?.completed == 4)

        completed.setSoundVolume(1) // Show the release default in Settings screenshots.

        let bell = NSSound(contentsOfFile: output + "/completion.wav", byReference: false)
        assert(bell != nil && abs(bell!.duration - 0.8) < 0.01, "Bundled completion sound is invalid")
        for (name, appearance, settings, history) in [("light", NSAppearance.Name.aqua, false, false), ("dark", .darkAqua, false, false), ("settings", .aqua, true, false), ("history", .aqua, false, true), ("history-dark", .darkAqua, false, true)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 324, height: 350),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.backgroundColor = .windowBackgroundColor
            let hosting = NSHostingView(rootView: SlotPopover(store: completed, initiallyShowingSettings: settings, initiallyShowingHistory: history)
                .background(Color(nsColor: .windowBackgroundColor))
                .preferredColorScheme(appearance == .darkAqua ? .dark : .light))
            window.contentView = hosting
            let size = hosting.fittingSize
            window.setContentSize(size)
            window.center()
            window.makeKeyAndOrderFront(nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.35))
            hosting.layoutSubtreeIfNeeded()
            window.display()
            let snapshot = CGWindowListCreateImage(.null, .optionIncludingWindow, CGWindowID(window.windowNumber), [.boundsIgnoreFraming, .bestResolution])!
            let bitmap = NSBitmapImageRep(cgImage: snapshot)
            let data = bitmap.representation(using: .png, properties: [:])!
            try data.write(to: URL(fileURLWithPath: output).appendingPathComponent("popover-\(name).png"))
            window.orderOut(nil)
        }
        print("PASS: completion invokes real audio once, playback finishes, preview plays without counting, volume persists, stop is silent, unlimited extra slots, next timer reset, persisted history, light/dark/settings/history UI")
    }
}
