import AVFoundation

// --- Player Manager ---
@MainActor
final class PlayerManager: NSObject, AVAudioPlayerDelegate {
    static let shared = PlayerManager()
    private var audioPlayer: AVAudioPlayer?
    private var audioQueue: [(sessionID: UUID, data: Data)] = []
    private var isPlaying = false
    private var currentSessionID: UUID?

    /// Enqueue audio data associated with a session ID
    func enqueue(data: Data, sessionID: UUID) {
        audioQueue.append((sessionID: sessionID, data: data))
        if !isPlaying { playNext() }
    }

    private func playNext() {
        // remove any queued items that belong to cancelled sessions are handled via cancel(sessionID:)
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
                    notifyIfSessionCompleted(next.sessionID)
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
                notifyIfSessionCompleted(next.sessionID)
                // try next
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
        let finishedID = currentSessionID
        playNext()
        notifyIfSessionCompleted(finishedID)
    }
    
    /// Cancel all queued/playing audio for a specific session
    func cancel(sessionID: UUID) {
        var stoppedCurrent = false
        // stop current if it's the same session
        if currentSessionID == sessionID {
            audioPlayer?.stop()
            currentSessionID = nil
            stoppedCurrent = true
        }
        // remove queued items for that session
        audioQueue.removeAll { $0.sessionID == sessionID }
        // if nothing playing, ensure state
        if audioPlayer == nil || audioPlayer?.isPlaying == false {
            if isPlaying {
                isPlaying = false
                notifyPlaybackStateChanged(false)
            }
        }
        // if we stopped current and there is more queued, advance
        if stoppedCurrent && !audioQueue.isEmpty {
            playNext()
        }
    }

    /// Stop any audio and clear the entire queue
    func stopAll() {
        audioPlayer?.stop()
        audioQueue.removeAll()
        currentSessionID = nil
        if isPlaying {
            isPlaying = false
            notifyPlaybackStateChanged(false)
        }
    }

    private func notifyIfSessionCompleted(_ finishedID: UUID?) {
        guard let finishedID else { return }
        if currentSessionID == finishedID { return }
        if audioQueue.contains(where: { $0.sessionID == finishedID }) { return }
        NotificationCenter.default.post(
            name: .playerManagerSessionCompleted,
            object: self,
            userInfo: ["sessionID": finishedID]
        )
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
    static let playerManagerSessionCompleted = Notification.Name("PlayerManagerSessionCompleted")
    static let playerManagerPlaybackStateChanged = Notification.Name("PlayerManagerPlaybackStateChanged")
}
