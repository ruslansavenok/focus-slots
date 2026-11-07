import AppKit
import AVFoundation

@MainActor
protocol CompletionSoundPlaying: AnyObject {
    @discardableResult func play(volume: Float) -> Bool
}

/// Use normal audio output, and reopen it on each alert so device changes and
/// wake from sleep do not leave a player attached to an old output device.
@MainActor
final class CompletionSound: NSObject, CompletionSoundPlaying, AVAudioPlayerDelegate {
    private let url: URL?
    private var player: AVAudioPlayer?
    private(set) var finishedSuccessfully: Bool?

    init(url: URL? = Bundle.main.url(forResource: "completion", withExtension: "wav")) {
        self.url = url
        super.init()
    }

    @discardableResult
    func play(volume: Float) -> Bool {
        player?.stop()
        finishedSuccessfully = nil
        guard let url else {
            NSLog("Focus Slots: completion sound is missing")
            return false
        }
        do {
            let next = try AVAudioPlayer(contentsOf: url)
            player = next
            next.delegate = self
            next.volume = min(1, max(0, volume))
            guard next.prepareToPlay(), next.play() else {
                NSLog("Focus Slots: audio playback could not start")
                return false
            }
            return true
        } catch {
            NSLog("Focus Slots: audio playback failed: %@", error.localizedDescription)
            return false
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor [weak self] in self?.finishedSuccessfully = flag }
    }
}
