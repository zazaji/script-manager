// ScriptManager/ViewModels/WorkspaceViewModel.swift
import Foundation
import AppKit
import Combine

@MainActor
public class WorkspaceViewModel: ObservableObject {
    // 架构级增强：升级为单例，供全局启动器共享数据，避免重复扫描
    public static let shared = WorkspaceViewModel()
    
    public enum SidebarTab {
        case frequent
        case custom
        case workspace
        case applications
    }
    
    @Published public var scripts: [ScriptItem] = []
    @Published public var customScriptItems: [ScriptItem] = []
    @Published public var frequentScriptItems: [ScriptItem] = []
    @Published public var applications: [ApplicationItem] = []
    
    @Published public var selectedWorkspacePath: String? = nil
    @Published public var searchText: String = ""
    
    // 统一管理选中项 ID (可以是脚本路径或应用路径)
    @Published public var selectedItemID: String? = nil
    
    @Published public var viewMode: ViewMode = .list
    @Published public var isShowingNewScriptSheet: Bool = false
    @Published public var currentTab: SidebarTab = .workspace
    
    private var cancellables = Set<AnyCancellable>()
    
    /// 过滤后的当前工作区脚本列表 (支持拼音、@Name、@Desc)
    public var filteredScripts: [ScriptItem] {
        filterItems(scripts)
    }
    
    /// 过滤后的自定义脚本列表
    public var filteredCustomScripts: [ScriptItem] {
        filterItems(customScriptItems)
    }
    
    /// 过滤后的常用脚本列表
    public var filteredFrequentScripts: [ScriptItem] {
        filterItems(frequentScriptItems)
    }
    
    /// 过滤后的应用列表
    public var filteredApplications: [ApplicationItem] {
        if searchText.isEmpty {
            return applications
        } else {
            return applications.filter { item in
                PinyinHelper.isMatch(
                    text: item.name,
                    searchText: searchText
                )
            }
        }
    }
    
