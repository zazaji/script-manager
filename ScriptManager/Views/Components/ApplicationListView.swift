// ScriptManager/Views/Components/ApplicationListView.swift
import SwiftUI
import AppKit

public struct ApplicationListView: View {
    @ObservedObject var workspaceVM: WorkspaceViewModel
    @Binding var selectedAppID: String?
    
    public var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text(Constants.UI.applicationsTitle).font(.headline)
                Spacer()
                Button(action: { workspaceVM.loadApplications() }) {
                    Image(systemName: "arrow.clockwise")
                }.buttonStyle(.plain)
                
                Picker("", selection: $workspaceVM.viewMode) {
                    ForEach(ViewMode.allCases, id: \.self) { mode in
                        Image(systemName: mode.iconName).tag(mode)
                    }
                }.pickerStyle(.segmented).frame(width: 70)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // 列表内容
            if workspaceVM.viewMode == .list {
                List(selection: $selectedAppID) {
                    ForEach(workspaceVM.filteredApplications) { app in
                        ApplicationRowView(app: app)
                            .tag(app.id)
                            .contextMenu {
                                Button(Constants.UI.openAppButton) {
                                    ApplicationManager.shared.launchApplication(at: app.url)
                                }
                                Button(Constants.UI.openInFinderButton) {
                                    NSWorkspace.shared.selectFile(app.url.path, inFileViewerRootedAtPath: "")
                                }
                            }
                    }
                }.listStyle(.sidebar)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 100, maximum: 120), spacing: 16)], spacing: 16) {
                        ForEach(workspaceVM.filteredApplications) { app in
                            ApplicationGridItemView(app: app, isSelected: selectedAppID == app.id)
                                .onTapGesture { selectedAppID = app.id }
                                .onTapGesture(count: 2) {
                                    ApplicationManager.shared.launchApplication(at: app.url)
                                }
                        }
                    }.padding()
                }.background(Color(NSColor.underPageBackgroundColor))
            }
        }
    }
}

struct ApplicationRowView: View {
    let app: ApplicationItem
    
    var body: some View {
        HStack(spacing: 12) {
            AppIconView(url: app.url)
                .frame(width: 24, height: 24)
            
            Text(app.name).font(.body).lineLimit(1)
            Spacer()
        }.padding(.vertical, 4)
    }
}

struct ApplicationGridItemView: View {
    let app: ApplicationItem
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            AppIconView(url: app.url)
                .frame(width: 48, height: 48)
            
            Text(app.name)
                .font(.caption)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(height: 32)
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 110)
        .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
        .foregroundColor(isSelected ? .white : .primary)
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}