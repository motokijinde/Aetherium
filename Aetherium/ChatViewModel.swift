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
    @Published var selectedSpeakerID: Int = 3
    @Published var displaySpeakers: [(id: Int, name: String)] = []
    @Published var speechSpeed: Double = 1.00
    
    private var generatingTask: Task<Void, Never>?
    private var speechBuffer = ""
    private var currentAudioSessionID: UUID? = nil
    
    var currentSpeakerName: String { displaySpeakers.first(where: { $0.id == selectedSpeakerID })?.name ?? "AI" }
    
    // 接続先
    let llmServerURL = "http://127.0.0.1:1234/v1"
    let voicevoxURL = "http://127.0.0.1:50021"

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
        } catch {
            print("VOICEVOX not found")
            self.displaySpeakers = []
        }
    }

    func stopGeneration() {
        generatingTask?.cancel()
        if let sid = currentAudioSessionID {
            PlayerManager.shared.cancel(sessionID: sid)
            currentAudioSessionID = nil
        }
        generatingTask = nil
        isGenerating = false
        speechBuffer = ""
    }

    func sendMessage(_ text: String) {
        stopGeneration()
        isGenerating = true
        // Run network work off the MainActor; update UI on MainActor only
        let audioSessionID = UUID()
        currentAudioSessionID = audioSessionID
        generatingTask = Task {
            let requestStartTime = Date()
            var firstTokenTime: Date?
            speechBuffer = ""
            await MainActor.run {
                self.messages.append(Message(role: "user", content: text))
                self.messages.append(Message(role: "assistant", content: ""))
            }
            let index = await MainActor.run { self.messages.count - 1 }
            
            guard let url = URL(string: "\(llmServerURL)/chat/completions") else { self.isGenerating = false; return }
            var request = URLRequest(url: url); request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try? JSONSerialization.data(withJSONObject: [
                "model": selectedModel,
                "messages": messages.dropLast().map { ["role": $0.role, "content": $0.content] },
                "stream": true,
                "stream_options": ["include_usage": true]
            ])
            
            do {
                let (stream, _) = try await URLSession.shared.bytes(for: request)
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
                                self.messages[index].content += content
                            }
                            self.speechBuffer += content
                            if content.contains(where: { "。！？\n".contains($0) }) {
                                let sentence = speechBuffer.trimmingCharacters(in: .whitespacesAndNewlines)
                                if !sentence.isEmpty && !Task.isCancelled { await synthesizeSpeech(text: sentence, sessionID: audioSessionID) }
                                speechBuffer = ""
                            }
                        }
                        if let usageDict = json["usage"] as? [String: Int] {
                            let totalDuration = Date().timeIntervalSince(firstTokenTime ?? requestStartTime)
                            let ttftValue = firstTokenTime?.timeIntervalSince(requestStartTime)
                            await MainActor.run {
                                self.messages[index].stats = UsageStats(prompt_tokens: usageDict["prompt_tokens"] ?? 0, completion_tokens: usageDict["completion_tokens"] ?? 0, total_tokens: usageDict["total_tokens"] ?? 0, tokensPerSecond: Double(usageDict["completion_tokens"] ?? 0) / max(totalDuration, 0.001), ttft: ttftValue, totalDuration: totalDuration)
                            }
                        }
                    }
                }
                if !Task.isCancelled && !speechBuffer.isEmpty { await synthesizeSpeech(text: speechBuffer, sessionID: audioSessionID) }
            } catch {
                if (error as NSError).code != NSURLErrorCancelled {
                    print("Stream error: \(error)")
                }
            }
            await MainActor.run {
                self.isGenerating = false
                self.generatingTask = nil
                self.currentAudioSessionID = nil
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
        // perform network audio generation off the MainActor
        await Task.detached(priority: .userInitiated) {
            do {
                var qReq = URLRequest(url: qUrl); qReq.httpMethod = "POST"
                let (qData, _) = try await URLSession.shared.data(for: qReq)
                // cancelled check
                if Task.isCancelled { return }
                var queryJson = try JSONSerialization.jsonObject(with: qData) as? [String: Any]
                queryJson?["speedScale"] = speed
                let modifiedQData = try JSONSerialization.data(withJSONObject: queryJson as Any)
                if Task.isCancelled { return }
                guard let sURL = URL(string: "\(self.voicevoxURL)/synthesis?speaker=\(speaker)") else { return }
                var sReq = URLRequest(url: sURL); sReq.httpMethod = "POST"
                sReq.httpBody = modifiedQData
                sReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                let (aData, _) = try await URLSession.shared.data(for: sReq)
                if Task.isCancelled { return }
                // enqueue on main actor and verify session still active
                await MainActor.run {
                    if self.currentAudioSessionID == sessionID {
                        PlayerManager.shared.enqueue(data: aData, sessionID: sessionID)
                    }
                }
            } catch {
                if (error as NSError).code != NSURLErrorCancelled { print("Speech error: \(error)") }
            }
        }.value
    }

    func resetSession() { stopGeneration(); self.messages = []; self.isConnecting = false }
}
