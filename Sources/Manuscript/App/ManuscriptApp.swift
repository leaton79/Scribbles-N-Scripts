import SwiftUI
import UniformTypeIdentifiers

@main
struct ManuscriptApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workspace = WorkspaceCoordinator()

    var body: some SwiftUI.Scene {
        let commands = WorkspaceCommandBindings(workspace: workspace)
        WindowGroup {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .commands {
            CommandMenu("Project") {
                Button("Reopen Last Project") {
                    _ = commands.reopenLastProject()
                }
                .disabled(!commands.canReopenLastProject)

                Menu("Open Recent") {
                    if commands.recentProjects.isEmpty {
                        Text("No Recent Projects")
                    } else {
                        ForEach(commands.recentProjects) { project in
                            Button(project.name) {
                                _ = commands.openProject(at: project.url)
                            }
                        }
                        Divider()
                        Button("Clear Recent Projects") {
                            commands.clearRecentProjects()
                        }
                    }
                }
                .disabled(commands.recentProjects.isEmpty)

                Divider()

                Button("Save Project As…") {
                    NotificationCenter.default.post(name: .showSaveAsSheet, object: nil)
                }
                .disabled(!commands.canSaveProjectAs)

                Button("Rename Project…") {
                    NotificationCenter.default.post(name: .showRenameSheet, object: nil)
                }
                .disabled(!commands.canRenameProject)

                Divider()

                Button("Save Project") {
                    _ = commands.saveProject()
                }
                .keyboardShortcut("s", modifiers: [.command])
                .disabled(!commands.canSaveProject)

                Button("New Chapter") {
                    _ = commands.createChapter()
                }
                .keyboardShortcut("N", modifiers: [.command, .shift])
                .disabled(!commands.canCreateProjectContent)

                Button("New Scene") {
                    _ = commands.createScene()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(!commands.canCreateProjectContent)

                Divider()

                Button("Create Backup") {
                    _ = commands.createBackup()
                }
                .disabled(!commands.canCreateBackup)

                Button("Save and Backup") {
                    _ = commands.saveAndBackup()
                }
                .keyboardShortcut("S", modifiers: [.command, .option])
                .disabled(!commands.canSaveAndBackup)
            }

            CommandMenu("View") {
                Button("Linear Mode") {
                    commands.setModeLinear()
                }
                .keyboardShortcut("1", modifiers: [.command])
                .disabled(!commands.canSwitchToLinearMode)

                Button("Modular Mode") {
                    commands.setModeModular()
                }
                .keyboardShortcut("2", modifiers: [.command])
                .disabled(!commands.canSwitchToModularMode)

                Button(commands.splitToggleTitle) {
                    _ = commands.toggleSplit()
                }
                .keyboardShortcut("\\", modifiers: [.command])
                .disabled(!commands.canToggleSplitEditor)

                Divider()

                Button("Previous Scene") {
                    _ = commands.navigateToPreviousScene()
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!commands.canNavigateToPreviousScene)

                Button("Next Scene") {
                    _ = commands.navigateToNextScene()
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!commands.canNavigateToNextScene)
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
    @State private var showingNewProjectSheet = false
    @State private var showingOpenProjectPicker = false
    @State private var showingSaveAsSheet = false
    @State private var showingRenameSheet = false
    @State private var newProjectName = ""
    @State private var saveAsProjectName = ""
    @State private var renameProjectName = ""

    var body: some View {
        let commands = WorkspaceCommandBindings(workspace: workspace)
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
                            Text(workspace.hasUnsavedChanges ? "Unsaved changes" : "All changes saved")
                                .font(.caption)
                                .foregroundStyle(workspace.hasUnsavedChanges ? .orange : .secondary)
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
                            Button("New Project") {
                                newProjectName = ""
                                showingNewProjectSheet = true
                            }
                            Button("Open Project") {
                                showingOpenProjectPicker = true
                            }
                            Menu("Recent") {
                                if commands.recentProjects.isEmpty {
                                    Text("No Recent Projects")
                                } else {
                                    ForEach(commands.recentProjects) { project in
                                        Button(project.name) {
                                            actionNotice = commands.openProject(at: project.url)
                                        }
                                    }
                                    Divider()
                                    Button("Clear Recent Projects") {
                                        commands.clearRecentProjects()
                                        actionNotice = "Recent projects cleared."
                                    }
                                }
                            }
                            .disabled(commands.recentProjects.isEmpty)
                            Button("Reopen Last") {
                                actionNotice = commands.reopenLastProject()
                            }
                            .disabled(!commands.canReopenLastProject)
                            Button("Save As") {
                                saveAsProjectName = workspace.projectDisplayName
                                showingSaveAsSheet = true
                            }
                            .disabled(!commands.canSaveProjectAs)
                            Button("Rename") {
                                renameProjectName = workspace.projectDisplayName
                                showingRenameSheet = true
                            }
                            .disabled(!commands.canRenameProject)
                            Button("Save") {
                                actionNotice = commands.saveProject() ?? "Project saved."
                            }
                            .keyboardShortcut("s", modifiers: [.command])
                            .disabled(!commands.canSaveProject)
                            Button("New Chapter") {
                                actionNotice = commands.createChapter()
                            }
                            .keyboardShortcut("N", modifiers: [.command, .shift])
                            .disabled(!commands.canCreateProjectContent)
                            Button("New Scene") {
                                actionNotice = commands.createScene()
                            }
                            .keyboardShortcut("n", modifiers: [.command])
                            .disabled(!commands.canCreateProjectContent)
                            Button("Backup") {
                                actionNotice = commands.createBackup()
                            }
                            .disabled(!commands.canCreateBackup)
                            Button("Save + Backup") {
                                actionNotice = commands.saveAndBackup()
                            }
                            .disabled(!commands.canSaveAndBackup)
                            if workspace.modeController.activeMode == .linear {
                                Button(commands.splitToggleTitle) {
                                    toggleSplit(windowWidth: geometry.size.width)
                                }
                                .keyboardShortcut("\\", modifiers: [.command])
                                .disabled(!commands.canToggleSplitEditor)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.ultraThinMaterial)

                        if !workspace.navigationState.breadcrumb.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(Array(workspace.navigationState.breadcrumb.enumerated()), id: \.offset) { index, item in
                                        Button(item.title) {
                                            workspace.select(breadcrumb: item)
                                        }
                                        .buttonStyle(.plain)
                                        .foregroundStyle(index == workspace.navigationState.breadcrumb.count - 1 ? .primary : .secondary)

                                        if index < workspace.navigationState.breadcrumb.count - 1 {
                                            Text(">")
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .background(.ultraThinMaterial.opacity(0.5))
                        }

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
                .onReceive(NotificationCenter.default.publisher(for: .showSaveAsSheet)) { _ in
                    saveAsProjectName = workspace.projectDisplayName
                    showingSaveAsSheet = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .showRenameSheet)) { _ in
                    renameProjectName = workspace.projectDisplayName
                    showingRenameSheet = true
                }
                .fileImporter(
                    isPresented: $showingOpenProjectPicker,
                    allowedContentTypes: [.folder],
                    allowsMultipleSelection: false
                ) { result in
                    switch result {
                    case let .success(urls):
                        guard let folder = urls.first else { return }
                        actionNotice = commands.openProject(at: folder)
                    case let .failure(error):
                        actionNotice = "Could not open project: \(error.localizedDescription)"
                    }
                }
                .sheet(isPresented: $showingNewProjectSheet) {
                    NewProjectSheet(
                        title: "Create New Project",
                        actionLabel: "Create",
                        projectName: $newProjectName,
                        onCancel: {
                            showingNewProjectSheet = false
                        },
                        onCreate: {
                            actionNotice = commands.createProject(named: newProjectName)
                            showingNewProjectSheet = false
                        }
                    )
                }
                .sheet(isPresented: $showingSaveAsSheet) {
                    NewProjectSheet(
                        title: "Save Project As",
                        actionLabel: "Save As",
                        projectName: $saveAsProjectName,
                        onCancel: {
                            showingSaveAsSheet = false
                        },
                        onCreate: {
                            actionNotice = commands.saveProjectAs(named: saveAsProjectName) ?? "Project saved as \(saveAsProjectName)."
                            showingSaveAsSheet = false
                        }
                    )
                }
                .sheet(isPresented: $showingRenameSheet) {
                    NewProjectSheet(
                        title: "Rename Project",
                        actionLabel: "Rename",
                        projectName: $renameProjectName,
                        onCancel: {
                            showingRenameSheet = false
                        },
                        onCreate: {
                            actionNotice = commands.renameProject(to: renameProjectName) ?? "Project renamed to \(renameProjectName)."
                            showingRenameSheet = false
                        }
                    )
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

private struct NewProjectSheet: View {
    let title: String
    let actionLabel: String
    @Binding var projectName: String
    let onCancel: () -> Void
    let onCreate: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
            TextField("Project name", text: $projectName)
                .textFieldStyle(.roundedBorder)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                Button(actionLabel, action: onCreate)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }
}

private extension Notification.Name {
    static let showSaveAsSheet = Notification.Name("workspace.showSaveAsSheet")
    static let showRenameSheet = Notification.Name("workspace.showRenameSheet")
}
