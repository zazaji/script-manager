// ScriptManager/Views/Components/SidebarView.swift
import SwiftUI

public struct SidebarView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    @Binding var selectedItemID: String?
    @State private var isShowingSettings = false
    @ObservedObject var appState = AppStateManager.shared
    
    public var body: some View {
        VStack(spacing: 0) {
            // 1. 顶部 Tab 切换器
            HStack(spacing: 12) {
                Picker("", selection: $workspaceVM.currentTab) {
                    Image(systemName: "star.fill")
                        .tag(WorkspaceViewModel.SidebarTab.frequent)
                    Image(systemName: "link")
                        .tag(WorkspaceViewModel.SidebarTab.custom)
                    Image(systemName: "folder.fill")
                        .tag(WorkspaceViewModel.SidebarTab.workspace)
                    Image(systemName: "app.badge.fill")
                        .tag(WorkspaceViewModel.SidebarTab.applications)
                }
                .pickerStyle(.segmented)
                .scaleEffect(1.1)
                .frame(maxWidth: .infinity)
                
                Button(action: { isShowingSettings = true }) {
                    Image(systemName: "gearshape")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help(Constants.UI.settingsTitle)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            
            // 2. 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(searchPrompt, text: $workspaceVM.searchText)
                    .textFieldStyle(.plain)
                if !workspaceVM.searchText.isEmpty {
                    Button(action: { workspaceVM.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
            
            Divider()
            
            // 3. 内容列表
            Group {
                switch workspaceVM.currentTab {
                case .frequent:
                    FavoriteScriptsView(workspaceVM: workspaceVM, selectedScriptID: $selectedItemID)
                case .custom:
                    CustomScriptsView(workspaceVM: workspaceVM, selectedScriptID: $selectedItemID)
                case .workspace:
                    WorkspaceScriptsView(workspaceVM: workspaceVM, selectedScriptID: $selectedItemID)
                case .applications:
                    ApplicationListView(workspaceVM: workspaceVM, selectedAppID: $selectedItemID)
                }
            }
        }
        .sheet(isPresented: $workspaceVM.isShowingNewScriptSheet) {
            NewScriptView(workspaceVM: workspaceVM)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .onAppear {
            if workspaceVM.selectedWorkspacePath == nil, let first = appState.recentWorkspaces.first {
                workspaceVM.selectedWorkspacePath = first
                WorkspaceManager.shared.startMonitoring(url: URL(fileURLWithPath: first))
                workspaceVM.refresh()
            }
        }
    }
    
    private var searchPrompt: String {
        workspaceVM.currentTab == .applications ? Constants.UI.searchAppsPrompt : Constants.UI.searchPrompt
    }
}

// MARK: - 子视图实现

struct FavoriteScriptsView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    @Binding var selectedScriptID: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Constants.UI.favoriteScripts).font(.headline)
                Spacer()
                Picker("", selection: $workspaceVM.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.iconName).tag(mode)
                    }
                }.pickerStyle(.segmented).frame(width: 70)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            
            if workspaceVM.viewMode == .list {
                List(selection: $selectedScriptID) {
                    ForEach(workspaceVM.filteredFrequentScripts) { script in
                        ScriptRowView(script: script).tag(script.id)
                    }
                }.listStyle(.sidebar)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ForEach(workspaceVM.filteredFrequentScripts) { script in
                            ScriptGridItemView(script: script, isSelected: selectedScriptID == script.id)
                                .onTapGesture { selectedScriptID = script.id }
                        }
                    }.padding()
                }.background(Color(NSColor.underPageBackgroundColor))
            }
        }
    }
}

struct CustomScriptsView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    @Binding var selectedScriptID: String?
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(Constants.UI.customScripts).font(.headline)
                Spacer()
                Button(action: workspaceVM.addCustomScript) { Image(systemName: "plus") }.buttonStyle(.plain)
                Picker("", selection: $workspaceVM.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.iconName).tag(mode)
                    }
                }.pickerStyle(.segmented).frame(width: 70)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            
            if workspaceVM.viewMode == .list {
                List(selection: $selectedScriptID) {
                    ForEach(workspaceVM.filteredCustomScripts) { script in
                        ScriptRowView(script: script).tag(script.id)
                    }
                }.listStyle(.sidebar)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ForEach(workspaceVM.filteredCustomScripts) { script in
                            ScriptGridItemView(script: script, isSelected: selectedScriptID == script.id)
                                .onTapGesture { selectedScriptID = script.id }
                        }
                    }.padding()
                }.background(Color(NSColor.underPageBackgroundColor))
            }
        }
    }
}

struct WorkspaceScriptsView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    @Binding var selectedScriptID: String?
    @ObservedObject var appState = AppStateManager.shared
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 架构级修复：添加空 Tag 消除 Picker 警告
                Picker("", selection: Binding(
                    get: { workspaceVM.selectedWorkspacePath ?? "" },
                    set: { newValue in
                        if newValue == "SELECT_NEW" { workspaceVM.selectWorkspace() }
                        else if !newValue.isEmpty {
                            workspaceVM.selectedWorkspacePath = newValue
                            WorkspaceManager.shared.startMonitoring(url: URL(fileURLWithPath: newValue))
                            workspaceVM.refresh()
                        }
                    }
                )) {
                    Text("").tag("") // 修复 selection "" is invalid 警告
                    Text(Constants.UI.selectWorkspaceButton + "...").tag("SELECT_NEW")
                    Divider()
                    ForEach(appState.recentWorkspaces, id: \.self) { path in
                        Text((path as NSString).lastPathComponent).tag(path)
                    }
                }.pickerStyle(.menu).labelsHidden()
                
                Spacer()
                Button(action: { workspaceVM.refresh() }) { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain)
                Button(action: { workspaceVM.isShowingNewScriptSheet = true }) { Image(systemName: "plus") }.buttonStyle(.plain)
                Picker("", selection: $workspaceVM.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.iconName).tag(mode)
                    }
                }.pickerStyle(.segmented).frame(width: 70)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            Divider()
            
            if workspaceVM.viewMode == .list {
                List(selection: $selectedScriptID) {
                    ForEach(workspaceVM.filteredScripts) { script in
                        ScriptRowView(script: script).tag(script.id)
                    }
                }.listStyle(.sidebar)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 16) {
                        ForEach(workspaceVM.filteredScripts) { script in
                            ScriptGridItemView(script: script, isSelected: selectedScriptID == script.id)
                                .onTapGesture { selectedScriptID = script.id }
                        }
                    }.padding()
                }.background(Color(NSColor.underPageBackgroundColor))
            }
        }
    }
}

struct ScriptRowView: View {
    let script: ScriptItem
    var body: some View {
        HStack {
            Image(systemName: script.type.iconName)
                .foregroundColor(script.type.iconColor)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(script.name).font(.body).lineLimit(1)
                if let displayName = script.displayName {
                    Text(displayName).font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
        }.padding(.vertical, 2)
    }
}

struct ScriptGridItemView: View {
    let script: ScriptItem
    let isSelected: Bool
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: script.type.iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 36, height: 36)
                .foregroundColor(script.type.iconColor)
            Text(script.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(1)
                .foregroundColor(isSelected ? .white : .primary)
        }
        .padding().frame(maxWidth: .infinity, minHeight: 100)
        .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}