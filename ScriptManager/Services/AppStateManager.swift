// ScriptManager/Services/AppStateManager.swift
import Foundation
import Combine
import ServiceManagement

public class AppStateManager: ObservableObject {
    public static let shared = AppStateManager()
    
    @Published public var recentWorkspaces: [String] = []
    @Published public var frequentScripts:[String: Int] = [:]
    @Published public var customScripts: [String] = []
    @Published public var favoriteScripts: [String] = []
    
    @Published public var scriptEnvironments: [String:[ScriptEnvironmentVariable]] = [:]
    
    @Published public var pythonPath: String = "" { didSet { saveState() } }
    @Published public var nodePath: String = "" { didSet { saveState() } }
    @Published public var rubyPath: String = "" { didSet { saveState() } }
    @Published public var envPath: String = "" { didSet { saveState() } }
    @Published public var defaultShell: String = "bash" { didSet { saveState() } }
    
    @Published public var terminalEmulator: String = "Terminal" { didSet { saveState() } }
    
    @Published public var launchAtLogin: Bool = false
    
    // 架构级重构：全面拥抱动态 API 网关模式，支持无限扩展的 Agent 列表
    @Published public var aiAgents: [AIAgentConfiguration] = [] { 
        didSet { 
            saveState()
            updateAgentHotkeys()
        } 
    }
    
    @Published public var aiWorkspacePath: String = "~/temp_projects" { didSet { saveState() } }
    
    // 架构级增强：AI 任务历史记录，按 Agent ID 分类存储
    @Published public var aiTaskHistory: [String: [String]] = [:] { didSet { saveState() } }
    
    private var bookmarks:[String: Data] = [:]
    
    private let defaults = UserDefaults.standard
    
    private init() {
        loadState()
    }
    
    private func loadState() {
        recentWorkspaces = defaults.stringArray(forKey: "recentWorkspaces") ?? []
        frequentScripts = defaults.dictionary(forKey: "frequentScripts") as?[String: Int] ?? [:]
        customScripts = defaults.stringArray(forKey: "customScripts") ?? []
        favoriteScripts = defaults.stringArray(forKey: "favoriteScripts") ?? []
        bookmarks = defaults.dictionary(forKey: "bookmarks") as?[String: Data] ?? [:]
        
        pythonPath = defaults.string(forKey: "pythonPath") ?? ""
        nodePath = defaults.string(forKey: "nodePath") ?? ""
        rubyPath = defaults.string(forKey: "rubyPath") ?? ""
        envPath = defaults.string(forKey: "envPath") ?? ""
        defaultShell = defaults.string(forKey: "defaultShell") ?? "bash"
        terminalEmulator = defaults.string(forKey: "terminalEmulator") ?? "Terminal"
        
        // 架构级防坑：平滑迁移旧的硬编码配置到动态列表，确保用户数据不丢失
        if let data = defaults.data(forKey: "aiAgents"), let decoded = try? JSONDecoder().decode([AIAgentConfiguration].self, from: data) {
            aiAgents = decoded
        } else {
            let oldHermes = defaults.string(forKey: "hermesEndpoint")
            if oldHermes != nil {
                aiAgents = [
                    AIAgentConfiguration(name: "Hermes", type: .openAI, endpoint: defaults.string(forKey: "hermesEndpoint") ?? "http://127.0.0.1:8642/v1/chat/completions", apiKey: defaults.string(forKey: "hermesApiKey") ?? "", prefix: defaults.string(forKey: "hermesPrefix") ?? ">", themeColor: "purple"),
                    AIAgentConfiguration(name: "OpenCode", type: .openAI, endpoint: defaults.string(forKey: "opencodeEndpoint") ?? "http://127.0.0.1:4096/v1/chat/completions", apiKey: defaults.string(forKey: "opencodeApiKey") ?? "", prefix: defaults.string(forKey: "opencodePrefix") ?? "/", themeColor: "blue"),
                    AIAgentConfiguration(name: "Claude Code", type: .openAI, endpoint: defaults.string(forKey: "claudeCodeEndpoint") ?? "http://127.0.0.1:8000/v1/chat/completions", apiKey: defaults.string(forKey: "claudeCodeApiKey") ?? "", prefix: defaults.string(forKey: "claudeCodePrefix") ?? "\\", themeColor: "orange")
                ]
            } else {
                // 默认开箱即用的四大 Agent
                aiAgents = [
                    AIAgentConfiguration(name: "Hermes", type: .openAI, endpoint: "http://127.0.0.1:8642/v1/chat/completions", prefix: ">", themeColor: "purple"),
                    AIAgentConfiguration(name: "OpenCode", type: .openAI, endpoint: "http://127.0.0.1:4096/v1/chat/completions", prefix: "/", themeColor: "blue"),
                    AIAgentConfiguration(name: "Claude Code", type: .openAI, endpoint: "http://127.0.0.1:8000/v1/chat/completions", prefix: "\\", themeColor: "orange"),
                    AIAgentConfiguration(name: "OpenClaw", type: .openClaw, endpoint: "http://127.0.0.1:3000/v1/responses", prefix: "@", themeColor: "red")
                ]
            }
        }
        
        aiWorkspacePath = defaults.string(forKey: "aiWorkspacePath") ?? ""
        if aiWorkspacePath.isEmpty { aiWorkspacePath = "~/temp_projects" }
        
        aiTaskHistory = defaults.dictionary(forKey: "aiTaskHistory") as? [String: [String]] ?? [:]
        
        if let envData = defaults.data(forKey: "scriptEnvironments"),
           let decoded = try? JSONDecoder().decode([String:[ScriptEnvironmentVariable]].self, from: envData) {
            scriptEnvironments = decoded
        }
        
        if #available(macOS 13.0, *) {
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
        
        for (path, data) in bookmarks {
            restoreAccess(for: path, with: data)
        }
        
        // 初始化时注册所有专属快捷键
        updateAgentHotkeys()
    }
    
