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
        .onChange(of: scenePhase) { _, newPhase in
            workspace.handleScenePhase(newPhase)
        }
    }
}

private struct WorkspaceView: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    @State private var splitNotice: String?

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
                            Text("Session: \(workspace.goalsManager.sessionProgressText())")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            if let splitNotice {
                                Text(splitNotice)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if workspace.modeController.activeMode == .linear {
                                Button(workspace.splitEditorState.isSplit ? "Close Split" : "Open Split") {
                                    toggleSplit(windowWidth: geometry.size.width)
                                }
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
                    if mode == .modular, workspace.splitEditorState.isSplit {
                        workspace.splitEditorState.closeSplit()
                    }
                }
            }
        }
    }

    private var sidebarNodes: [SidebarNode] {
        guard let project = workspace.projectManager.currentProject else { return [] }
        return SidebarHierarchyBuilder.build(project: project, filters: workspace.navigationState.activeFilters)
    }

    private func toggleSplit(windowWidth: CGFloat) {
        if workspace.splitEditorState.isSplit {
            workspace.splitEditorState.closeSplit()
            splitNotice = nil
            return
        }

        if let selected = workspace.navigationState.selectedSceneId {
            let applied = workspace.splitEditorState.openSplit(
                sceneId: selected,
                preferredOrientation: .vertical,
                windowWidth: windowWidth
            )
            splitNotice = applied == .horizontal ? "Window too narrow for side-by-side split. Using stacked layout." : nil
            workspace.splitEditorState.setActivePane(1)
        }
    }
}
