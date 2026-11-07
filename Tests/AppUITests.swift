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
        let store = SlotStore(defaults: defaults, playSound: false)
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
        nearEnd.deadline = Date().addingTimeInterval(0.5)
        nearEnd.activeSeconds = 60
        defaults.set(try JSONEncoder().encode(nearEnd), forKey: "timeSlots.state.v1")
        let finishing = SlotStore(defaults: defaults, completionSound: soundSpy)
        assert(finishing.isRunning)
        RunLoop.main.run(until: Date().addingTimeInterval(2))
        assert(!finishing.isRunning && finishing.state.completed == 1 && finishing.justCompleted)
        assert(soundSpy.volumes.count == 1 && abs(soundSpy.volumes[0] - 0.85) < 0.001)
        assert(realSound.finishedSuccessfully == true, "Completion did not finish playing through audio output")
        finishing.refresh()
        assert(finishing.state.completed == 1, "Duplicate completion")
        assert(soundSpy.volumes.count == 1, "Duplicate completion sound")
        finishing.setSoundVolume(0.55)
        finishing.previewSound()
        assert(soundSpy.volumes.count == 2 && abs(soundSpy.volumes[1] - 0.55) < 0.001)
        assert(finishing.state.completed == 1, "Preview changed progress")
        RunLoop.main.run(until: Date().addingTimeInterval(1.2))
        assert(realSound.finishedSuccessfully == true && !finishing.soundFailed)
        finishing.start()
        finishing.stop()
        assert(soundSpy.volumes.count == 2, "Stopping played completion audio")
        let completed = SlotStore(defaults: defaults, playSound: false)
        assert(completed.state.completed == 1 && !completed.isRunning)
        assert(abs(completed.soundVolume - 0.55) < 0.001, "Sound volume did not persist")

        let bell = NSSound(contentsOfFile: output + "/completion.wav", byReference: false)
        assert(bell != nil && abs(bell!.duration - 0.8) < 0.01, "Bundled completion sound is invalid")
        for (name, appearance, settings) in [("light", NSAppearance.Name.aqua, false), ("dark", .darkAqua, false), ("settings", .aqua, true)] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 324, height: 350),
                                  styleMask: [.borderless], backing: .buffered, defer: false)
            window.appearance = NSAppearance(named: appearance)
            window.backgroundColor = .windowBackgroundColor
            let hosting = NSHostingView(rootView: SlotPopover(store: completed, initiallyShowingSettings: settings)
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
        print("PASS: completion invokes real audio once, playback finishes, preview plays without counting, volume persists, stop is silent, timer behavior, light/dark/settings UI")
    }
}
