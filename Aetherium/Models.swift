import Foundation

// --- Usage Stats ---
/// LLMのトークン使用量や生成速度に関する統計情報
struct UsageStats: Codable {
    let prompt_tokens: Int
    let completion_tokens: Int
    let total_tokens: Int
    var tokensPerSecond: Double?
    var ttft: Double? // Time To First Token (最初の1文字が出るまでの時間)
    var totalDuration: Double? // 総処理時間（秒）
}

// --- Chat Message ---
/// チャット画面に表示する1つ1つのメッセージデータ
struct Message: Identifiable, Codable {
    var id = UUID()
    let role: String
    var content: String
    var stats: UsageStats?
}

// --- VOICEVOX Models ---
/// VOICEVOXのスタイル（ノーマル、あまあま等）
struct VVStyle: Codable, Hashable {
    let id: Int
    let name: String
}

/// VOICEVOXのキャラクター情報
struct VVSpeaker: Codable, Identifiable {
    var id: String { speaker_uuid }
    let name: String
    let speaker_uuid: String
    let styles: [VVStyle]
}

