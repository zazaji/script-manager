// ScriptManager/Services/AIAgentService.swift
import Foundation

/// 架构级增强：基于 URLSession 的流式 API 任务封装，实现优雅的取消与多轮对话状态管理
public class APIExecutionTask: ExecutionTaskProtocol {
    private var currentTask: Task<Void, Never>?
    private weak var session: ExecutionSession?
    
    private let agentConfig: AIAgentConfiguration
    
    // 核心：在内存中维护完整的对话上下文，实现真正的多轮交互
    private var messages: [[String: String]] = []
    private var systemPrompt: String = ""
    public private(set) var isCancelled = false
    
    init(agentConfig: AIAgentConfiguration, workspace: String, initialPrompt: String, session: ExecutionSession) {
        self.agentConfig = agentConfig
        self.session = session
        
        // 架构级增强：通过 System Prompt 优雅地将 Workspace 上下文注入给 Agent
        let expandedWorkspace = NSString(string: workspace).expandingTildeInPath
        self.systemPrompt = "You are an AI agent. Your current working directory for this task is: \(expandedWorkspace). Please ensure any file operations are performed within this directory unless specified otherwise."
        
        // 架构级修复：Anthropic API 要求 system prompt 作为独立字段，且 messages 必须是 user/assistant 交替
        if agentConfig.type == .anthropic {
            self.messages = [
                ["role": "user", "content": initialPrompt]
            ]
        } else {
            self.messages = [
                ["role": "system", "content": self.systemPrompt],
                ["role": "user", "content": initialPrompt]
            ]
        }
    }
    
    public func start() {
        sendRequest()
    }
    
    public func cancel() {
        isCancelled = true
        currentTask?.cancel()
        Task { @MainActor in
            session?.appendLog(Constants.UI.processTerminatedByUser, type: .error)
            session?.state = .failure
        }
    }
    
    public func sendInput(_ text: String) {
        guard !isCancelled else { return }
        
        // 将用户的后续输入追加到上下文中
        messages.append(["role": "user", "content": text])
        
        Task { @MainActor in
            session?.appendLog("\n", type: .output)
            session?.appendLog("❯ \(text)\n", type: .info)
            session?.state = .running
        }
        
        // 发起新一轮的 API 请求
        sendRequest()
    }
    
    private func sendRequest() {
        guard let url = URL(string: agentConfig.endpoint) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("text/event-stream", forHTTPHeaderField: "Accept")
        
        // 架构级增强：根据 API 类型智能组装 Headers 和 Body
        if agentConfig.type == .anthropic {
            request.addValue(agentConfig.apiKey, forHTTPHeaderField: "x-api-key")
            request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            
            let body: [String: Any] = [
                "model": agentConfig.name,
                "system": systemPrompt,
                "messages": messages,
                "stream": true,
                "max_tokens": 4096
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        } else {
            if !agentConfig.apiKey.trimmingCharacters(in: .whitespaces).isEmpty {
                request.addValue("Bearer \(agentConfig.apiKey)", forHTTPHeaderField: "Authorization")
            }
            let body: [String: Any] = [
                "model": agentConfig.name,
                "messages": messages,
                "stream": true
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }
        
        // 架构级规范：统一、严谨的请求日志打印，方便极客调试
        print("\n========== [AI AGENT API REQUEST] ==========")
        print("Agent: \(agentConfig.name) (\(agentConfig.type.rawValue))")
        print("URL: \(url.absoluteString)")
        print("Method: \(request.httpMethod ?? "POST")")
        print("Headers:")
        request.allHTTPHeaderFields?.forEach { key, value in
            if key.lowercased() == "authorization" || key.lowercased() == "x-api-key" {
                print("  \(key): ********")
            } else {
                print("  \(key): \(value)")
            }
        }
        if let bodyData = request.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
            print("Body: \(bodyStr)")
        }
        print("============================================\n")
        
        currentTask = Task {
            do {
                // 架构级增强：使用现代的 async/await 字节流 API，实现极致的内存效率
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        self.session?.appendLog("❌ Error: Invalid response type from server.\n", type: .error)
                        self.session?.state = .failure
                    }
                    return
                }
                
                print("\n========== [AI AGENT API RESPONSE] ==========")
                print("URL: \(url.absoluteString)")
                print("Status Code: \(httpResponse.statusCode)")
                print("============================================\n")
                
                // 拦截非 200 错误，并提取服务端返回的错误详情
                if httpResponse.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines {
                        errorBody += line + "\n"
                    }
                    await MainActor.run {
                        self.session?.appendLog("❌ HTTP Error \(httpResponse.statusCode): \(errorBody)\n", type: .error)
                        self.session?.state = .failure
                    }
                    return
                }
                
                var assistantReply = ""
                
                // 逐行解析 SSE 数据流
                for try await line in bytes.lines {
                    if isCancelled { break }
                    
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("data:") {
                        let jsonStr = String(trimmed.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        
                        // 忽略结束标识
                        if jsonStr == "[DONE]" { continue }
                        
                        if let data = jsonStr.data(using: .utf8),
                           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                            
                            // 架构级增强：根据 API 类型智能解析 SSE 结构
                            if agentConfig.type == .anthropic {
                                if let type = json["type"] as? String, type == "content_block_delta",
                                   let delta = json["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    assistantReply += text
                                    await MainActor.run {
                                        self.session?.appendLog(text, type: .output)
                                    }
                                }
                            } else {
                                if let choices = json["choices"] as? [[String: Any]],
                                   let first = choices.first,
                                   let delta = first["delta"] as? [String: Any],
                                   let content = delta["content"] as? String {
                                    assistantReply += content
                                    await MainActor.run {
                                        self.session?.appendLog(content, type: .output)
                                    }
                                }
                            }
                        }
                    }
                }
                
                // 任务自然结束，将助手的回复追加到上下文中，并等待用户的下一次输入
                if !isCancelled {
                    self.messages.append(["role": "assistant", "content": assistantReply])
                    await MainActor.run {
                        self.session?.appendLog("\n\n✅ [Waiting for input...]\n", type: .info)
                        self.session?.state = .success
                    }
                }
                
            } catch is CancellationError {
                // 任务被用户主动取消，静默处理
            } catch {
                // 拦截网络异常
                if !self.isCancelled {
                    await MainActor.run {
                        self.session?.appendLog("\n❌ Request failed: \(error.localizedDescription)\n", type: .error)
                        self.session?.state = .failure
                    }
                }
            }
        }
    }
}

