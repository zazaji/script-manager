// ScriptManager/ViewModels/LauncherViewModel.swift
import Foundation
import SwiftUI
import AppKit
import Combine

public enum LauncherItemType {
    case script(ScriptItem)
    case application(ApplicationItem)
    case aiTask(prompt: String, agentID: String)
}

public struct LauncherItem: Identifiable {
    public let id: String
    public let path: String
    public let type: LauncherItemType
    public let name: String
    public var iconName: String? = nil
    public var iconColor: Color? = nil
    // 架构级重构：使用 appURL 替代 nsIcon，支持惰性加载
    public var appURL: URL? = nil
    public let description: String?
    public var parametersHint: String? = nil
}

@MainActor
public class LauncherViewModel: ObservableObject {
    public static let shared = LauncherViewModel()
    
    @Published public var searchText: String = "" {
        didSet {
            filterItems()
        }
    }
    
    @Published public var items: [LauncherItem] = []
    @Published public var selectedIndex: Int = 0
    
    @Published public var currentSession: ExecutionSession? = nil {
        didSet {
            TerminalManager.shared.updateWidgetState()
        }
    }
    
    private var cancellables = Set<AnyCancellable>()
    private var isDataReady = false

    private init() {
        WorkspaceViewModel.shared.$applications
            .receive(on: RunLoop.main)
            .sink { [weak self] apps in
                guard let self = self else { return }
                if !apps.isEmpty || self.isDataReady {
                    self.filterItems()
                }
                if !self.isDataReady && !apps.isEmpty {
                    self.isDataReady = true
                }
            }
            .store(in: &cancellables)

        WorkspaceViewModel.shared.$scripts
            .receive(on: RunLoop.main)
            .sink { [weak self] scripts in
                guard let self = self else { return }
                if !scripts.isEmpty || self.isDataReady {
                    self.filterItems()
                }
                if !self.isDataReady && !scripts.isEmpty {
                    self.isDataReady = true
                }
            }
            .store(in: &cancellables)

        WorkspaceViewModel.shared.$customScriptItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.filterItems() }
            .store(in: &cancellables)

