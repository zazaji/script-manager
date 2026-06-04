// ScriptManager/Services/ScriptExecutionService.swift
import Foundation
import Darwin

public class ScriptExecutionTask: ExecutionTaskProtocol {
    private let process: Process
    private let masterHandle: FileHandle?
    private let stdinPipe: Pipe?
    
    init(process: Process, masterHandle: FileHandle?, stdinPipe: Pipe?) {
        self.process = process
        self.masterHandle = masterHandle
        self.stdinPipe = stdinPipe
    }
    
    public func cancel() {
        if process.isRunning {
            process.terminate()
        }
    }
    
    public func sendInput(_ text: String) {
        guard let data = (text + "\n").data(using: .utf8) else { return }
        do {
            if let master = masterHandle {
                try master.write(contentsOf: data)
            } else if let pipe = stdinPipe {
                try pipe.fileHandleForWriting.write(contentsOf: data)
            }
        } catch {
            print("[ExecutionTask] Input Error: \(error.localizedDescription)")
        }
    }
}

public class ScriptExecutionService {
    public static let shared = ScriptExecutionService()
    private init() {}
    
    public func execute(item: ScriptItem, 
                        arguments: [String], 
                        environmentVariables: [ScriptEnvironmentVariable], 
                        session: ExecutionSession) throws -> ScriptExecutionTask {
        
        let process = Process()
        var masterHandle: FileHandle?
        var slaveHandle: FileHandle?
        var stdinPipe: Pipe?
        
        let masterFD = posix_openpt(O_RDWR | O_NOCTTY)
        if masterFD != -1 {
            if grantpt(masterFD) == 0 && unlockpt(masterFD) == 0 {
                if let slavePathPtr = ptsname(masterFD) {
                    let slaveFD = open(slavePathPtr, O_RDWR | O_NOCTTY)
                    if slaveFD != -1 {
                        masterHandle = FileHandle(fileDescriptor: masterFD, closeOnDealloc: true)
                        slaveHandle = FileHandle(fileDescriptor: slaveFD, closeOnDealloc: true)
                        process.standardInput = slaveHandle
                        process.standardOutput = slaveHandle
                        process.standardError = slaveHandle
                    }
                }
            }
        }
        
        if masterHandle == nil {
            stdinPipe = Pipe()
            process.standardInput = stdinPipe
            process.standardOutput = Pipe()
            process.standardError = Pipe()
        }

        let appState = AppStateManager.shared
        var env = ProcessInfo.processInfo.environment
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:\(env["PATH"] ?? "")"
        env["TERM"] = "xterm-256color"
        env["LANG"] = "en_US.UTF-8"
        for v in environmentVariables where !v.name.isEmpty { env[v.name] = v.value }
        process.environment = env
        
        let shellExec = appState.defaultShell == "zsh" ? "/bin/zsh" : "/bin/bash"
        let pythonExec = appState.pythonPath.isEmpty ? "python3" : appState.pythonPath
        let nodeExec = appState.nodePath.isEmpty ? "node" : appState.nodePath
        let rubyExec = appState.rubyPath.isEmpty ? "ruby" : appState.rubyPath
        
        var actualArgs: [String] = []
        switch item.type {
        case .python: actualArgs = [pythonExec, "-u", item.url.path] + arguments
        case .node: actualArgs = [nodeExec, item.url.path] + arguments
        case .ruby: actualArgs = [rubyExec, item.url.path] + arguments
        case .bash: actualArgs = ["/bin/bash", item.url.path] + arguments // 架构级修复：强制 .sh 脚本使用 bash，无视 defaultShell
        default: actualArgs = [shellExec, item.url.path] + arguments
        }

        let envPath = appState.envPath.trimmingCharacters(in: .whitespaces)
        
        // 架构级修复：严格隔离 bash 和 zsh 的配置文件加载，防止语法不兼容导致脚本直接崩溃
        let wrapperScript: String
        if shellExec.hasSuffix("zsh") {
            wrapperScript = """
            if [ -f ~/.zshrc ]; then source ~/.zshrc >/dev/null 2>&1; fi
            \(envPath.isEmpty ? "" : "if [ -f \"\(envPath)\" ]; then source \"\(envPath)\" >/dev/null 2>&1; fi")
            exec "$@"
            """
        } else {
            wrapperScript = """
            if [ -f ~/.bash_profile ]; then source ~/.bash_profile >/dev/null 2>&1; fi
            if [ -f ~/.bashrc ]; then source ~/.bashrc >/dev/null 2>&1; fi
            \(envPath.isEmpty ? "" : "if [ -f \"\(envPath)\" ]; then source \"\(envPath)\" >/dev/null 2>&1; fi")
            exec "$@"
            """
        }
        
        process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
        
        var finalArgs: [String] = ["-q", "/dev/null", shellExec, "-c", wrapperScript, "--"]
        finalArgs.append(contentsOf: actualArgs)
        
        process.arguments = finalArgs

        print("\n========== [SCRIPT EXECUTION REQUEST] ==========")
        print("URL: \(item.url.path)")
        print("Shell: \(shellExec)")
        print("Headers (Env):")
        env.filter { $0.key == "TERM" || $0.key == "PATH" || 
                    environmentVariables.map { $0.name }.contains($0.key) }
           .forEach { print("  \($0.key): \($0.value)") }
        print("Body (Args): \(actualArgs.joined(separator: " "))")
        print("Wrapped via: /usr/bin/script (Provides Controlling Terminal for sudo)")
        print("================================================\n")

        process.terminationHandler = { [weak session] p in
            let status = p.terminationStatus
            print("\n========== [SCRIPT EXECUTION RESPONSE] ==========")
            print("URL: \(item.url.path)")
            print("Exit Code: \(status)")
            print("================================================\n")
            
            Task { @MainActor in
                session?.state = status == 0 ? .success : .failure
                session?.appendLog(status == 0 ? 
                    Constants.UI.processFinishedSuccess : 
                    Constants.UI.processFinishedFailure(String(status)), type: status == 0 ? .info : .error)
                
                // 架构级增强：进程自然结束时，触发垃圾回收清理临时文件
                session?.cleanupTempFile()
            }
            try? masterHandle?.close()
            try? slaveHandle?.close()
        }

        try process.run()
        try? slaveHandle?.close()

        let outputHandle = masterHandle ?? (process.standardOutput as! Pipe).fileHandleForReading
        outputHandle.readabilityHandler = { h in
            let data = h.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                let clean = str.strippingANSI().replacingOccurrences(of: "\r\n", with: "\n")
                Task { @MainActor in session.appendLog(clean, type: .output) }
            }
        }

