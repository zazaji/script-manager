// ScriptManager/ViewModels/TerminalManager.swift
import Foundation
import Combine

/// 架构级增强：全局终端管理器，负责调度和维护多个 ExecutionSession
@MainActor
public class TerminalManager: ObservableObject {
    public static let shared = TerminalManager()
    
    @Published public var sessions: [ExecutionSession] = []
    @Published public var selectedSessionID: UUID?
    @Published public var isPanelVisible: Bool = false
    
    private init() {}
    
    /// 添加一个新的终端会话并自动展开面板
    public func addSession(_ session: ExecutionSession) {
        sessions.append(session)
        selectedSessionID = session.id
        isPanelVisible = true
    }
    
    /// 移除指定的终端会话
    public func removeSession(id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].stop()
            sessions.remove(at: index)
        }
        
        if selectedSessionID == id {
            selectedSessionID = sessions.last?.id
        }
        
        if sessions.isEmpty {
            isPanelVisible = false
        }
    }
    
    /// 切换终端面板的可见性
    public func togglePanel() {
        isPanelVisible.toggle()
    }
}