    public func saveState() {
        defaults.set(recentWorkspaces, forKey: "recentWorkspaces")
        defaults.set(frequentScripts, forKey: "frequentScripts")
        defaults.set(customScripts, forKey: "customScripts")
        defaults.set(favoriteScripts, forKey: "favoriteScripts")
        defaults.set(bookmarks, forKey: "bookmarks")
        
        defaults.set(pythonPath, forKey: "pythonPath")
        defaults.set(nodePath, forKey: "nodePath")
        defaults.set(rubyPath, forKey: "rubyPath")
        defaults.set(envPath, forKey: "envPath")
        defaults.set(defaultShell, forKey: "defaultShell")
        defaults.set(terminalEmulator, forKey: "terminalEmulator")
        
        // 保存动态 AI Agent 列表
        if let encoded = try? JSONEncoder().encode(aiAgents) {
            defaults.set(encoded, forKey: "aiAgents")
        }
        
        defaults.set(aiWorkspacePath, forKey: "aiWorkspacePath")
        defaults.set(aiTaskHistory, forKey: "aiTaskHistory")
        
        if let encoded = try? JSONEncoder().encode(scriptEnvironments) {
            defaults.set(encoded, forKey: "scriptEnvironments")
        }
        
        defaults.synchronize()
    }
    
    /// 架构级增强：动态注册所有 Agent 的专属快捷键
    public func updateAgentHotkeys() {
        GlobalHotkeyManager.shared.unregisterAllAgentHotkeys()
        
        for (index, agent) in aiAgents.enumerated() {
            if agent.hotkeyCode != 0 && agent.hotkeyModifiers != 0 {
                GlobalHotkeyManager.shared.registerAgentHotkey(id: index + 100, keyCode: agent.hotkeyCode, modifiers: agent.hotkeyModifiers) {
                    Task { @MainActor in
                        // 专属快捷键唤醒时，自动填入该 Agent 的前缀，实现秒级聚焦
                        LauncherViewModel.shared.searchText = agent.prefix
                        LauncherWindowManager.shared.show()
                    }
                }
            }
        }
    }
    
