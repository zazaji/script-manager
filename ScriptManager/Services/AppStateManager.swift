// ScriptManager/Services/AppStateManager.swift
import Foundation
import Combine

/// 架构级增强：全局状态管理器，负责持久化常用工作区、常用脚本、自定义脚本、收藏脚本和环境变量
/// 引入 Security-Scoped Bookmarks 机制，彻底解决 Sandbox 权限问题
public class AppStateManager: ObservableObject {
    public static let shared = AppStateManager()
    
    @Published public var recentWorkspaces: [String] = []
    @Published public var frequentScripts:[String: Int] = [:]
    @Published public var customScripts: [String] = []
    @Published public var favoriteScripts: [String] = []
    
    // 存储每个脚本的环境变量配置
    @Published public var scriptEnvironments: [String:[ScriptEnvironmentVariable]] = [:]
    
    // 架构级增强：自定义执行环境路径
    @Published public var pythonPath: String = "" { didSet { saveState() } }
    @Published public var nodePath: String = "" { didSet { saveState() } }
    @Published public var rubyPath: String = "" { didSet { saveState() } }
    @Published public var envPath: String = "" { didSet { saveState() } }
    @Published public var defaultShell: String = "bash" { didSet { saveState() } }
    
    // 存储 Security-Scoped Bookmark Data
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
        
        if let envData = defaults.data(forKey: "scriptEnvironments"),
           let decoded = try? JSONDecoder().decode([String:[ScriptEnvironmentVariable]].self, from: envData) {
            scriptEnvironments = decoded
        }
        
        // 恢复所有书签的访问权限，突破沙盒限制
        for (path, data) in bookmarks {
            restoreAccess(for: path, with: data)
        }
    }
    
    /// 架构级防坑：改为 public，允许在视图消失等生命周期节点强制调用，并加入 synchronize 确保立即落盘
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
        
        if let encoded = try? JSONEncoder().encode(scriptEnvironments) {
            defaults.set(encoded, forKey: "scriptEnvironments")
        }
        
        // 强制立即同步到磁盘，防止 App 意外退出或快速关闭导致的数据丢失
        defaults.synchronize()
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
    
    // MARK: - Security-Scoped Bookmarks
    
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