import SwiftUI

@main
struct AetheriumApp: App {
    @State private var isShowingAbout = false

    var body: some Scene {
        WindowGroup {
            AetheriumView()
                .sheet(isPresented: $isShowingAbout) {
                    AboutView()
                }
        }
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button {
                    isShowingAbout = true
                } label: {
                    Label("About Aetherium", systemImage: "info.circle")
                }
            }
        }
    }
}
