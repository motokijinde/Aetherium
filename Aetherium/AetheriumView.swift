import SwiftUI

// --- UI Components ---
struct MessageBubble: View {
    let message: Message
    let speakerName: String
    let isLoadingActive: Bool
    var isUser: Bool { message.role == "user" }
    @State private var dotOpacity: [Double] = [1.0, 0.6, 0.6]
    @State private var hoveredStatIndex: Int? = nil
    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if !isUser { Image(systemName: "waveform.circle.fill").font(.system(size: 32)).foregroundStyle(Color.green.gradient).padding(.bottom, 2) } else { Spacer() }
            VStack(alignment: isUser ? .trailing : .leading, spacing: 4) {
                Text(isUser ? "あなた" : speakerName).font(.system(size: 10, weight: .bold)).foregroundColor(.secondary)
                VStack(alignment: .leading, spacing: 4) {
                    if message.content.isEmpty && isLoadingActive && !isUser {
                        HStack(spacing: 3) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle().fill(Color.blue).frame(width: 6, height: 6)
                                    .opacity(dotOpacity[index])
                            }
                        }.padding(.horizontal, 14).padding(.vertical, 10).onAppear { 
                            withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dotOpacity[0] = 0.3 }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dotOpacity[1] = 0.3 }
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) { dotOpacity[2] = 0.3 }
                            }
                        }
                    } else {
                        Text(message.content).padding(.horizontal, 14).padding(.vertical, 10).background(isUser ? AnyShapeStyle(Color.blue.gradient) : AnyShapeStyle(Color.gray.opacity(0.15).gradient)).foregroundColor(isUser ? .white : .primary).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)).textSelection(.enabled)
                    }
                    if let stats = message.stats, !isUser, !message.content.isEmpty {
                        HStack(spacing: 3) {
                            // Speed stat
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill").font(.system(size: 7))
                                Text(String(format: "%.1f t/s", stats.tokensPerSecond ?? 0)).font(.system(size: 8, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .onHover { hovering in
                                hoveredStatIndex = hovering ? 0 : nil
                            }
                            .overlay(alignment: .top) {
                                if hoveredStatIndex == 0 {
                                    Text("トークン生成速度")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(4)
                                        .offset(y: -40)
                                        .zIndex(1)
                                }
                            }
                            
                            // Token count stat
                            HStack(spacing: 2) {
                                Image(systemName: "tag").font(.system(size: 7))
                                Text(String(format: "%d tokens", stats.completion_tokens)).font(.system(size: 8, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .onHover { hovering in
                                hoveredStatIndex = hovering ? 1 : nil
                            }
                            .overlay(alignment: .top) {
                                if hoveredStatIndex == 1 {
                                    Text("生成トークン数")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(4)
                                        .offset(y: -40)
                                        .zIndex(1)
                                }
                            }
                            
                            // TTFT stat
                            HStack(spacing: 2) {
                                Image(systemName: "clock").font(.system(size: 7))
                                Text(String(format: "%.1f second", stats.ttft ?? 0)).font(.system(size: 8, design: .monospaced))
                            }
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                            .background(Color.secondary.opacity(0.1))
                            .cornerRadius(6)
                            .onHover { hovering in
                                hoveredStatIndex = hovering ? 2 : nil
                            }
                            .overlay(alignment: .top) {
                                if hoveredStatIndex == 2 {
                                    Text("最初のトークンまでの時間")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.black.opacity(0.8))
                                        .cornerRadius(4)
                                        .offset(y: -40)
                                        .zIndex(1)
                                }
                            }
                        }
                        .foregroundColor(.secondary)
                        .padding(.leading, 4)
                    }
                }
            }
            if isUser { Image(systemName: "person.crop.circle.fill").font(.system(size: 32)).foregroundStyle(Color.blue.gradient).padding(.bottom, 2) } else { Spacer() }
        }.padding(.horizontal, 16).padding(.vertical, 8)
    }
}

