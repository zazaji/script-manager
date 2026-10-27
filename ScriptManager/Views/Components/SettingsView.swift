// ScriptManager/Views/Components/SettingsView.swift
import SwiftUI

public struct SettingsView: View {
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    @ObservedObject private var languageManager = AppLanguageManager.shared
    @ObservedObject private var appState = AppStateManager.shared
    @ObservedObject private var globalHotkeyManager = GlobalHotkeyManager.shared
    
    @Environment(\.presentationMode) var presentationMode
    
    public var body: some View {
        VStack(spacing: 0) {
            // 架构级重构：引入原生 TabView，将臃肿的长列表拆分为逻辑清晰的模块
            TabView {
                generalTab
                    .tabItem {
                        Label(Constants.UI.generalSettings, systemImage: "gearshape")
                    }
                
                aiAgentsTab
                    .tabItem {
                        Label(Constants.UI.aiSettingsTitle, systemImage: "sparkles")
                    }
                
                environmentTab
                    .tabItem {
                        Label(Constants.UI.environmentPaths, systemImage: "terminal")
                    }
            }
            .padding(.top, 12)
            .padding(.horizontal, 20)
            
            Divider()
                .padding(.top, 12)
            
            // 底部全局操作区
            HStack {
                Spacer()
                Button(Constants.UI.okButton) {
                    NSApp.keyWindow?.makeFirstResponder(nil)
                    presentationMode.wrappedValue.dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(20)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 700, height: 550) // 设定优雅的固定尺寸，为动态列表留出空间
        .onChange(of: appState.envPath) { _, newValue in
            if newValue.lowercased().contains("zshrc") {
                appState.defaultShell = "zsh"
            } else if newValue.lowercased().contains("bashrc") || newValue.lowercased().contains("bash_profile") {
                appState.defaultShell = "bash"
            }
        }
        .onAppear {
            appState.syncLaunchAtLoginState()
        }
        .onDisappear {
            appState.saveState()
        }
    }
    
    // MARK: - General Tab
    private var generalTab: some View {
        Form {
            VStack(spacing: 20) {
                HStack {
                    Text(Constants.UI.themeLabel).frame(width: 180, alignment: .trailing)
                    Picker("", selection: $appTheme) {
                        Text(Constants.UI.systemDefault).tag("system")
                        Text(Constants.UI.lightMode).tag("light")
                        Text(Constants.UI.darkMode).tag("dark")
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                
                HStack {
                    Text(Constants.UI.languageLabel).frame(width: 180, alignment: .trailing)
                    Picker("", selection: $languageManager.currentLanguage) {
                        Text("English").tag("en")
                        Text("中文").tag("zh-Hans")
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                
                HStack {
                    Text(Constants.UI.launchAtLoginLabel).frame(width: 180, alignment: .trailing)
                    Toggle("", isOn: Binding(
                        get: { appState.launchAtLogin },
                        set: { newValue in
                            appState.setLaunchAtLogin(newValue)
                        }
                    ))
                    .toggleStyle(.switch)
                    Spacer()
                }
                
                HStack {
                    Text(Constants.UI.shortcutLabel).frame(width: 180, alignment: .trailing)
                    ShortcutRecorderView(keyCode: $globalHotkeyManager.hotkeyCode, modifiers: $globalHotkeyManager.hotkeyModifiers)
                        .frame(width: 150)
                    Spacer()
                }
                
                Spacer() // 将内容顶上去
            }
            .padding(.vertical, 24)
        }
    }
    
    // MARK: - AI Agents Tab
    private enum AgentPreset {
        case hermes, opencode, claudeCode, openClaw, custom
    }
    
    private func addAgent(preset: AgentPreset) {
        let newAgent: AIAgentConfiguration
        switch preset {
        case .hermes:
            newAgent = AIAgentConfiguration(name: "Hermes", type: .openAI, endpoint: "http://127.0.0.1:8642/v1/chat/completions", prefix: ">", themeColor: "purple")
        case .opencode:
            newAgent = AIAgentConfiguration(name: "OpenCode", type: .openAI, endpoint: "http://127.0.0.1:4096/v1/chat/completions", prefix: "/", themeColor: "blue")
        case .claudeCode:
            newAgent = AIAgentConfiguration(name: "Claude Code", type: .openAI, endpoint: "http://127.0.0.1:8000/v1/chat/completions", prefix: "\\", themeColor: "orange")
        case .openClaw:
            newAgent = AIAgentConfiguration(name: "OpenClaw", type: .openClaw, endpoint: "http://127.0.0.1:3000/v1/responses", prefix: "@", themeColor: "red")
        case .custom:
            newAgent = AIAgentConfiguration(name: "New Agent", type: .openAI, endpoint: "http://127.0.0.1:8000/v1/chat/completions", prefix: "?", themeColor: "gray")
        }
        appState.aiAgents.append(newAgent)
    }
    
    private var aiAgentsTab: some View {
        Form {
            // 架构级重构：支持动态添加、删除、修改无限个 AI Agent 实例
            ScrollView {
                VStack(spacing: 24) {
                    ForEach($appState.aiAgents) { $agent in
                        VStack(spacing: 12) {
                            HStack {
                                Text(Constants.UI.agentNameLabel).frame(width: 80, alignment: .trailing)
                                TextField("", text: $agent.name)
                                    .textFieldStyle(.roundedBorder)
                                
                                Text(Constants.UI.agentTypeLabel).padding(.leading, 8)
                                Picker("", selection: $agent.type) {
                                    Text("OpenAI").tag(AIAgentType.openAI)
                                    Text("Anthropic").tag(AIAgentType.anthropic)
                                    Text("OpenClaw").tag(AIAgentType.openClaw)
                                }
                                .pickerStyle(.menu)
                                .frame(width: 100)
                                
                                Spacer()
                                
                                Button(action: {
                                    appState.aiAgents.removeAll { $0.id == agent.id }
                                }) {
                                    Image(systemName: "trash")
                                        .foregroundColor(.red)
                                }
                                .buttonStyle(.plain)
                            }
                            
                            HStack {
                                Text(Constants.UI.agentEndpointLabel).frame(width: 80, alignment: .trailing)
                                TextField("https://...", text: $agent.endpoint)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text(Constants.UI.agentApiKeyLabel).frame(width: 80, alignment: .trailing)
                                SecureField("Optional API Key", text: $agent.apiKey)
                                    .textFieldStyle(.roundedBorder)
                            }
                            
                            HStack {
                                Text(Constants.UI.agentPrefixLabel).frame(width: 80, alignment: .trailing)
                                TextField("", text: $agent.prefix)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                
                                Text(Constants.UI.agentThemeLabel).padding(.leading, 8)
                                Picker("", selection: $agent.themeColor) {
                                    Text("Purple").tag("purple")
                                    Text("Blue").tag("blue")
                                    Text("Orange").tag("orange")
                                    Text("Red").tag("red")
                                    Text("Green").tag("green")
                                    Text("Gray").tag("gray")
                                }
                                .pickerStyle(.menu)
                                .frame(width: 80)
                                
                                Text(Constants.UI.agentShortcutLabel).padding(.leading, 8)
                                ShortcutRecorderView(keyCode: $agent.hotkeyCode, modifiers: $agent.hotkeyModifiers)
                                    .frame(width: 120)
                                
                                Spacer()
                            }
                        }
                        .padding()
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                        )
                    }
                    
                    Menu {
                        Button(Constants.UI.addHermesButton) { addAgent(preset: .hermes) }
                        Button(Constants.UI.addOpenCodeButton) { addAgent(preset: .opencode) }
                        Button(Constants.UI.addClaudeCodeButton) { addAgent(preset: .claudeCode) }
                        Button(Constants.UI.addOpenClawButton) { addAgent(preset: .openClaw) }
                        Divider()
                        Button(Constants.UI.addCustomAgentButton) { addAgent(preset: .custom) }
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text(Constants.UI.addAgentButton)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .padding(.top, 8)
                    
                    Divider().padding(.vertical, 8)
                    
                    // Global AI Workspace
                    PathSettingRow(label: Constants.UI.aiWorkspaceLabel, path: $appState.aiWorkspacePath)
                }
                .padding(.vertical, 24)
                .padding(.trailing, 16) // 为滚动条留出空间
            }
        }
    }
    
    // MARK: - Environment Tab
    private var environmentTab: some View {
        Form {
            VStack(spacing: 20) {
                PathSettingRow(label: Constants.UI.pythonPathLabel, path: $appState.pythonPath)
                PathSettingRow(label: Constants.UI.nodePathLabel, path: $appState.nodePath)
                PathSettingRow(label: Constants.UI.rubyPathLabel, path: $appState.rubyPath)
                PathSettingRow(label: Constants.UI.envPathLabel, path: $appState.envPath)
                
                Divider().padding(.vertical, 8)
                
                HStack {
                    Text(Constants.UI.terminalEmulatorLabel).frame(width: 180, alignment: .trailing)
                    Picker("", selection: $appState.terminalEmulator) {
                        Text(Constants.UI.terminalAppTerminal).tag("Terminal")
                        Text(Constants.UI.terminalAppiTerm).tag("iTerm")
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                
                HStack {
                    Text(Constants.UI.defaultShellLabel).frame(width: 180, alignment: .trailing)
                    Picker("", selection: $appState.defaultShell) {
                        Text("Bash").tag("bash")
                        Text("Zsh").tag("zsh")
                    }
                    .pickerStyle(.segmented)
                    Spacer()
                }
                
                Spacer()
            }
            .padding(.vertical, 24)
        }
    }
}

struct PathSettingRow: View {
    let label: String
    @Binding var path: String
    
    @State private var localText: String = ""
    
    var body: some View {
        HStack {
            Text(label)
                .frame(width: 180, alignment: .trailing)
            
            TextField("", text: $localText)
                .textFieldStyle(.roundedBorder)
                .onChange(of: localText) { _, newValue in
                    if path != newValue {
                        path = newValue
                    }
                }
                .onChange(of: path) { _, newValue in
                    if localText != newValue {
                        localText = newValue
                    }
                }
                .onAppear {
                    localText = path
                }
            
            Button(Constants.UI.selectPathButton) {
                let panel = NSOpenPanel()
                panel.canChooseFiles = true
                panel.canChooseDirectories = true
                panel.showsHiddenFiles = true
                if panel.runModal() == .OK, let url = panel.url {
                    path = url.path
                    localText = url.path
                }
            }
        }
    }
}