        WorkspaceViewModel.shared.$frequentScriptItems
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.filterItems() }
            .store(in: &cancellables)
    }
    
    public func reset() {
        if currentSession != nil {
            return
        }
        
        if searchText == "" {
            filterItems()
        } else {
            searchText = ""
        }
        selectedIndex = 0
    }
    
    public func filterItems() {
        var newItems: [LauncherItem] = []
        
        var matchedAgent: AIAgentConfiguration? = nil
        var prompt: String = ""
        
        // 架构级增强：动态遍历所有配置的 Agent，支持无限扩展的前缀匹配
        for agent in AppStateManager.shared.aiAgents {
            if !agent.prefix.isEmpty && searchText.hasPrefix(agent.prefix) {
                matchedAgent = agent
                prompt = String(searchText.dropFirst(agent.prefix.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }
        
        if let agent = matchedAgent {
            let agentID = agent.id.uuidString
            
            // 1. 插入当前正在输入的任务项
            newItems.append(LauncherItem(
                id: "ai_task_\(agentID)_current",
                path: "ai_task_\(agentID)",
                type: .aiTask(prompt: prompt, agentID: agentID),
                name: prompt.isEmpty ? "Ask \(agent.name)..." : "\(agent.name): \(prompt)",
                iconName: agent.icon,
                iconColor: agent.uiColor,
                description: "Press Enter to execute via \(agent.name)",
                parametersHint: nil
            ))
            
            // 2. 插入该 Agent 的历史记录项
            let history = AppStateManager.shared.aiTaskHistory[agentID] ?? []
            // 如果当前有输入，则过滤历史记录；否则展示全部历史记录
            let filteredHistory = prompt.isEmpty ? history : history.filter { $0.localizedCaseInsensitiveContains(prompt) && $0 != prompt }
            
            for (index, hPrompt) in filteredHistory.enumerated() {
                newItems.append(LauncherItem(
                    id: "ai_task_\(agentID)_history_\(index)",
                    path: "ai_task_\(agentID)",
                    type: .aiTask(prompt: hPrompt, agentID: agentID),
                    name: hPrompt,
                    iconName: "clock.arrow.circlepath",
                    iconColor: .gray,
                    description: "History",
                    parametersHint: nil
                ))
            }
            
            self.items = newItems
            self.selectedIndex = 0
            return
        }

        let parts = searchText.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        let query = parts.first.map(String.init) ?? ""

        if query.isEmpty {
            for script in WorkspaceViewModel.shared.allScripts {
                newItems.append(LauncherItem(
                    id: "script_\(script.id)",
                    path: script.url.path,
                    type: .script(script),
                    name: script.displayName ?? script.name,
                    iconName: script.type.iconName,
                    iconColor: script.type.iconColor,
                    description: script.scriptDescription ?? script.url.path,
                    parametersHint: script.parametersHint
                ))
            }
            for app in WorkspaceViewModel.shared.applications {
                newItems.append(LauncherItem(
                    id: "app_\(app.id)",
                    path: app.url.path,
                    type: .application(app),
                    name: app.name,
                    appURL: app.url,
                    description: app.url.path
                ))
            }
        } else {
            let scripts = WorkspaceViewModel.shared.allScripts.filter {
                PinyinHelper.isMatch(text: $0.name, searchText: query) ||
                PinyinHelper.isMatch(text: $0.displayName ?? "", searchText: query)
            }
            for script in scripts {
                newItems.append(LauncherItem(
                    id: "script_\(script.id)",
                    path: script.url.path,
                    type: .script(script),
                    name: script.displayName ?? script.name,
                    iconName: script.type.iconName,
                    iconColor: script.type.iconColor,
                    description: script.scriptDescription ?? script.url.path,
                    parametersHint: script.parametersHint
                ))
            }

            let apps = WorkspaceViewModel.shared.applications.filter {
                PinyinHelper.isMatch(text: $0.name, searchText: query)
            }
            for app in apps {
                newItems.append(LauncherItem(
                    id: "app_\(app.id)",
                    path: app.url.path,
                    type: .application(app),
                    name: app.name,
                    appURL: app.url,
                    description: app.url.path
                ))
            }
        }

        let frequentDict = AppStateManager.shared.frequentScripts
        newItems.sort { a, b in
            let countA = frequentDict[a.path] ?? 0
            let countB = frequentDict[b.path] ?? 0
            if countA != countB {
                return countA > countB
            }
            return a.name.localizedStandardCompare(b.name) == .orderedAscending
        }

        self.items = newItems

        if self.selectedIndex >= newItems.count {
            self.selectedIndex = max(0, newItems.count - 1)
        }
    }
    
    public func moveUp() {
        if selectedIndex > 0 {
            selectedIndex -= 1
        }
    }
    
    public func moveDown() {
        if selectedIndex < items.count - 1 {
            selectedIndex += 1
        }
    }
    
    public func autoFill() {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        
        let fillText: String
        switch item.type {
        case .script(let script):
            fillText = script.name + " "
        case .application(let app):
            fillText = app.name + " "
        case .aiTask(let prompt, let agentID):
            if let agent = AppStateManager.shared.aiAgents.first(where: { $0.id.uuidString == agentID }) {
                fillText = agent.prefix + prompt
            } else {
                fillText = prompt
            }
        }
        
        if !searchText.hasPrefix(fillText) {
            searchText = fillText
            selectedIndex = 0
        }
    }
    
    /// 架构级增强：轻量级 Shell 参数解析器，正确处理单引号、双引号和转义字符
    private func parseArguments(_ string: String) -> [String] {
        var args: [String] = []
        var currentArg = ""
        var inQuotes = false
        var quoteChar: Character? = nil
        var escapeNext = false
        
        for char in string {
            if escapeNext {
                currentArg.append(char)
                escapeNext = false
            } else if char == "\\" {
                escapeNext = true
            } else if inQuotes {
                if char == quoteChar {
                    inQuotes = false
                    quoteChar = nil
                } else {
                    currentArg.append(char)
                }
            } else {
                if char == "\"" || char == "'" {
                    inQuotes = true
                    quoteChar = char
                } else if char.isWhitespace {
                    if !currentArg.isEmpty {
                        args.append(currentArg)
                        currentArg = ""
                    }
                } else {
                    currentArg.append(char)
                }
            }
        }
        if !currentArg.isEmpty {
            args.append(currentArg)
        }
        return args
    }
    
    public func executeSelected(inTerminal: Bool = true) {
        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let item = items[selectedIndex]
        
        switch item.type {
        case .application(let app):
            LauncherWindowManager.shared.hide()
            AppStateManager.shared.recordScriptRun(app.url.path)
            ApplicationManager.shared.launchApplication(at: app.url)
            
        case .script(let script):
            LauncherWindowManager.shared.hide()
            AppStateManager.shared.recordScriptRun(script.url.path)
            let parts = searchText.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
            let argsString = parts.count > 1 ? String(parts[1]) : ""
            
            // 架构级修复：使用健壮的参数解析器替代脆弱的 split
            let arguments = parseArguments(argsString)
            
            if inTerminal {
                executeInSystemTerminal(script: script, arguments: arguments)
            } else {
                executeInApp(script: script, arguments: arguments)
            }
            
        case .aiTask(let prompt, let agentID):
            guard !prompt.isEmpty else { return }
            executeAITaskInline(prompt: prompt, agentID: agentID)
        }
    }
    
    /// 架构级重构：彻底抛弃本地 CLI 调用，直接通过 API 网关与 AI Agent 通信
    private func executeAITaskInline(prompt: String, agentID: String) {
        let appState = AppStateManager.shared
        
        guard let agent = appState.aiAgents.first(where: { $0.id.uuidString == agentID }) else { return }
        
        // 架构级增强：执行任务时，将 Prompt 保存到历史记录中
        appState.addAITaskHistory(agentID: agentID, prompt: prompt)
        
        // 架构级修复：严格遵循用户配置的 AI 专属工作区优先级
        var workspace = appState.aiWorkspacePath.trimmingCharacters(in: .whitespaces)
        if workspace.isEmpty {
            workspace = WorkspaceViewModel.shared.selectedWorkspacePath ?? ""
        }
        if workspace.isEmpty {
            workspace = "~/temp_projects"
        }
        
        // 创建独立的执行会话
        let session = ExecutionSession(scriptName: "AI Task (\(agent.name))")
        
        // 架构级修复：将 AI 任务加入全局 TerminalManager，确保其在后台持久化运行
        TerminalManager.shared.addSession(session)
        
        self.currentSession = session
        
        session.state = .running
        session.appendLog(Constants.UI.processStarted("AI Agent: \(agent.name)"), type: .info)
        session.appendLog("Workspace: \(workspace)", type: .info)
        session.appendLog("Prompt: \(prompt)\n", type: .info)
        session.appendLog("----------------------------------------\n", type: .info)
        
        // 委托给重构后的 AIAgentService 发起 API 请求
        let task = AIAgentService.shared.executeAITask(prompt: prompt, agentID: agentID, workspace: workspace, session: session)
        session.task = task
        
        // 监听状态变化，驱动悬浮窗更新
        session.$state.sink { _ in
            DispatchQueue.main.async {
                TerminalManager.shared.updateWidgetState()
            }
        }.store(in: &cancellables)
    }
    
    public func closeCurrentSession() {
        // 架构级修复：不再调用 currentSession?.stop()，允许任务在后台继续运行
        currentSession = nil
        filterItems()
    }
    
    private func executeInApp(script: ScriptItem, arguments: [String]) {
        LauncherWindowManager.shared.activateMainWindow()
        
        let session = ExecutionSession(scriptName: script.name)
        TerminalManager.shared.addSession(session)
        
        session.state = .running
        session.appendLog(Constants.UI.processStarted(script.name), type: .info)
        if !arguments.isEmpty {
            session.appendLog("Arguments: \(arguments.joined(separator: " "))", type: .info)
        }
        session.appendLog("----------------------------------------", type: .info)
        
        do {
            let envs = AppStateManager.shared.getEnvironmentVariables(for: script.url.path)
            let task = try ScriptExecutionService.shared.execute(
                item: script,
                arguments: arguments,
                environmentVariables: envs,
                session: session
            )
            session.task = task
        } catch {
            session.appendLog(Constants.UI.executionError(error.localizedDescription), type: .error)
            session.state = .failure
        }
    }
    
    private func executeInSystemTerminal(script: ScriptItem, arguments: [String]) {
        let appState = AppStateManager.shared
        let pythonExec = appState.pythonPath.isEmpty ? "python3" : appState.pythonPath
        let nodeExec = appState.nodePath.isEmpty ? "node" : appState.nodePath
        let rubyExec = appState.rubyPath.isEmpty ? "ruby" : appState.rubyPath
        let shellExec = appState.defaultShell == "zsh" ? "/bin/zsh" : "/bin/bash"
        
        var actualArgs: [String] = []
        switch script.type {
        case .python: actualArgs = [pythonExec, "-u", script.url.path] + arguments
        case .node: actualArgs = [nodeExec, script.url.path] + arguments
        case .ruby: actualArgs = [rubyExec, script.url.path] + arguments
        case .bash: actualArgs = ["/bin/bash", script.url.path] + arguments // 架构级修复：强制 .sh 脚本使用 bash
        default: actualArgs = [shellExec, script.url.path] + arguments
        }
        
        let envs = appState.getEnvironmentVariables(for: script.url.path)
        var envPrefix = ""
        for env in envs where !env.name.isEmpty {
            envPrefix += "export \(env.name)=\(escapeForShell(env.value)) && "
        }
        
        let scriptDir = script.url.deletingLastPathComponent().path
        let cdCommand = "cd \(escapeForShell(scriptDir)) && "
        
        let commandString = actualArgs.map { escapeForShell($0) }.joined(separator: " ")
        
        // 架构级修复 1：移除暴力的 `clear; ` 命令。
        // 这样即使用户的脚本执行极快，终端屏幕上也会保留完整的执行命令和输出痕迹，避免产生“没有输入”的错觉。
        let fullCommand = cdCommand + envPrefix + commandString
        
        let appleScriptSafeCommand = fullCommand
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        
        let terminalApp = appState.terminalEmulator
        let terminalBundleID = terminalApp == "iTerm" ? "com.googlecode.iterm2" : "com.apple.Terminal"
        
        // 架构级防坑：前置校验目标终端应用是否安装，避免触发 FSFindFolder error=-43
        if NSWorkspace.shared.urlForApplication(withBundleIdentifier: terminalBundleID) == nil {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Application Not Found"
                alert.informativeText = "Could not find \(terminalApp). Please ensure it is installed on your system."
                alert.addButton(withTitle: Constants.UI.okButton)
                alert.alertStyle = .critical
                alert.runModal()
            }
            return
        }
        
        let appleScriptSource: String
        
        if terminalApp == "iTerm" {
            // 架构级修复 2：iTerm2 必须新建 Tab，绝不能向 current session 盲目写入，防止污染用户正在运行的进程
            appleScriptSource = """
            tell application "iTerm"
                activate
                if (count of windows) = 0 then
                    create window with default profile
                else
                    tell current window
                        create tab with default profile
                    end tell
                end if
                tell current window
                    tell current session
                        write text "\(appleScriptSafeCommand)"
                    end tell
                end tell
            end tell
            """
        } else {
            appleScriptSource = """
            tell application "Terminal"
                activate
                do script "\(appleScriptSafeCommand)"
            end tell
            """
        }
        
        print("[LauncherViewModel] Executing in \(terminalApp): \(fullCommand)")
        
        // 架构级修复 3：NSAppleScript 必须在主线程执行！
        // 在后台线程执行会导致 Apple Event 发送失败，且无法触发 macOS 的“自动化权限”弹窗，导致 Terminal 弹出但无命令输入。
        DispatchQueue.main.async {
            if let appleScript = NSAppleScript(source: appleScriptSource) {
                var error: NSDictionary?
                appleScript.executeAndReturnError(&error)
                if let err = error {
                    print("[LauncherViewModel] AppleScript Error: \(err)")
                    let errNum = err[NSAppleScript.errorNumber] as? Int ?? 0
                    
                    // 架构级修复：精准捕获 -1743 权限拒绝错误，提供保姆级引导
                    if errNum == -1743 {
                        let alert = NSAlert()
                        alert.messageText = Constants.UI.automationPermissionTitle
                        alert.informativeText = Constants.UI.automationPermissionDeniedMessage(terminalApp)
                        alert.addButton(withTitle: Constants.UI.openSystemSettingsButton)
                        alert.addButton(withTitle: Constants.UI.cancelButton)
                        alert.alertStyle = .warning
                        
                        if alert.runModal() == .alertFirstButtonReturn {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    } else {
                        let alert = NSAlert()
                        alert.messageText = "AppleScript Error"
                        alert.informativeText = "\(err[NSAppleScript.errorMessage] as? String ?? "Unknown error")\nCode: \(errNum)"
                        alert.addButton(withTitle: Constants.UI.okButton)
                        alert.alertStyle = .critical
                        alert.runModal()
                    }
                }
            }
        }
    }
    
    private func escapeForShell(_ string: String) -> String {
        return "'" + string.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}