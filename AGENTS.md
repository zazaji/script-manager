# AGENTS.md — ScriptManager 开发指南

本文件面向在本仓库工作的 AI 编码助手与开发者，说明目录结构、架构约定与开发原则。
修改代码前请先阅读「开发原则」与「必守的坑」，避免破坏既有架构。

## 项目概述

**ScriptManager** 是一个原生 macOS SwiftUI 应用，核心能力：

1. **脚本 GUI 化**：解析 Bash / Python / Node.js / Ruby 脚本中的 `@Param` 注释，自动生成参数表单并执行（支持 App 内 PTY 终端或唤起系统 Terminal/iTerm）
2. **快速启动器（Alfred 风格）**：全局快捷键 `Cmd+Space` 唤起浮动搜索栏，可搜脚本、应用、AI 任务，带独立刷新状态机
3. **公式计算**：启动器输入 `=`（含全角 `＝`）前缀即时求值——四则、幂 `^`/`**`、阶乘 `!`、百分比 `%`、隐式乘法、进制字面量 `0x/0b/0o`、角度符号 `°`、40+ 函数与常量、全角符号归一化；含单个未知数的表达式/方程自动数值求根（如 `x^2=4`、`-3800+300*((1+i)^18-1)/(i*(1+i)^18)=0`）；回车复制结果（浮层保持打开并就地显示"已复制"，Esc 或失焦关闭）
4. **AI Agent 集成**：按前缀路由（如输入 `/` 进入某 Agent），任务经 API 网关执行，日志实时落到终端会话与悬浮窗
5. **双语界面**：中文 / 英文运行时切换

应用**未沙盒**运行（需要完整磁盘访问 FDA），通过安全作用域书签持久化工作区授权。

## 目录结构

```
ScriptManager/                        # 仓库根目录
├── AGENTS.md / CLAUDE.md             # 本文件与 Claude Code 指南（内容需保持一致）
├── README.md / README_zh.md
├── ScriptManager.xcodeproj
├── ScriptManager.zip / temp/         # 归档产物，非源码，忽略
└── ScriptManager/                    # Xcode target 源码主目录
    ├── ScriptManagerApp.swift        # @main 入口；语言切换后用 .id() 强制重建视图树
    ├── Info.plist
    ├── Models/
    │   └── ScriptModels.swift        # ScriptItem / ScriptParameter / ScriptMetadata /
    │                                 # ExecutionSession / ScriptType / SidebarTab 等
    ├── Core/                         # 与 UI 无关的基础设施
    │   ├── Constants.swift           # ★ 所有用户可见文案集中在 Constants.UI，经 AppLanguageManager 本地化
    │   ├── AppLanguageManager.swift  # 中英双语运行时切换
    │   ├── GlobalHotkeyManager.swift # Carbon 全局快捷键（Cmd+Space 唤起启动器）
    │   ├── PermissionManager.swift   # FDA 多重探测（绕过 TCC 缓存问题）
    │   ├── PinyinHelper.swift        # 拼音搜索匹配（CFStringTransform）
    │   └── FormulaEvaluator.swift    # 启动器 = 前缀公式的纯函数求值器（递归下降解析、无状态、无 IO）
    ├── Services/                     # 系统能力封装（尽量无状态、可单例复用）
    │   ├── AppStateManager.swift     # UserDefaults 持久化：工作区书签、频次统计、AI Agent 配置、
    │   │                             #   AI 任务历史、环境变量、python/node/ruby 路径、终端选择
    │   ├── WorkspaceManager.swift    # 工作区目录监听、脚本文件创建
    │   ├── ScriptParserService.swift # @Param 注释 → ScriptParameter（async）
    │   ├── ScriptExecutionService.swift # PTY 执行：posix_openpt + grantpt + /usr/bin/script 包装
    │   ├── ApplicationManager.swift  # 扫描 /Applications、/System/Applications、~/Applications 并启动
    │   ├── LauncherWindowManager.swift # 启动器浮动窗口的显示/隐藏/主窗口激活
    │   ├── TaskWidgetManager.swift   # 悬浮任务窗管理
    │   └── AIAgentService.swift      # AI Agent API 网关调用
    ├── ViewModels/                   # ObservableObject，UI 的唯一数据出口
    │   ├── WorkspaceViewModel.shared # ★ 单一数据源：脚本列表、应用列表、4 个侧栏标签页
    │   ├── LauncherViewModel.shared  # 启动器：过滤、选中、执行、刷新状态机（LauncherRefreshState）
    │   ├── TerminalManager.shared    # 终端会话池（ExecutionSession），驱动悬浮 widget
    │   └── ScriptDetailViewModel.swift # 单脚本详情的表单/执行状态
    ├── Views/
    │   ├── MainContentView.swift     # NavigationSplitView 主框架
    │   └── Components/               # 一个功能组件一个文件，与同名功能对应
    │       ├── SidebarView.swift         # 侧栏 4 页：Frequent / Custom / Workspace / Applications
    │       ├── ScriptDetailView.swift / ScriptHeaderView.swift
    │       ├── DynamicFormView.swift     # @Param → 表单控件
    │       ├── CodeEditorView.swift / CustomTextView.swift
    │       ├── ConsoleTerminalView.swift / TerminalPanelView.swift
    │       ├── LauncherView.swift        # Cmd+Space 搜索栏（含刷新按钮三态）
    │       ├── SettingsView.swift / ShortcutRecorderView.swift
    │       ├── ApplicationListView.swift / ApplicationDetailView.swift
    │       ├── TaskWidgetView.swift       # 悬浮任务窗 UI
    │       ├── NewScriptView.swift
    │       └── SafeNSImage.swift          # NSImage 安全加载工具视图
    └── Resources/
        ├── en.lproj/Localizable.strings
        └── zh-Hans.lproj/Localizable.strings
```

