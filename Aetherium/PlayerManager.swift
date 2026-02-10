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
            isPlaying = true
            do {
                audioPlayer = try AVAudioPlayer(data: next.data)
                audioPlayer?.delegate = self
                audioPlayer?.prepareToPlay()
                audioPlayer?.play()
                return
            } catch {
                // try next
                continue
            }
        }
        isPlaying = false
        currentSessionID = nil
    }

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) { playNext() }
    
    /// Cancel all queued/playing audio for a specific session
    func cancel(sessionID: UUID) {
        // stop current if it's the same session
        if currentSessionID == sessionID {
            audioPlayer?.stop()
            currentSessionID = nil
        }
        // remove queued items for that session
        audioQueue.removeAll { $0.sessionID == sessionID }
        // if nothing playing, ensure state
        if audioPlayer == nil || audioPlayer?.isPlaying == false {
            isPlaying = false
        }
    }
}