        return ScriptExecutionTask(process: process, 
                                 masterHandle: masterHandle, 
                                 stdinPipe: stdinPipe)
    }
}

extension String {
    func strippingANSI() -> String {
        var result = self
        
        // 架构级修复：全面增强 ANSI 过滤，彻底解决 opencode 等 TUI 工具输出乱码的问题
        
        // 1. 过滤 OSC 序列 (Operating System Command): ESC ] ... BEL 或 ESC ] ... ESC \
        // 例如: ]10;?  ]11;?  ]1337;Capabilities \
        let oscPattern = "\u{001B}\\][^\u{0007}\u{001B}]*(?:\u{0007}|\u{001B}\\\\)"
        if let regex = try? NSRegularExpression(pattern: oscPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        }
        
        // 2. 过滤 CSI 序列 (Control Sequence Introducer): ESC [ ... [a-zA-Z]
        // 这会过滤掉颜色、光标移动、清屏等
        let csiPattern = "\u{001B}\\[[0-9;?]*[a-zA-Z]"
        if let regex = try? NSRegularExpression(pattern: csiPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        }
        
        // 3. 过滤其他简单的 ESC 序列，如 ESC = (Application Keypad), ESC > (Normal Keypad)
        let simpleEscPattern = "\u{001B}[=>]"
        if let regex = try? NSRegularExpression(pattern: simpleEscPattern) {
            result = regex.stringByReplacingMatches(in: result, range: NSRange(location: 0, length: result.utf16.count), withTemplate: "")
        }
        
        // 4. 过滤掉孤立的 ESC 字符 (如果还有残留)
        result = result.replacingOccurrences(of: "\u{001B}", with: "")
        
        return result
    }
}