## 架构与数据流

```
GlobalHotkey (Cmd+Space) ─► LauncherWindowManager ─► LauncherView ─► LauncherViewModel
                                                                        │ 订阅(Combine)
WorkspaceViewModel.shared ◄── WorkspaceManager(目录监听) ◄── 磁盘变更    │
        │  $scripts / $applications / $customScriptItems / $frequentScriptItems
        └──────────────► 自动触发 LauncherViewModel.filterItems()

执行链路：DynamicFormView → ScriptExecutionService(PTY) → ExecutionSession
         → TerminalManager(会话池) → ConsoleTerminalView / TaskWidgetView
AI 链路：  LauncherView 前缀匹配 → LauncherViewModel.executeAITaskInline
         → AIAgentService(API 网关) → ExecutionSession 日志
公式链路：LauncherView 前缀 = → LauncherViewModel.filterItems 内联求值
         → FormulaEvaluator(纯函数) → 回车复制结果到剪贴板（浮层保持打开，Esc/失焦关闭）
```

- **WorkspaceViewModel 是脚本与应用的唯一数据源**。任何视图/VM 需要这两类数据时，订阅它的
  `@Published` 属性，禁止自行扫描磁盘或手工轮询刷新。
- 启动器的刷新按钮（`LauncherViewModel.refreshData()`）调用 `WorkspaceViewModel.refreshAll()`
  同时重扫脚本与应用两条数据线——不要改回 `refresh()`，它只按主界面当前标签页二选一。

## 开发原则

1. **MVVM + 单例共享状态**：全局服务与 VM 一律 `static let shared`；View 只持有
   `@ObservedObject`/`@StateObject`，不直接碰文件系统与进程。
2. **单一数据源，事件驱动**：跨组件数据变化通过 `@Published` + Combine 订阅传播；
   不写手动的"通知 A 再让 B 刷新"式胶水代码。
