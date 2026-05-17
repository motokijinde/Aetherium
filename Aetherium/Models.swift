import Foundation

struct UsageStats: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
    var tokensPerSecond: Double?
    var ttft: Double? // Time To First Token
}

struct Message: Identifiable, Codable {
    var id = UUID()
    let role: String
    var content: String
    var stats: UsageStats?
}

struct VVStyle: Codable, Hashable {
    let id: Int
    let name: String
}

struct VVSpeaker: Codable, Identifiable {
    var id: String { speaker_uuid }
    let name: String
    let speaker_uuid: String
    let styles: [VVStyle]
}