struct AetheriumView: View {
    @StateObject private var vm = ChatViewModel()
    @State private var inputText = ""
    @State private var rotationAngle: Double = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if !vm.isConnecting {
                    VStack(spacing: 40) {
                        VStack(spacing: 10) {
                            Image(systemName: "sparkles").font(.system(size: 50)).foregroundStyle(Color.blue.gradient)
                            Text("Aetherium").font(.system(size: 40, weight: .black, design: .rounded))
                        }
                        VStack(alignment: .leading, spacing: 25) {
                            settingRow(title: "Model", icon: "cpu", content: $vm.selectedModel, options: vm.models, placeholder: "LLMを起動してください")
                            settingRow(title: "Voice", icon: "mouth", selection: $vm.selectedSpeakerID, options: vm.displaySpeakers, placeholder: "VOICEVOXを起動してください")
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Speed: \(String(format: "%.2f", vm.speechSpeed))x", systemImage: "speedometer").font(.subheadline).bold()
                                Slider(value: $vm.speechSpeed, in: 0.5...2.0)
                            }
                        }.padding(30).background(.thinMaterial).cornerRadius(24).frame(width: 380)
                        
                        // 【修正】両方のリストが取得できている場合のみ有効化
                        Button(action: { withAnimation(.spring()) { vm.isConnecting = true } }) {
                            Text("Start Session").font(.headline).frame(width: 220, height: 40)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .clipShape(Capsule())
                        .disabled(vm.models.isEmpty || vm.displaySpeakers.isEmpty)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .task { await vm.fetchModels(); await vm.fetchVVSpeakers() }
                } else {
                    VStack(spacing: 0) {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: 0) { ForEach(vm.messages, id: \.id) { msg in let isLastMsg = (msg.id == vm.messages.last?.id); let isLoadingActive = isLastMsg && msg.role == "assistant" && vm.isGenerating; MessageBubble(message: msg, speakerName: vm.currentSpeakerName, isLoadingActive: isLoadingActive) } }.padding(.vertical, 10)
                                Spacer().id("bottom")
                            }.onChange(of: vm.messages.count) { _, _ in 
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                }
                            }
                            .onChange(of: vm.messages.last?.content) { _, _ in
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                        }
                        HStack(spacing: 12) {
                            TextField("メッセージを入力...", text: $inputText).textFieldStyle(.plain).padding(.horizontal, 16).padding(.vertical, 10).background(Capsule().fill(Color.primary.opacity(0.05))).onSubmit { let t = inputText; inputText = ""; vm.sendMessage(t) }
                            Button(action: { let t = inputText; inputText = ""; vm.sendMessage(t) }) { Image(systemName: "arrow.up.circle.fill").font(.system(size: 32)).foregroundStyle(inputText.isEmpty ? AnyShapeStyle(Color.gray) : AnyShapeStyle(Color.blue.gradient)) }.buttonStyle(.plain).disabled(inputText.isEmpty)
                        }.padding(.horizontal, 16).padding(.vertical, 12).background(.ultraThinMaterial)
                    }
                    .toolbar {
                        ToolbarItemGroup(placement: .primaryAction) {
                            HStack(spacing: 8) {
                                Button(action: { if vm.isGenerating { vm.stopGeneration() } }) {
                                    HStack(spacing: 6) {
                                        ZStack {
                                            Image(systemName: "waveform").foregroundStyle(Color.secondary).opacity(vm.isGenerating ? 0 : 1)
                                            Image(systemName: "rays").rotationEffect(.degrees(rotationAngle)).foregroundStyle(Color.blue.gradient).opacity(vm.isGenerating ? 1 : 0).onAppear { withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) { rotationAngle = 360 } }
                                        }.frame(width: 18)
                                        Text(vm.isGenerating ? "Generating..." : "Ready").font(.system(size: 11, weight: .bold, design: .rounded)).foregroundColor(vm.isGenerating ? .primary : .secondary)
                                        if vm.isGenerating { Image(systemName: "stop.circle.fill").foregroundColor(.red).font(.system(size: 14)) }
                                    }.padding(.leading, 8).padding(.trailing, vm.isGenerating ? 8 : 4).padding(.vertical, 4)
                                }.buttonStyle(.plain).disabled(!vm.isGenerating)
                                Divider().frame(height: 16).padding(.horizontal, 2)
                                Button(action: { withAnimation { inputText = ""; vm.resetSession() } }) { Text("Exit").fontWeight(.medium).foregroundColor(.red) }.buttonStyle(.bordered).controlSize(.small)
                                Spacer().frame(width: 6)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Aetherium")
            .navigationSubtitle(vm.isConnecting ? "Session with \(vm.currentSpeakerName) (\(vm.selectedModel))" : "Settings")
        }
        .frame(minWidth: 600, minHeight: 700)
    }

    private func settingRow(title: String, icon: String, content: Binding<String>, options: [String], placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline).bold()
            if options.isEmpty { Text(placeholder).font(.caption).foregroundColor(.red) } else {
                Picker("", selection: content) { ForEach(options, id: \.self) { Text($0).tag($0) } }.pickerStyle(.menu).labelsHidden()
            }
        }
    }

    private func settingRow(title: String, icon: String, selection: Binding<Int>, options: [(id: Int, name: String)], placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon).font(.subheadline).bold()
            if options.isEmpty { Text(placeholder).font(.caption).foregroundColor(.red) } else {
                Picker("", selection: selection) { ForEach(options, id: \.id) { Text($0.name).tag($0.id) } }.pickerStyle(.menu).labelsHidden()
            }
        }
    }
}
