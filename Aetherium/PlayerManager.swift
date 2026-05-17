import AVFoundation

@MainActor
final class PlayerManager: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerManager()
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [(sessionID: UUID, data: Data)] = []
    private var isPlaying = false
    private var currentSessionID: UUID?

    func enqueue(data: Data, sessionID: UUID) {
        audioQueue.append((sessionID: sessionID, data: data))
        if !isPlaying { playNext() }
    }

    private func playNext() {
        while !audioQueue.isEmpty {
            let next = audioQueue.removeFirst()
            currentSessionID = next.sessionID
            do {
                audioPlayer = try AVAudioPlayer(data: next.data)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                let didPlay = audioPlayer?.play() ?? false
                if !didPlay {
                    currentSessionID = nil
                    if isPlaying {
                        isPlaying = false
                        notifyPlaybackStateChanged(false)
                    }
                    continue
                }
                if !isPlaying {
                    isPlaying = true
                    notifyPlaybackStateChanged(true)
                }
                return
            } catch {
                currentSessionID = nil
                if isPlaying {
                    isPlaying = false
                    notifyPlaybackStateChanged(false)
                }
                continue
            }
        }
        if isPlaying {
            isPlaying = false
            notifyPlaybackStateChanged(false)
        }
        currentSessionID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        playNext()
    }

    func stopAll() {
        audioPlayer?.stop()
        audioQueue.removeAll()
        currentSessionID = nil
        if isPlaying {
            isPlaying = false
            notifyPlaybackStateChanged(false)
        }
    }

    private func notifyPlaybackStateChanged(_ playing: Bool) {
        NotificationCenter.default.post(
            name: .playerManagerPlaybackStateChanged,
            object: self,
            userInfo: ["isPlaying": playing]
        )
    }
}

extension Notification.Name {
    static let playerManagerPlaybackStateChanged = Notification.Name("PlayerManagerPlaybackStateChanged")
}
