// ScriptManager/ScriptManagerApp.swift
import SwiftUI

@main
struct ScriptManagerApp: App {
    @AppStorage("appTheme") private var appTheme: String = "system"
    
    // 架构级防坑：使用 @ObservedObject 观察单例，而不是 @StateObject
    @ObservedObject private var languageManager = AppLanguageManager.shared

    var body: some Scene {
        WindowGroup {
            MainContentView()
                .preferredColorScheme(colorScheme)
                // 架构级增强：注入全局语言环境，实现即时生效
                .environment(\.locale, Locale(identifier: languageManager.currentLanguage))
                .id(languageManager.currentLanguage) // 强制刷新视图树
                // 架构级修复：拉高全局最小尺寸底线 (1000)，为 Sidebar(240) + 配置(380) + 代码(380) 留出充裕物理空间
                .frame(minWidth: 1000, idealWidth: 1200, minHeight: 700, idealHeight: 800)
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            SidebarCommands()
        }
    }
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }
}

struct PermissionDeniedView: View {
    var checkAction: () -> Void
    @State private var showTroubleshooting: Bool = false
    @State private var showCopiedToast: Bool = false
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            // 增加关闭按钮，适配 Sheet 模式
            HStack {
                Spacer()
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            
            if PermissionManager.shared.isSandboxed {
                // 沙盒警告视图
                Image(systemName: "exclamationmark.triangle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 64)
                    .foregroundColor(.orange)
                
                Text(Constants.UI.sandboxWarningTitle)
                    .font(.title)
                    .bold()
                
                Text(Constants.UI.sandboxWarningMessage)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    .lineSpacing(4)
            } else {
                // FDA 引导视图
                Image(systemName: "lock.shield.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 64, height: 72)
                    .foregroundColor(.red)
                
                Text(Constants.UI.permissionDeniedTitle)
                    .font(.title)
                    .bold()
                
                Text(Constants.UI.permissionDeniedMessage)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 32)
                    
                VStack(spacing: 8) {
                    Text(Constants.UI.fdaGuideMessage)
                        .font(.callout)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 32)
                }
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal, 32)
                
                HStack(spacing: 20) {
                    Button(action: {
                        PermissionManager.shared.revealAppInFinder()
                    }) {
                        HStack {
                            Image(systemName: "magnifyingglass")
                            Text(Constants.UI.revealAppInFinderButton)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: {
                        PermissionManager.shared.openSystemSettingsForFDA()
                    }) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                            Text(Constants.UI.openSystemSettingsButton)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.top, 4)
                
                // 架构级防坑：TCC 故障排查折叠面板
                DisclosureGroup(isExpanded: $showTroubleshooting) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(Constants.UI.tccBugDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        
                        HStack {
                            Text("1. " + Constants.UI.tccBugStep1)
                                .font(.caption)
                                .bold()
                            Spacer()
                        }
                        
                        HStack {
                            Text("2. " + Constants.UI.tccBugStep2)
                                .font(.caption)
                                .bold()
                            
                            Button(action: {
                                PermissionManager.shared.copyTCCResetCommand()
                                withAnimation { showCopiedToast = true }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    withAnimation { showCopiedToast = false }
                                }
                            }) {
                                HStack {
                                    Image(systemName: showCopiedToast ? "checkmark" : "doc.on.doc")
                                    Text(showCopiedToast ? Constants.UI.copiedToast : Constants.UI.copyResetCommandButton)
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .tint(showCopiedToast ? .green : .blue)
                        }
                        
                        Text("3. " + Constants.UI.tccBugStep3)
                            .font(.caption)
                            .bold()
                    }
                    .padding(12)
                    .background(Color(NSColor.windowBackgroundColor))
                    .cornerRadius(6)
                    .padding(.horizontal, 32)
                } label: {
                    Text(Constants.UI.tccBugTitle)
                        .font(.callout)
                        .foregroundColor(.orange)
                        .bold()
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)
            }
            
            Button(Constants.UI.checkAgainButton) {
                checkAction()
            }
            .buttonStyle(.borderless)
            .foregroundColor(.accentColor)
            .padding(.top, 8)
        }
        .padding(32)
        .frame(width: 650, height: showTroubleshooting ? 600 : 500)
    }
}