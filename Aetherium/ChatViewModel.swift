import SwiftUI
import Combine

// --- ViewModel ---
@MainActor
final class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var selectedModel: String = ""
    @Published var models: [String] = []
    @Published var isConnecting = false
    @Published var isGenerating = false
    @Published var isAudioPlaying = false
    @Published var selectedSpeakerID: Int = 3
    @Published var displaySpeakers: [(id: Int, name: String)] = []
    @Published var speechSpeed: Double = 1.00
    
    private var generatingTask: Task<Void, Never>?
    private var speechQueue: [(text: String, sessionID: UUID)] = []
    private var speechQueueTask: Task<Void, Never>?
    private var isSynthesizing = false
    private var currentAudioSessionID: UUID? = nil
    private var streamTask: URLSessionTask?
    private var audioCompletionObserver: NSObjectProtocol?
    private var playbackStateObserver: NSObjectProtocol?
    
    var currentSpeakerName: String { displaySpeakers.first(where: { $0.id == selectedSpeakerID })?.name ?? "AI" }
    
    // 接続先
    let llmServerURL = "http://127.0.0.1:1234/v1"
    let voicevoxURL = "http://127.0.0.1:50021"

    init() {
        audioCompletionObserver = NotificationCenter.default.addObserver(
            forName: .playerManagerSessionCompleted,
            object: PlayerManager.shared,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let finishedID = note.userInfo?["sessionID"] as? UUID
            else { return }
            Task { @MainActor in
                guard self.currentAudioSessionID == finishedID else { return }
                if self.isSynthesizing { return }
                if self.speechQueue.contains(where: { $0.sessionID == finishedID }) { return }
                self.currentAudioSessionID = nil
            }
        }
        playbackStateObserver = NotificationCenter.default.addObserver(
            forName: .playerManagerPlaybackStateChanged,
            object: PlayerManager.shared,
            queue: .main
        ) { [weak self] note in
            guard let self,
                  let playing = note.userInfo?["isPlaying"] as? Bool
            else { return }
            Task { @MainActor in
                self.isAudioPlaying = playing
            }
        }
    }

    deinit {
        if let observer = audioCompletionObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = playbackStateObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func fetchModels() async {
        guard let url = URL(string: "\(llmServerURL)/models") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let dataArray = json["data"] as? [[String: Any]] {
                let fetchedModels = dataArray.compactMap { $0["id"] as? String }
                self.models = fetchedModels
                if self.selectedModel.isEmpty { self.selectedModel = fetchedModels.first ?? "" }
            }
        } catch {
            print("LLM Server not found")
            self.models = []
        }
    }

    func fetchVVSpeakers() async {
        guard let url = URL(string: "\(voicevoxURL)/speakers") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode([VVSpeaker].self, from: data)
            self.displaySpeakers = decoded.compactMap { speaker in
                guard let firstStyle = speaker.styles.first else { return nil }
                return (id: firstStyle.id, name: speaker.name)
            }.sorted { $0.name < $1.name }
            if let first = self.displaySpeakers.first,
               !self.displaySpeakers.contains(where: { $0.id == self.selectedSpeakerID }) {
                self.selectedSpeakerID = first.id
            }
        } catch {
            print("VOICEVOX not found")
            self.displaySpeakers = []
        }
    }

    func stopGeneration() {
        streamTask?.cancel()
        streamTask = nil
        generatingTask?.cancel()
        speechQueueTask?.cancel()
        speechQueueTask = nil
        speechQueue.removeAll()
        PlayerManager.shared.stopAll()
        currentAudioSessionID = nil
        isSynthesizing = false
        generatingTask = nil
        isGenerating = false
    }

    func sendMessage(_ text: String) {
        stopGeneration()
        isGenerating = true
        // Run network work off the MainActor; update UI on MainActor only
        let audioSessionID = UUID()
        currentAudioSessionID = audioSessionID
        let assistantID = UUID()
        self.messages.append(Message(role: "user", content: text))
        self.messages.append(Message(id: assistantID, role: "assistant", content: ""))
        let requestMessages = self.messages.dropLast().map { ["role": $0.role, "content": $0.content] }
        let requestModel = self.selectedModel
        generatingTask = Task {
            let requestStartTime = Date()
            var firstTokenTime: Date?
            var localSpeechBuffer = ""
            let indexForAssistant: () -> Int? = {
                return self.messages.firstIndex(where: { $0.id == assistantID })
            }
            
            guard let url = URL(string: "\(llmServerURL)/chat/completions") else {
                await MainActor.run {
                    self.isGenerating = false
                    self.generatingTask = nil
                    self.currentAudioSessionID = nil
                }
                return
            }
            var request = URLRequest(url: url); request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": requestModel,
                "messages": requestMessages,
                "stream": true,
                "stream_options": ["include_usage": true]
            ])
            
            do {
                let (stream, _) = try await URLSession.shared.bytes(for: request)
                await MainActor.run {
                    self.streamTask = stream.task
                }
                for try await line in stream.lines {
                    if Task.isCancelled { break }
                    // ignore done sentinel
                    let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.hasPrefix("data: [DONE]") || trimmed == "data: [DONE]" { break }
                    if line.hasPrefix("data: "), let data = line.dropFirst(6).data(using: .utf8),
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        if let choices = json["choices"] as? [[String: Any]],
                           let delta = choices.first?["delta"] as? [String: Any],
                           let content = delta["content"] as? String {
                            // mark first token time when we receive the first content chunk
                            if firstTokenTime == nil { firstTokenTime = Date() }
                            // update UI on main actor
                            await MainActor.run {
                                if let i = indexForAssistant() {
                                    self.messages[i].content += content
                                }
                            }
                            localSpeechBuffer += content
                            if content.contains(where: { "。！？\n".contains($0) }) {
                                let sentence = localSpeechBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !sentence.isEmpty && !Task.isCancelled {
                                    await MainActor.run { self.enqueueSpeech(sentence, sessionID: audioSessionID) }
                                }
                                localSpeechBuffer = ""
                            }
                        }
                        if let usageDict = json["usage"] as? [String: Int] {
                            let totalDuration = Date().timeIntervalSince(firstTokenTime ?? requestStartTime)
                            let ttftValue = firstTokenTime?.timeIntervalSince(requestStartTime)
                            await MainActor.run {
                                if let i = indexForAssistant() {
                                    self.messages[i].stats = UsageStats(prompt_tokens: usageDict["prompt_tokens"] ?? 0, completion_tokens: usageDict["completion_tokens"] ?? 0, total_tokens: usageDict["total_tokens"] ?? 0, tokensPerSecond: Double(usageDict["completion_tokens"] ?? 0) / max(totalDuration, 0.001), ttft: ttftValue, totalDuration: totalDuration)
                                }
                            }
                        }
                    }
                }
                if !Task.isCancelled && !localSpeechBuffer.isEmpty {
                    await MainActor.run { self.enqueueSpeech(localSpeechBuffer, sessionID: audioSessionID) }
                    localSpeechBuffer = ""
                }
            } catch {
                if (error as NSError).code != NSURLErrorCancelled {
                    print("Stream error: \(error)")
                }
            }
            await MainActor.run {
                self.isGenerating = false
                self.generatingTask = nil
                self.streamTask = nil
            }
        }
    }

    private func enqueueSpeech(_ text: String, sessionID: UUID) {
        speechQueue.append((text: text, sessionID: sessionID))
        if speechQueueTask == nil {
            speechQueueTask = Task { await processSpeechQueue() }
        }
    }

    private func processSpeechQueue() async {
        while !Task.isCancelled {
            let item: (text: String, sessionID: UUID)?
            if speechQueue.isEmpty {
                speechQueueTask = nil
                return
            } else {
                item = speechQueue.removeFirst()
            }
            guard let item else { continue }
            if currentAudioSessionID == item.sessionID {
                isSynthesizing = true
                await synthesizeSpeech(text: item.text, sessionID: item.sessionID)
                isSynthesizing = false
            }
        }
    }

    func synthesizeSpeech(text: String, sessionID: UUID) async {
        guard !Task.isCancelled else { return }
        let cleanText = text.replacingOccurrences(of: "[^\\p{L}\\p{N}。！？、]", with: "", options: .regularExpression)
        guard !cleanText.isEmpty else { return }
        let encoded = cleanText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        guard let qUrl = URL(string: "\(self.voicevoxURL)/audio_query?text=\(encoded)&speaker=\(self.selectedSpeakerID)") else { return }

        // capture current settings to use off-main
        let speed = await MainActor.run { self.speechSpeed }
        let speaker = await MainActor.run { self.selectedSpeakerID }
        do {
            try Task.checkCancellation()
            var qReq = URLRequest(url: qUrl); qReq.httpMethod = "POST"
            let (qData, _) = try await URLSession.shared.data(for: qReq)
            try Task.checkCancellation()
            var queryJson = try JSONSerialization.jsonObject(with: qData) as? [String: Any]
            queryJson?["speedScale"] = speed
            let modifiedQData = try JSONSerialization.data(withJSONObject: queryJson as Any)
            try Task.checkCancellation()
            guard let sURL = URL(string: "\(self.voicevoxURL)/synthesis?speaker=\(speaker)") else { return }
            var sReq = URLRequest(url: sURL); sReq.httpMethod = "POST"
            sReq.httpBody = modifiedQData
            sReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let (aData, _) = try await URLSession.shared.data(for: sReq)
            try Task.checkCancellation()
            // enqueue on main actor and verify session still active
            await MainActor.run {
                if self.currentAudioSessionID == sessionID {
                    PlayerManager.shared.enqueue(data: aData, sessionID: sessionID)
                }
            }
        } catch is CancellationError {
            // Task cancelled; no-op
        } catch {
            if (error as NSError).code != NSURLErrorCancelled { print("Speech error: \(error)") }
        }
    }

    func resetSession() { stopGeneration(); self.messages = []; self.isConnecting = false }
}
