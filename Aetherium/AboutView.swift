import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) var dismiss
    @State private var isHoveringGitHub = false

    // Xcode の General 設定から Version と Build を自動取得
    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
        return "\(version) (\(build))"
    }

    var body: some View {
        VStack(spacing: 16) {
            if let nsImage = NSImage(named: NSImage.applicationIconName) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 48, height: 48)
                    .padding(.top, 20)
            }

            VStack(spacing: 2) {
                Text("Aetherium")
                    .font(.system(size: 20, weight: .bold, design: .rounded))

                Text("Version \(appVersion)")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Text("Aetherium（エーテリウム）は、ローカルLLMとVOICEVOXを繋ぐ、あなただけのプライベート・アシスタントです。")
                .font(.system(size: 13))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .padding(.top, 10)
                .padding(.horizontal, 40)

            HStack(spacing: 4) {
                Text("© 2026 NIK Co., Ltd. Developed by JINDE")
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Link("GitHub", destination: URL(string: "https://github.com/motokijinde/aetherium.git")!)
                    .font(.system(size: 12, weight: .bold))
                    .underline(isHoveringGitHub)
                    .onHover { hovering in isHoveringGitHub = hovering }
            }
            .padding([.top, .bottom], 20)

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