    /// 内部通用过滤逻辑
    private func filterItems(_ items: [ScriptItem]) -> [ScriptItem] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { item in
                let matchFileName = PinyinHelper.isMatch(
                    text: item.name,
                    searchText: searchText
                )
                let matchDisplayName = PinyinHelper.isMatch(
                    text: item.displayName ?? "",
                    searchText: searchText
                )
                let matchDesc = PinyinHelper.isMatch(
                    text: item.scriptDescription ?? "",
                    searchText: searchText
                )
                
                return matchFileName || matchDisplayName || matchDesc
            }
        }
    }
    
    /// 聚合所有脚本，供详情页和启动器查找
    public var allScripts: [ScriptItem] {
        var all = scripts
        all.append(contentsOf: customScriptItems)
        all.append(contentsOf: frequentScriptItems)
        var unique = [String: ScriptItem]()
        for item in all {
            unique[item.id] = item
        }
        return Array(unique.values)
    }
    
    // 架构级增强：私有化 init，强制使用单例
    private init() {
        Task { @MainActor in
            loadCustomAndFrequentScripts()
            loadApplications()
            
            // 自动加载最近一次工作区，解决启动器在主界面显示前呼出时，工作区未加载的致命 Bug
            let appState = AppStateManager.shared
            if self.selectedWorkspacePath == nil,
               let first = appState.recentWorkspaces.first {
                self.selectedWorkspacePath = first
                WorkspaceManager.shared.startMonitoring(
                    url: URL(fileURLWithPath: first)
                )
                self.scanWorkspace(url: URL(fileURLWithPath: first))
            }
            
            setupBindings()
        }
    }
    
    private func setupBindings() {
        AppStateManager.shared.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.loadCustomAndFrequentScripts()
            }
            .store(in: &cancellables)
        
        WorkspaceManager.shared.workspaceChanged
            .debounce(
                for: .milliseconds(500),
                scheduler: RunLoop.main
            )
            .sink { [weak self] _ in
                self?.refresh()
            }
            .store(in: &cancellables)
            
        // 监听 Tab 切换，清空选中，避免跨 Tab 视觉混淆
        $currentTab
            .dropFirst()
            .sink { [weak self] _ in
                self?.selectedItemID = nil
            }
            .store(in: &cancellables)
    }
    
    public func loadCustomAndFrequentScripts() {
        let state = AppStateManager.shared
        self.customScriptItems = state.customScripts.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? 
                ScriptItem(url: url) : nil
        }
        self.frequentScriptItems = state.topFrequentScripts.compactMap { path in
            let url = URL(fileURLWithPath: path)
            return FileManager.default.fileExists(atPath: path) ? 
                ScriptItem(url: url) : nil
        }
    }
    
    public func loadApplications() {
        Task {
            let apps = await ApplicationManager.shared.scanApplications()
            self.applications = apps
        }
    }
    
    public func selectWorkspace() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.message = Constants.UI.selectWorkspaceButton
        
        if panel.runModal() == .OK, let url = panel.url {
            AppStateManager.shared.addWorkspace(url)
            self.selectedWorkspacePath = url.path
            WorkspaceManager.shared.startMonitoring(url: url)
            self.scanWorkspace(url: url)
        }
    }
    
    public func addCustomScript() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            AppStateManager.shared.addCustomScript(url)
        }
    }
    
    public func refresh() {
        if currentTab == .applications {
            loadApplications()
        } else if let path = selectedWorkspacePath {
            let url = URL(fileURLWithPath: path)
            scanWorkspace(url: url)
        }
    }
    
    public func createNewScript(
        name: String,
        type: ScriptType,
        content: String? = nil
    ) {
        guard let path = selectedWorkspacePath else { return }
        let workspaceURL = URL(fileURLWithPath: path)
        
        do {
            _ = try WorkspaceManager.shared.createScript(
                at: workspaceURL,
                name: name,
                type: type,
                content: content
            )
            refresh()
        } catch {
            print(
                "[WorkspaceViewModel] Create failed: "
                + error.localizedDescription
            )
        }
    }
    
    public func generateSamples() {
        if selectedWorkspacePath == nil {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.message = Constants.UI.selectWorkspaceButton
            
            if panel.runModal() == .OK, let url = panel.url {
                AppStateManager.shared.addWorkspace(url)
                self.selectedWorkspacePath = url.path
                WorkspaceManager.shared.startMonitoring(url: url)
                self.scanWorkspace(url: url)
                
                do {
                    try WorkspaceManager.shared.createSampleScripts(at: url)
                    self.refresh()
                } catch {
                    print("[WorkspaceViewModel] Samples failed: \(error)")
                }
            }
        } else {
            guard let path = selectedWorkspacePath else { return }
            let url = URL(fileURLWithPath: path)
            do {
                try WorkspaceManager.shared.createSampleScripts(at: url)
                self.refresh()
            } catch {
                print("[WorkspaceViewModel] Samples failed: \(error)")
            }
        }
    }
    
    public func deleteScript(_ script: ScriptItem) {
        let alert = NSAlert()
        alert.messageText = Constants.UI.deleteConfirmTitle
        alert.informativeText = Constants.UI.deleteConfirmMessage
        alert.addButton(withTitle: Constants.UI.deleteButton)
        alert.addButton(withTitle: Constants.UI.cancelButton)
        alert.alertStyle = .warning
        
        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try FileManager.default.removeItem(at: script.url)
                refresh()
            } catch {
                print(
                    "[WorkspaceViewModel] Delete failed: "
                    + error.localizedDescription
                )
            }
        }
    }
    
    private func scanWorkspace(url: URL) {
        let fileManager = FileManager.default
        var foundScripts: [ScriptItem] = []
        
        do {
            let contents = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: nil,
                options: .skipsHiddenFiles
            )
            let supportedExtensions = ["sh", "py", "js", "rb"]
            
            for fileURL in contents {
                let ext = fileURL.pathExtension.lowercased()
                if supportedExtensions.contains(ext) {
                    foundScripts.append(ScriptItem(url: fileURL))
                }
            }
            self.scripts = foundScripts.sorted(by: { $0.name < $1.name })
        } catch {
            print("[Scan Error]: Failed: \(error)")
        }
    }
}