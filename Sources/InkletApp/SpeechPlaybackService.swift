import AVFoundation
import Foundation

@MainActor
final class SpeechPlaybackService: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(audioData: Data) throws {
        stop()
        let player = try AVAudioPlayer(data: audioData)
        player.delegate = self
        player.prepareToPlay()
        player.play()
        self.player = player
    }

    func stop() {
        player?.stop()
        player = nil
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.player = nil
        }
    }
}
