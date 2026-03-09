import SwiftUI

@main
struct ManuscriptApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workspace = WorkspaceCoordinator()

    var body: some SwiftUI.Scene {
        WindowGroup {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            CommandMenu("Project") {
                Button("New Chapter") {
                    _ = workspace.createChapter()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])

                Button("New Scene") {
                    _ = workspace.createScene()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }

            CommandMenu("View") {
                Button("Linear Mode") {
                    workspace.setMode(.linear)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Modular Mode") {
                    workspace.setMode(.modular)
                }
                .keyboardShortcut("2", modifiers: [.command])

                Button(workspace.splitEditorState.isSplit ? "Close Split" : "Toggle Split") {
                    _ = workspace.toggleSplitForCommand()
                }
                .keyboardShortcut("\\", modifiers: [.command])
                .disabled(workspace.modeController.activeMode != .linear && !workspace.splitEditorState.isSplit)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            workspace.handleScenePhase(newPhase)
        }
    }
}

private struct WorkspaceView: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    @State private var splitNotice: String?
    @State private var actionNotice: String?

    var body: some View {
        GeometryReader { geometry in
            if let loadError = workspace.loadError {
                ContentUnavailableView("Could not open project", systemImage: "exclamationmark.triangle", description: Text(loadError))
            } else {
                HStack(spacing: 0) {
                    SidebarView(
                        navigationState: workspace.navigationState,
                        nodes: sidebarNodes,
                        onSelect: workspace.select(node:)
                    )
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)

                    Divider()

                    VStack(spacing: 0) {
                        HStack {
                            Text(workspace.projectDisplayName)
                                .font(.headline)
                            Text("Session: \(workspace.goalsManager.sessionProgressText())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let actionNotice {
                                Text(actionNotice)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if let splitNotice {
                                Text(splitNotice)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("New Chapter") {
                                actionNotice = workspace.createChapter()
                            }
                            .keyboardShortcut("N", modifiers: [.command, .shift])
                            Button("New Scene") {
                                actionNotice = workspace.createScene()
                            }
                            .keyboardShortcut("n", modifiers: [.command])
                            if workspace.modeController.activeMode == .linear {
                                Button(workspace.splitEditorState.isSplit ? "Close Split" : "Open Split") {
                                    toggleSplit(windowWidth: geometry.size.width)
                                }
                                .keyboardShortcut("\\", modifiers: [.command])
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.ultraThinMaterial)

                        ModeContainerView(
                            modeController: workspace.modeController,
                            linearState: workspace.linearState,
                            modularState: workspace.modularState,
                            navigationState: workspace.navigationState,
                            editorState: workspace.editorState,
                            splitState: workspace.splitEditorState
                        )
                    }
                }
                .onChange(of: workspace.modeController.activeMode) { _, mode in
                    workspace.handleModeChange(mode)
                }
            }
        }
    }

    private var sidebarNodes: [SidebarNode] {
        guard let project = workspace.projectManager.currentProject else { return [] }
        return SidebarHierarchyBuilder.build(project: project, filters: workspace.navigationState.activeFilters)
    }

    private func toggleSplit(windowWidth: CGFloat) {
        splitNotice = workspace.toggleSplit(windowWidth: windowWidth)
    }
}