    /// 架构级增强：添加 AI 任务历史记录，自动去重并限制最大 50 条
    public func addAITaskHistory(agentID: String, prompt: String) {
        let cleanPrompt = prompt.trimmingCharacters(in: .whitespaces)
        guard !cleanPrompt.isEmpty else { return }
        
        var history = aiTaskHistory[agentID] ?? []
        // 去重：如果已存在相同的 prompt，先移除它
        history.removeAll { $0 == cleanPrompt }
        // 插入到队首
        history.insert(cleanPrompt, at: 0)
        // 限制最多 50 条
        if history.count > 50 {
            history = Array(history.prefix(50))
        }
        
        aiTaskHistory[agentID] = history
    }
    
    public func syncLaunchAtLoginState() {
        if #available(macOS 13.0, *) {
            DispatchQueue.main.async {
                self.launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
    
    public func setLaunchAtLogin(_ enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                    print("[AppStateManager] Successfully registered Launch at Login.")
                } else {
                    try SMAppService.mainApp.unregister()
                    print("[AppStateManager] Successfully unregistered Launch at Login.")
                }
                launchAtLogin = enabled
            } catch {
                print("[AppStateManager] Failed to toggle launch at login: \(error)")
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        } else {
            print("[AppStateManager] Launch at login requires macOS 13.0+")
        }
    }
    
    public func addWorkspace(_ url: URL) {
        let path = url.path
        if let index = recentWorkspaces.firstIndex(of: path) {
            recentWorkspaces.remove(at: index)
        }
        recentWorkspaces.insert(path, at: 0)
        if recentWorkspaces.count > 10 {
            recentWorkspaces = Array(recentWorkspaces.prefix(10))
        }
        
        saveBookmark(for: url)
        saveState()
    }
    
    public func addCustomScript(_ url: URL) {
        let path = url.path
        if !customScripts.contains(path) {
            customScripts.append(path)
            saveBookmark(for: url)
            saveState()
        }
    }
    
    public func removeCustomScript(_ path: String) {
        customScripts.removeAll { $0 == path }
        bookmarks.removeValue(forKey: path)
        saveState()
    }
    
    public func toggleFavorite(_ path: String) {
        if favoriteScripts.contains(path) {
            favoriteScripts.removeAll { $0 == path }
        } else {
            favoriteScripts.append(path)
        }
        saveState()
    }
    
    public func isFavorite(_ path: String) -> Bool {
        return favoriteScripts.contains(path)
    }
    
    public func saveEnvironmentVariables(for path: String, variables:[ScriptEnvironmentVariable]) {
        scriptEnvironments[path] = variables
        saveState()
    }
    
    public func getEnvironmentVariables(for path: String) ->[ScriptEnvironmentVariable] {
        return scriptEnvironments[path] ?? []
    }
    
    public func recordScriptRun(_ path: String) {
        frequentScripts[path, default: 0] += 1
        saveState()
    }
    
    public var topFrequentScripts: [String] {
        frequentScripts.sorted { $0.value > $1.value }.prefix(10).map { $0.key }
    }
    
    private func saveBookmark(for url: URL) {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
            bookmarks[url.path] = bookmarkData
            print("[AppStateManager] Successfully created security bookmark for \(url.path)")
        } catch {
            print("[AppStateManager] Failed to create bookmark for \(url.path): \(error)")
        }
    }
    
    private func restoreAccess(for path: String, with data: Data) {
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: data, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
            if isStale {
                print("[AppStateManager] Bookmark is stale for \(path), attempting to recreate.")
                saveBookmark(for: url)
            }
            if url.startAccessingSecurityScopedResource() {
                print("[AppStateManager] Successfully restored sandbox access to \(path)")
            } else {
                print("[AppStateManager] Failed to start accessing resource for \(path)")
            }
        } catch {
            print("[AppStateManager] Failed to resolve bookmark for \(path): \(error)")
        }
    }
}