3. **文案零硬编码**：所有用户可见字符串一律 `Constants.UI.xxx`；新增 key 必须**同时**
   写进 `en.lproj` 与 `zh-Hans.lproj` 的 Localizable.strings（`Constants.swift` 里给默认值）。
   纯英文的工具性 help 文案（如启动器内开发者按钮）可豁免。
4. **主线程纪律**：UI 与 `@Published` 赋值在主线程；重 IO（目录扫描）放
   `Task.detached`；`NSAppleScript` **必须**主线程执行（后台执行会静默失败且无法触发
   自动化授权弹窗）。
5. **表单绑定用局部 @State**：`DynamicFormView` 等文本输入场景先绑定局部 `@State` 再回写，
   防止 `@Published` 回流造成的输入竞争（既有修复，勿改为直绑）。
6. **执行链路保持可观测**：PTY 会话输出是事实记录——禁止在执行命令前插入 `clear`；
   sudo 密码交互依赖 `/usr/bin/script` 包装出的控制终端，不得绕过。
7. **注释讲约束不讲实现**：延续 `架构级修复/增强/防坑：` 注释风格，只写代码本身表达
   不了的"为什么/坑在哪"；合并后仍成立的约束才值得写。
8. **本地化 & 语言切换**：切换语言后依赖 `.id(languageManager.currentLanguage)` 重建
   视图树；新增视图如需响应语言切换，接入同一机制。
9. **失败要可见**：执行错误写入 `ExecutionSession`（state + log）；AppleScript 失败需
   针对 `-1743`（自动化权限被拒）给出打开系统设置的引导，其他错误弹窗展示原始信息。
10. **交付前必须编译**：改动后运行
    `xcodebuild -project ScriptManager.xcodeproj -scheme ScriptManager -configuration Debug build`
    确认 BUILD SUCCEEDED；运行时行为（热键、权限、终端）需在 Xcode Cmd+R 实测，
    AI 助手无法替代。

## 必守的坑（历史教训，违反会复发）

- **绝不在 `contentsOfDirectory` 的 `includingPropertiesForKeys` 里传 `.isApplicationKey`**：
  会触发 LaunchServices 同步阻塞，导致系统级卡死。应用扫描只按扩展名 `.app` 过滤。
- **`refresh()` 的标签页歧义**：`WorkspaceViewModel.refresh()` 依据 `currentTab` 只刷新
  一侧数据；需要"全量刷新"时用 `WorkspaceViewModel.refreshAll()`。
- **启动器数据就绪门闩**：`LauncherViewModel.isDataReady` 防止启动早期空列表闪烁；
  新增数据源订阅时保持该语义。
- **异步回调里的 self**：Combine sink、Task 中注意 `[weak self]`，ViewModel 是单例
  生命周期与 App 相同，但订阅仍可能被重复创建，`cancellables` 必须接住。
- **权限弹窗只出现一次**：FDA / 自动化权限的探测与引导逻辑集中在 PermissionManager 与
  LauncherViewModel 的 AppleScript 错误处理里，不要在别处重复弹窗。

## 新增代码的落位

| 要加的东西 | 放哪里 |
|---|---|
| 数据模型 / 枚举 | `Models/ScriptModels.swift`（或同目录新文件） |
| 系统能力（扫描、执行、API） | `Services/`，单例 + 无 UI 依赖 |
| 界面状态机 | `ViewModels/`，`@Published` 暴露状态 |
| UI 组件 | `Views/Components/`，一组件一文件 |
| 用户可见文案 | `Constants.UI` + 两个 .strings 同步加 key |
| 全局快捷键 / 权限探测 | `Core/` 既有管理器，勿另起炉灶 |

## 提交约定

- 提交信息用 `type: summary`（参考 git log：`docs:`、`feat:`、`fix:`）。
- 涉及 UI 行为变化的提交，在提交说明中写明验证方式（如何手动复现）。
