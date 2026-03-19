// ScriptManager/ViewModels/ScriptDetailViewModel.swift
import Foundation
import Combine

@MainActor
public class ScriptDetailViewModel: ObservableObject {
    @Published public var currentItem: ScriptItem?
    @Published public var metadata: ScriptMetadata?
    
    // 动态表单数据绑定字典
    @Published public var stringValues:[String: String] = [:]
    @Published public var boolValues:[String: Bool] = [:]
    
    // 架构级增强：支持代码编辑与附加参数
    @Published public var scriptContent: String = ""
    @Published public var additionalArguments: String = ""
    
    // 架构级增强：支持环境变量配置
    @Published public var environmentVariables:[ScriptEnvironmentVariable] = []
    
    public init() {}
    
    /// 加载并解析选中的脚本
    public func load(item: ScriptItem) {
        self.currentItem = item
        self.metadata = nil
        self.stringValues.removeAll()
        self.boolValues.removeAll()
        self.scriptContent = ""
        self.additionalArguments = ""
        
        // 加载环境变量
        self.environmentVariables = AppStateManager.shared.getEnvironmentVariables(for: item.url.path)
        
        Task {
            do {
                // 1. 解析元数据
                let parsedMetadata = try await ScriptParserService.shared.parse(url: item.url)
                self.metadata = parsedMetadata
                
                // 2. 初始化表单默认值
                for param in parsedMetadata.parameters {
                    if param.type == .bool {
                        if let def = param.defaultValue, def.lowercased() == "true" {
                            self.boolValues[param.name] = true
                        } else {
                            self.boolValues[param.name] = false
                        }
                    } else if param.type == .choice {
                        self.stringValues[param.name] = param.defaultValue ?? param.options?.first ?? ""
                    } else {
                        self.stringValues[param.name] = param.defaultValue ?? ""
                    }
                }
                
                // 3. 读取脚本完整内容用于编辑器
                self.scriptContent = try WorkspaceManager.shared.readScript(url: item.url)
            } catch {
                print("❌ 解析脚本失败: \(error.localizedDescription)")
            }
        }
    }
    
    /// 保存脚本内容和环境变量，并实时更新 UI 元数据
    public func saveScript() {
        guard let item = currentItem else { return }
        do {
            try WorkspaceManager.shared.saveScript(url: item.url, content: scriptContent)
            AppStateManager.shared.saveEnvironmentVariables(for: item.url.path, variables: environmentVariables)
            
            // 保存后重新解析元数据，实现所见即所得的 UI 实时更新
            Task {
                let parsedMetadata = try await ScriptParserService.shared.parse(url: item.url)
                self.metadata = parsedMetadata
                
                // 架构级增强：为新添加的参数初始化默认值，防止 UI 绑定异常
                for param in parsedMetadata.parameters {
                    if param.type == .bool {
                        if self.boolValues[param.name] == nil {
                            self.boolValues[param.name] = (param.defaultValue?.lowercased() == "true")
                        }
                    } else {
                        if self.stringValues[param.name] == nil {
                            if param.type == .choice {
                                self.stringValues[param.name] = param.defaultValue ?? param.options?.first ?? ""
                            } else {
                                self.stringValues[param.name] = param.defaultValue ?? ""
                            }
                        }
                    }
                }
            }
        } catch {
            print("❌ 保存脚本失败: \(error.localizedDescription)")
        }
    }
    
    /// 组装参数并委托给 TerminalManager 执行脚本
    public func runScript() {
        guard let item = currentItem, let meta = metadata else { return }
        
        // 1. 必填项校验拦截
        for param in meta.parameters where param.isRequired {
            if param.type == .string || param.type == .path || param.type == .choice {
                let val = stringValues[param.name] ?? ""
                if val.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    print("⚠️ [校验失败]: 参数 '\(param.name)' 是必填项，请填写后重试。")
                    return
                }
            }
        }
        
        // 2. 按照元数据定义的顺序组装参数
        var arguments: [String] = []
        for param in meta.parameters {
            if param.type == .bool {
                let isTrue = boolValues[param.name] ?? false
                if isTrue {
                    arguments.append("--\(param.name)")
                }
            } else {
                let val = stringValues[param.name] ?? ""
                if !val.isEmpty {
                    arguments.append(val)
                }
            }
        }
        
        // 3. 附加额外参数
        let extraArgs = additionalArguments.split(separator: " ").map { String($0) }
        arguments.append(contentsOf: extraArgs)
        
        // 4. 记录运行次数并保存环境变量
        AppStateManager.shared.recordScriptRun(item.url.path)
        AppStateManager.shared.saveEnvironmentVariables(for: item.url.path, variables: environmentVariables)
        
        // 5. 创建独立的执行会话并加入终端管理器
        let session = ExecutionSession(scriptName: item.name)
        TerminalManager.shared.addSession(session)
        
        session.state = .running
        session.appendLog(Constants.UI.processStarted(item.name), type: .info)
        session.appendLog("----------------------------------------", type: .info)
        
        do {
            let task = try ScriptExecutionService.shared.execute(item: item, arguments: arguments, environmentVariables: environmentVariables, session: session)
            session.task = task
        } catch {
            session.appendLog(Constants.UI.executionError(error.localizedDescription), type: .error)
            session.state = .failure
        }
    }
}