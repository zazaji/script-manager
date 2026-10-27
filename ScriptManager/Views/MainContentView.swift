// ScriptManager/Views/MainContentView.swift
import SwiftUI

public struct MainContentView: View {
    // 架构级增强：适配 WorkspaceViewModel 的单例化，供全局启动器共享数据
    @ObservedObject private var workspaceVM = WorkspaceViewModel.shared
    @StateObject private var detailVM = ScriptDetailViewModel()
    @ObservedObject private var terminalManager = TerminalManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @State private var showPermissionSheet = false
    
    // 架构级修复：显式控制 Sidebar 的可见性，防止其在小窗口时变为 Overlay 遮挡右侧
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    
    public init() {}
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 权限警告条
            if !permissionManager.hasFDA {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(Constants.UI.fdaRecommendedMessage)
                        .font(.subheadline)
                    Spacer()
                    Button(Constants.UI.grantAccessButton) {
                        showPermissionSheet = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                
                Rectangle()
                    .fill(Color(NSColor.separatorColor))
                    .frame(height: 1)
            }
            
            // 2. 核心布局：左侧 Sidebar 全高，右侧 Detail + Terminal
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(
                    workspaceVM: workspaceVM,
                    selectedItemID: $workspaceVM.selectedItemID
                )
                .navigationTitle(Constants.UI.scriptLibraryTitle)
                .navigationSplitViewColumnWidth(min: 240, ideal: 260, max: 280) // 限制最大宽度，防止 Sidebar 贪婪占据 Detail 的空间
                .toolbar {
                    // 架构级增强：将终端按钮放在左侧 Toolbar，与 Sidebar 切换并列
                    ToolbarItem(placement: .navigation) {
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                terminalManager.togglePanel()
                            }
                        }) {
                            Image(systemName: "terminal")
                                .foregroundColor(terminalManager.isPanelVisible ? .accentColor : .secondary)
                        }
                        .help(Constants.UI.terminalPanelTitle)
                    }
                }
            } detail: {
                // 架构级修复：确保 detail 区域拥有独立、不透明的背景，防止终端背景渗漏到 Sidebar
                VStack(spacing: 0) {
                    detailView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    if terminalManager.isPanelVisible {
                        // 自定义分割线，消除白线
                        Rectangle()
                            .fill(Color(NSColor.separatorColor))
                            .frame(height: 1)
                        
                        TerminalPanelView()
                            .frame(height: 320)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.textBackgroundColor)) // 关键：设置不透明背景
                .clipped() // 关键：裁剪边界，防止动画溢出
            }
            .navigationSplitViewStyle(.balanced) // 架构级修复：保持侧边栏和内容区的稳定并排形态，禁止其转化为浮层覆盖遮挡
            .onChange(of: workspaceVM.selectedItemID) { _, newValue in
                handleSelectionChange(newValue)
            }
        }
        .sheet(isPresented: $showPermissionSheet) {
            PermissionDeniedView(checkAction: {
                permissionManager.checkFDA()
                if permissionManager.hasFDA {
                    showPermissionSheet = false
                }
            })
        }
        .onAppear {
            permissionManager.checkFDA()
        }
    }
    
    @ViewBuilder
    private var detailView: some View {
        if workspaceVM.currentTab == .applications {
            if let selectedID = workspaceVM.selectedItemID,
               let app = workspaceVM.applications.first(where: { $0.id == selectedID }) {
                ApplicationDetailView(app: app)
            } else {
                WelcomeView(workspaceVM: workspaceVM)
            }
        } else {
            if let selectedID = workspaceVM.selectedItemID,
               let item = workspaceVM.allScripts.first(where: { $0.id == selectedID }) {
                ScriptDetailView(viewModel: detailVM, item: item)
            } else {
                WelcomeView(workspaceVM: workspaceVM)
            }
        }
    }
    
    private func handleSelectionChange(_ newValue: String?) {
        guard let id = newValue else { return }
        if workspaceVM.currentTab != .applications {
            if let item = workspaceVM.allScripts.first(where: { $0.id == id }) {
                detailVM.load(item: item)
            }
        }
    }
}

struct WelcomeView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    
    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                VStack(spacing: 16) {
                    Image(systemName: "terminal.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 64, height: 64)
                        .foregroundColor(.accentColor)
                    
                    Text(Constants.UI.welcomeTitle)
                        .font(.largeTitle)
                        .bold()
                    
                    Text(Constants.UI.welcomeSubtitle)
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
                .padding(.top, 60)
                
                VStack(alignment: .leading, spacing: 20) {
                    Text(Constants.UI.guideTitle)
                        .font(.title2)
                        .bold()
                    
                    VStack(alignment: .leading, spacing: 16) {
                        GuideStepView(step: Constants.UI.guideStep1, icon: "text.quote")
                        
                        Text("""
                        # @Name: My Script
                        # @Param: input | string | true | default | Description
                        """)
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(NSColor.windowBackgroundColor))
                        .cornerRadius(8)
                        
                        GuideStepView(step: Constants.UI.guideStep2, icon: "switch.2")
                        GuideStepView(step: Constants.UI.guideStep3, icon: "play.fill")
                    }
                }
                .padding(24)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
                .padding(.horizontal, 40)
                
                HStack(spacing: 20) {
                    Button(action: {
                        workspaceVM.selectWorkspace()
                    }) {
                        HStack {
                            Image(systemName: "folder.badge.plus")
                            Text(Constants.UI.openWorkspaceButton)
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    
                    Button(action: {
                        workspaceVM.generateSamples()
                    }) {
                        HStack {
                            Image(systemName: "wand.and.stars")
                            Text(Constants.UI.generateSamplesButton)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.bottom, 40)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(NSColor.textBackgroundColor))
    }
}

struct GuideStepView: View {
    let step: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
                .frame(width: 24)
            Text(step)
                .font(.body)
        }
    }
}