/// 架构级增强：空任务占位符，用于处理配置错误等前置拦截场景
public class DummyExecutionTask: ExecutionTaskProtocol {
    public func cancel() {}
    public func sendInput(_ text: String) {}
}

/// 架构级重构：彻底抛弃脆弱的本地 CLI 调用，全面拥抱标准的 OpenAI 兼容 API 网关
/// 实现跨平台、零乱码、高性能的 AI Agent 交互体验
public class AIAgentService {
    public static let shared = AIAgentService()
    private init() {}
    
    /// 向指定的 AI Agent 网关发送流式请求
    /// - Parameters:
    ///   - prompt: 用户的自然语言指令
    ///   - agentID: 动态 Agent 的唯一标识符
    ///   - workspace: 独立的工作区路径
    ///   - session: 绑定的执行会话，用于实时渲染日志
    /// - Returns: 遵循 ExecutionTaskProtocol 的任务对象，支持随时取消和多轮对话
    public func executeAITask(prompt: String, agentID: String, workspace: String, session: ExecutionSession) -> ExecutionTaskProtocol {
        let appState = AppStateManager.shared
        
        // 1. 动态路由：根据 Agent ID 提取配置
        guard let agent = appState.aiAgents.first(where: { $0.id.uuidString == agentID }) else {
            Task { @MainActor in
                session.appendLog("❌ Error: AI Agent configuration not found.\n", type: .error)
                session.state = .failure
            }
            return DummyExecutionTask()
        }
        
        let endpoint = agent.endpoint
        let agentName = agent.name
        
        // 2. 前置校验：拦截无效配置
        if endpoint.trimmingCharacters(in: .whitespaces).isEmpty {
            Task { @MainActor in
                session.appendLog("❌ Error: API Endpoint is not configured for \(agentName).\n", type: .error)
                session.state = .failure
            }
            return DummyExecutionTask()
        }
        
        guard URL(string: endpoint) != nil else {
            Task { @MainActor in
                session.appendLog("❌ Error: Invalid API Endpoint URL: \(endpoint)\n", type: .error)
                session.state = .failure
            }
            return DummyExecutionTask()
        }
        
        // 3. 创建并启动 API 任务
        let apiTask = APIExecutionTask(
            agentConfig: agent,
            workspace: workspace,
            initialPrompt: prompt,
            session: session
        )
        
        apiTask.start()
        return apiTask
    }
}