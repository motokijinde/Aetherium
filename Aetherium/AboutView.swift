import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss

    // XcodeのGeneral設定からVersionとBuildを自動取得
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 16) {
                // アプリ本体のアイコンを表示
                if let nsImage = NSImage(named: NSImage.applicationIconName) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)
                        .padding(.top, 40)
                }

                VStack(spacing: 2) {
                    Text("Aetherium")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                    
                    Text("Version \(appVersion)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                // 指定いただいた説明文
                Text("Aetherium（エーテリウム）は、ローカルLLMとVOICEVOXを繋ぐ、あなただけのプライベート・アシスタントです。")
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.top, 10)
                    .padding(.horizontal, 40)

                Text("© 2026 NIK Co., Ltd. Developed by JINDE")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                    .padding(.top, 20)
                    .padding(.bottom, 30)
            }
            
            Divider()
            
            Button("完了") {
                dismiss()
            }
            .padding(12)
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
        }
        .frame(width: 320)
    }
}
