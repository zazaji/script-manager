// ScriptManager/ViewModels/TerminalManager.swift
import Foundation
import Combine

@MainActor
public class TerminalManager: ObservableObject {
    public static let shared = TerminalManager()
    
    @Published public var sessions: [ExecutionSession] = []
    @Published public var selectedSessionID: UUID?
    @Published public var isPanelVisible: Bool = false
    
    private var sessionCancellables = [UUID: AnyCancellable]()
    
    private init() {}
    
    public func addSession(_ session: ExecutionSession) {
        sessions.append(session)
        selectedSessionID = session.id
        isPanelVisible = true
        
        sessionCancellables[session.id] = session.$state.sink { [weak self] _ in
            DispatchQueue.main.async {
                self?.updateWidgetState()
            }
        }
        updateWidgetState()
    }
    
    public func removeSession(id: UUID) {
        if let index = sessions.firstIndex(where: { $0.id == id }) {
            sessions[index].stop()
            sessions.remove(at: index)
        }
        sessionCancellables.removeValue(forKey: id)
        
        if selectedSessionID == id {
            selectedSessionID = sessions.last?.id
        }
        if sessions.isEmpty {
            isPanelVisible = false
        }
        updateWidgetState()
    }
    
    public func closeAllSessions() {
        for session in sessions {
            session.stop()
        }
        sessions.removeAll()
        sessionCancellables.removeAll()
        
        selectedSessionID = nil
        isPanelVisible = false
        updateWidgetState()
    }
    
    public func closeOtherSessions(than id: UUID) {
        let toRemove = sessions.filter { $0.id != id }
        for session in toRemove {
            session.stop()
            sessionCancellables.removeValue(forKey: session.id)
        }
        sessions.removeAll { $0.id != id }
        selectedSessionID = id
        updateWidgetState()
    }
    
    public func togglePanel() {
        isPanelVisible.toggle()
    }
    
    /// 架构级增强：计算全局任务状态，并驱动 TaskWidgetManager
    /// 包含智能抑制逻辑：如果启动器正在显示内联终端，则隐藏全局悬浮窗
    public func updateWidgetState() {
        // 1. 智能抑制检查 (Intelligent Suppression)
        let isLauncherVisible = LauncherWindowManager.shared.isVisible
        let isInlineSessionActive = LauncherViewModel.shared.currentSession != nil
        
        if isLauncherVisible && isInlineSessionActive {
            TaskWidgetManager.shared.updateState(.hidden)
            return
        }
        
        // 2. 正常状态计算
        let runningSessions = sessions.filter { $0.state == .running }
        
        // 包含启动器内联的 Session（如果它在后台运行）
        var allRunning = runningSessions
        if let inlineSession = LauncherViewModel.shared.currentSession, inlineSession.state == .running {
            if !allRunning.contains(where: { $0.id == inlineSession.id }) {
                allRunning.append(inlineSession)
            }
        }
        
        if let firstRunning = allRunning.last {
            // 架构级增强：传递 session 实例，供悬浮窗实时读取日志
            TaskWidgetManager.shared.updateState(.running(firstRunning))
        } else {
            // 检查是否有刚完成的任务
            var lastFinished: ExecutionSession? = sessions.last(where: { $0.state == .success || $0.state == .failure })
            
            if let inlineSession = LauncherViewModel.shared.currentSession, 
               (inlineSession.state == .success || inlineSession.state == .failure) {
                lastFinished = inlineSession
            }
            
            if let finished = lastFinished {
                let isSuccess = finished.state == .success
                TaskWidgetManager.shared.updateState(isSuccess ? .success(finished.scriptName) : .failure(finished.scriptName))
            } else {
                TaskWidgetManager.shared.updateState(.hidden)
            }
        }
    }
}