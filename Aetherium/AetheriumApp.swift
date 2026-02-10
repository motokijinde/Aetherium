import SwiftUI

@main
struct AetheriumApp: App {
    // About画面の表示を管理するフラグ
    @State private var isShowingAbout = false

    var body: some Scene {
        WindowGroup {
            AetheriumView()
                // 下記のシートでAbout画面を呼び出せるようにします
                .sheet(isPresented: $isShowingAbout) {
                    AboutView()
                }
        }
        // ここが重要！メニューバーの挙動をカスタマイズします
        .commands {
            CommandGroup(replacing: .appInfo) {
                // Labelを使うことで、テキストの横にアイコンを表示できます
                Button {
                    isShowingAbout = true
                } label: {
                    Label("About Aetherium", systemImage: "info.circle")
                }
            }
        }
    }
}
