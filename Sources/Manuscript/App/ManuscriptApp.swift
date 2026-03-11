import SwiftUI
import UniformTypeIdentifiers
import AppKit

@main
struct ScribblesNScriptsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var workspace = WorkspaceCoordinator()

    init() {
        AppIconRenderer.applyToApplication()
    }

    var body: some SwiftUI.Scene {
        let commands = WorkspaceCommandBindings(workspace: workspace)
        WindowGroup {
            WorkspaceView(workspace: workspace)
                .frame(minWidth: 1000, minHeight: 700)
        }
        .defaultSize(width: 1440, height: 900)
        .commands {
            CommandMenu("Project") {
                Button("Command Palette…") {
                    NotificationCenter.default.post(name: .showCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

                Button("Switch Project…") {
                    NotificationCenter.default.post(name: .showProjectSwitcher, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .shift])

                Divider()

                Button("Reopen Last Project") {
                    _ = commands.reopenLastProject()
                }
                .disabled(!commands.canReopenLastProject)

                Menu("Open Recent") {
                    if commands.recentProjects.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("No Recent Projects")
                            Button("Help") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "recent-projects-empty")
                            }
                            .buttonStyle(.borderless)
                            .font(.caption)
                        }
                    } else {
                        ForEach(commands.recentProjects) { project in
                            Button(project.name) {
                                _ = commands.openProject(at: project.url)
                            }
                        }
                        Divider()
                        Button("Clear Recent Projects") {
                            NotificationCenter.default.post(name: .requestClearRecentProjects, object: nil)
                        }
                    }
                    if commands.hasStaleRecentProjects {
                        if !commands.recentProjects.isEmpty {
                            Divider()
                        }
                        Button("Clean Missing Entries") {
                            NotificationCenter.default.post(name: .requestCleanupMissingRecentProjects, object: nil)
                        }
                    }
                }
                .disabled(commands.recentProjects.isEmpty && !commands.hasStaleRecentProjects)

                Divider()

                Button("Save Project As…") {
                    NotificationCenter.default.post(name: .showSaveAsSheet, object: nil)
                }
                .disabled(!commands.canSaveProjectAs)

                Button("Rename Project…") {
                    NotificationCenter.default.post(name: .showRenameSheet, object: nil)
                }
                .disabled(!commands.canRenameProject)

                Button("Project Settings…") {
                    NotificationCenter.default.post(name: .showProjectSettings, object: nil)
                }
                .keyboardShortcut(",", modifiers: [.command])
                .disabled(!workspace.hasOpenProject)

                Button("Import / Export…") {
                    NotificationCenter.default.post(name: .showImportExport, object: nil)
                }
                .disabled(!commands.canShowImportExport)

                Button("Timeline…") {
                    NotificationCenter.default.post(name: .showTimelineSheet, object: nil)
                }
                .disabled(!commands.canCreateProjectContent)

                Button("Entities…") {
                    NotificationCenter.default.post(name: .showEntitiesSheet, object: nil)
                }
                .disabled(!commands.canCreateProjectContent)

                Button("Sources…") {
                    NotificationCenter.default.post(name: .showSourcesSheet, object: nil)
                }
                .disabled(!commands.canCreateProjectContent)

                Button("Notes…") {
                    NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                }
                .disabled(!commands.canCreateProjectContent)

                Button("Scratchpad…") {
                    NotificationCenter.default.post(name: .showScratchpadSheet, object: nil)
                }
                .disabled(!commands.canCreateProjectContent)

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

                Button("New Scene Below") {
                    _ = commands.createSceneBelow()
                }
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(!commands.canCreateSceneBelow)

                Button("Move to Chapter…") {
                    NotificationCenter.default.post(name: .showMoveSceneSheet, object: nil)
                }
                .disabled(!commands.canMoveSelectedSceneToAnotherChapter)

                Button("Send to Staging") {
                    _ = commands.sendSelectedSceneToStaging()
                }
                .disabled(!commands.canSendSelectedSceneToStaging)

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

                if let reason = commands.projectActionsDisabledReason {
                    Divider()
                    Button("Why Are Some Project Actions Disabled?") {
                        NotificationCenter.default.post(name: .showHelpReference, object: "disabled-commands")
                    }
                    Text(reason)
                }
            }

            CommandMenu("Workspace") {
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

                Button("Open in Split") {
                    _ = commands.openSelectionInSplit()
                }
                .disabled(!commands.canOpenSelectionInSplit)

                Button(commands.inspectorToggleTitle) {
                    commands.toggleInspector()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(!commands.canToggleInspector)

                Divider()

                Button("Modular Corkboard") {
                    commands.showCorkboardMode()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Modular Outliner") {
                    commands.showOutlinerMode()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Group Modular by Chapter") {
                    commands.groupModularByChapter()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Group Modular Flat") {
                    commands.groupModularFlat()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Group Modular by Status") {
                    commands.groupModularByStatus()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Compact Corkboard Density") {
                    commands.setCorkboardDensityCompact()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Comfortable Corkboard Density") {
                    commands.setCorkboardDensityComfortable()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Collapse All Modular Groups") {
                    commands.collapseAllModularGroups()
                }
                .disabled(!commands.canUseModularPresentationControls)

                Button("Expand All Modular Groups") {
                    commands.expandAllModularGroups()
                }
                .disabled(!commands.canUseModularPresentationControls)

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

                Divider()

                Button("Writing Goals & Statistics…") {
                    NotificationCenter.default.post(name: .showGoalsDashboard, object: nil)
                }
                .keyboardShortcut("g", modifiers: [.command, .shift])

                if let reason = commands.workspaceActionsDisabledReason {
                    Divider()
                    Button("Why Are Some Workspace Actions Disabled?") {
                        NotificationCenter.default.post(name: .showHelpReference, object: "disabled-commands")
                    }
                    Text(reason)
                }
            }

            CommandMenu("Appearance") {
                Menu("Theme") {
                    ForEach(AppTheme.allCases, id: \.self) { theme in
                        Button(theme.displayName) {
                            _ = commands.setTheme(theme)
                        }
                    }
                }

                Menu("Appearance Presets") {
                    if commands.appearancePresets.isEmpty {
                        Text("No Appearance Presets")
                    } else {
                        ForEach(commands.appearancePresets) { preset in
                            Button(preset.name) {
                                _ = commands.applyAppearancePreset(preset.id)
                            }
                        }
                    }
                }
                .disabled(commands.appearancePresets.isEmpty)

                Divider()

                Menu("Sidebar Text (\(Int(commands.sidebarTextSize)) pt)") {
                    Button("Smaller Sidebar Text") {
                        _ = commands.adjustSidebarTextSize(by: -1)
                    }
                    Button("Larger Sidebar Text") {
                        _ = commands.adjustSidebarTextSize(by: 1)
                    }
                    Divider()
                    Button("Reset Sidebar Text") {
                        _ = commands.resetSidebarTextSize()
                    }
                }

                Menu("Editor Text (\(commands.editorTextSize) pt)") {
                    Button("Smaller Editor Text") {
                        _ = commands.adjustEditorTextSize(by: -1)
                    }
                    Button("Larger Editor Text") {
                        _ = commands.adjustEditorTextSize(by: 1)
                    }
                    Divider()
                    Button("Reset Editor Text") {
                        _ = commands.resetEditorTextSize()
                    }
                }
                .disabled(!workspace.hasOpenProject)

                Menu("Inspector Text (\(Int(commands.inspectorTextSize)) pt)") {
                    Button("Smaller Inspector Text") {
                        _ = commands.adjustInspectorTextSize(by: -1)
                    }
                    Button("Larger Inspector Text") {
                        _ = commands.adjustInspectorTextSize(by: 1)
                    }
                    Divider()
                    Button("Reset Inspector Text") {
                        _ = commands.resetInspectorTextSize()
                    }
                }
            }

            CommandMenu("Find") {
                Button("Find in Current Scene") {
                    NotificationCenter.default.post(name: .showInlineSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command])
                .disabled(!commands.canSearchProject)

                Button("Find in Project") {
                    NotificationCenter.default.post(name: .showProjectSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])
                .disabled(!commands.canSearchProject)

                Divider()

                Button(commands.searchHighlightToggleTitle) {
                    commands.toggleSearchHighlightDisplayMode()
                }
                .keyboardShortcut("h", modifiers: [.command, .option])
                .disabled(!commands.canToggleSearchHighlightDisplayMode)

                Button("Reset Highlight Settings") {
                    commands.resetSearchHighlightSettings()
                }
                .keyboardShortcut("0", modifiers: [.command, .option])
                .disabled(!commands.canResetSearchHighlightSettings)

                Divider()

                Button("Select All Matched Scenes") {
                    commands.includeAllReplaceScenes()
                }
                .keyboardShortcut("i", modifiers: [.command, .option])
                .disabled(!commands.canBulkSelectReplaceScenes)

                Button("Deselect All Matched Scenes") {
                    commands.excludeAllReplaceScenes()
                }
                .keyboardShortcut("u", modifiers: [.command, .option])
                .disabled(!commands.canBulkSelectReplaceScenes)

                Button(commands.replaceUndoMenuTitle) {
                    _ = commands.undoLastReplaceBatch()
                }
                .disabled(!commands.canUndoLastReplaceBatch)

                Button(commands.replaceRedoMenuTitle) {
                    _ = commands.redoLastReplaceBatch()
                }
                .disabled(!commands.canRedoLastReplaceBatch)

                if let reason = commands.searchActionsDisabledReason {
                    Divider()
                    Button("Why Is Search Disabled?") {
                        NotificationCenter.default.post(name: .showHelpReference, object: "disabled-commands")
                    }
                    Text(reason)
                }
            }

            CommandGroup(after: .help) {
                Button("Scribbles-N-Scripts Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: nil)
                }
                .keyboardShortcut("/", modifiers: [.command, .shift])
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            workspace.handleScenePhase(newPhase)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApplication.shared.windows.first?.makeKeyAndOrderFront(nil)
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
    @State private var showingProjectSwitcher = false
    @State private var showingCommandPalette = false
    @State private var showingHelpReference = false
    @State private var showingGoalsDashboard = false
    @State private var showingProjectSettings = false
    @State private var showingImportExport = false
    @State private var showingTimelineSheet = false
    @State private var showingEntitiesSheet = false
    @State private var showingSourcesSheet = false
    @State private var showingNotesSheet = false
    @State private var showingScratchpadSheet = false
    @State private var showingImportPicker = false
    @State private var showingResearchImportPicker = false
    @State private var pendingResearchImportSourceID: UUID?
    @State private var showingMoveSceneSheet = false
    @State private var projectSwitcherQuery = ""
    @State private var commandPaletteQuery = ""
    @State private var pendingRecentAction: RecentProjectsAction?
    @State private var showingRecentActionConfirmation = false
    @State private var recentUndoSnapshot: RecentProjectsSnapshot?
    @State private var recentUndoMessage: String?
    @State private var newProjectName = ""
    @State private var saveAsProjectName = ""
    @State private var renameProjectName = ""
    @State private var helpReferenceEntryID: String?

    var body: some View {
        let commands = WorkspaceCommandBindings(workspace: workspace)
        GeometryReader { geometry in
            workspaceBody(commands: commands, geometry: geometry)
        }
        .onReceive(NotificationCenter.default.publisher(for: .showHelpReference)) { notification in
            helpReferenceEntryID = notification.object as? String
            showingHelpReference = true
        }
        .sheet(isPresented: $showingHelpReference) {
            HelpReferenceSheet(startingEntryID: helpReferenceEntryID)
                .preferredColorScheme(workspace.preferredColorScheme)
                .tint(workspace.themePalette.tint)
                .environment(\.appThemePalette, workspace.themePalette)
        }
    }

    @ViewBuilder
    private func workspaceBody(commands: WorkspaceCommandBindings, geometry: GeometryProxy) -> some View {
        if let loadError = workspace.loadError {
            VStack(spacing: 16) {
                ContentUnavailableView("Could not open project", systemImage: "exclamationmark.triangle", description: Text(loadError))
                if workspace.recoveryCandidateURL != nil {
                    Button("Open Recovery Mode") {
                        _ = workspace.openRecoveryModeForFailedProject()
                    }
                }
            }
        } else if !workspace.hasOpenProject {
            startScreen(commands: commands, geometry: geometry)
                .preferredColorScheme(workspace.preferredColorScheme)
                .tint(workspace.themePalette.tint)
                .environment(\.appThemePalette, workspace.themePalette)
                .background(workspace.themePalette.canvas.ignoresSafeArea())
        } else {
            loadedWorkspaceView(commands: commands, geometry: geometry)
                .preferredColorScheme(workspace.preferredColorScheme)
                .tint(workspace.themePalette.tint)
                .environment(\.appThemePalette, workspace.themePalette)
                .background(workspace.themePalette.canvas.ignoresSafeArea())
        }
    }

    private func startScreen(commands: WorkspaceCommandBindings, geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top, spacing: 18) {
                        Image(nsImage: AppIconRenderer.brandImage(size: 128))
                            .resizable()
                            .interpolation(.high)
                            .frame(width: 84, height: 84)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(workspace.themePalette.border, lineWidth: 1)
                            )

                        VStack(alignment: .leading, spacing: 8) {
                            Text("Scribbles-N-Scripts")
                                .font(.system(size: 34, weight: .bold, design: .serif))
                            Text("Notebook-first drafting for long-form writing.")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Start a new manuscript, reopen a recent draft, or use Commands to jump straight into the workflow.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    HStack(spacing: 10) {
                        Button {
                            newProjectName = ""
                            showingNewProjectSheet = true
                        } label: {
                            Label("New Project", systemImage: "square.and.pencil")
                        }
                        .buttonStyle(.borderedProminent)

                        Button {
                            showingOpenProjectPicker = true
                        } label: {
                            Label("Open Project", systemImage: "folder")
                        }
                        .buttonStyle(.bordered)

                        Button {
                            commandPaletteQuery = ""
                            showingCommandPalette = true
                        } label: {
                            Label("Commands", systemImage: "command")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(28)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(workspace.themePalette.chrome, in: RoundedRectangle(cornerRadius: 26, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 26, style: .continuous)
                        .stroke(workspace.themePalette.border, lineWidth: 1)
                )
                .shadow(color: workspace.themePalette.shadow, radius: 18, x: 0, y: 10)

                HStack(alignment: .top, spacing: 20) {
                    recentProjectsHomeSection(commands: commands)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                    homeGuideSection
                        .frame(width: min(geometry.size.width * 0.30, 320), alignment: .topLeading)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 32)
            .frame(maxWidth: 1240, alignment: .leading)
        }
    }

    private func recentProjectsHomeSection(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Recent Projects")
                    .font(.title3.weight(.semibold))
                Spacer()
                if commands.hasStaleRecentProjects {
                    Button("Clean Missing") {
                        pendingRecentAction = .cleanupMissing
                        showingRecentActionConfirmation = true
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if commands.recentProjects.isEmpty {
                VStack(alignment: .center, spacing: 8) {
                    ContentUnavailableView(
                        "No Recent Projects",
                        systemImage: "books.vertical",
                        description: Text("Create a project or open an existing manuscript folder to begin building your workspace.")
                    )
                    Button("Help") {
                        NotificationCenter.default.post(name: .showHelpReference, object: "recent-projects-empty")
                    }
                    .buttonStyle(.borderless)
                }
                .frame(maxWidth: .infinity, minHeight: 240)
                .background(workspace.themePalette.card, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(workspace.themePalette.border, lineWidth: 1)
                )
                .shadow(color: workspace.themePalette.softShadow, radius: 14, x: 0, y: 8)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(commands.recentProjects.prefix(8)) { project in
                        Button {
                            actionNotice = commands.openProject(at: project.url)
                        } label: {
                            HStack(alignment: .center, spacing: 14) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(project.name)
                                        .font(.headline)
                                        .multilineTextAlignment(.leading)
                                    Text(project.url.path)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(workspace.themePalette.tint)
                            }
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(workspace.themePalette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(workspace.themePalette.border, lineWidth: 1)
                            )
                            .shadow(color: workspace.themePalette.softShadow, radius: 10, x: 0, y: 6)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var homeGuideSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Workspace Flow")
                .font(.title3.weight(.semibold))

            VStack(alignment: .leading, spacing: 12) {
                homeGuideRow(title: "Draft in context", detail: "Write in linear mode, split scenes, or jump into modular corkboard and outliner views.")
                homeGuideRow(title: "Track structure", detail: "Keep notes, entities, timeline events, tags, and metadata attached to the manuscript.")
                homeGuideRow(title: "Compile cleanly", detail: "Export to Markdown, HTML, DOCX, PDF, and EPUB from the same project.")
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Appearance")
                    .font(.headline)
                Text("Use Project Settings to save appearance presets, or open Commands and search for a theme or preset name to switch looks quickly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("First Steps")
                    .font(.headline)
                guidedHelpButton(title: "Start with the Welcome Screen", topicID: "welcome-screen")
                guidedHelpButton(title: "Learn the Command Palette", topicID: "command-palette")
                guidedHelpButton(title: "Understand the Inspector", topicID: "inspector")
                guidedHelpButton(title: "Search the Whole Project", topicID: "find-project")
            }
        }
        .padding(20)
        .background(workspace.themePalette.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
        .shadow(color: workspace.themePalette.softShadow, radius: 16, x: 0, y: 10)
    }

    private func homeGuideRow(title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(workspace.themePalette.tint)
                .frame(width: 10, height: 10)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func guidedHelpButton(title: String, topicID: String) -> some View {
        Button(title) {
            NotificationCenter.default.post(name: .showHelpReference, object: topicID)
        }
        .buttonStyle(.borderless)
        .font(.caption)
    }

    private func loadedWorkspaceView(commands: WorkspaceCommandBindings, geometry: GeometryProxy) -> AnyView {
        var view = AnyView(
            HSplitView {
                if workspace.activeEditorChromeVisibility.showSidebar {
                    sidebarPane
                }
                mainPane(commands: commands, geometry: geometry)
                if workspace.isInspectorVisible && workspace.activeEditorChromeVisibility.showInspector {
                    inspectorPane
                }
            }
            .padding(14)
            .background(workspace.themePalette.canvas)
        )
        view = AnyView(view.onChange(of: workspace.modeController.activeMode) { _, mode in
                workspace.handleModeChange(mode)
            })
        view = AnyView(view.onAppear {
                if commands.hasStaleRecentProjects {
                    pendingRecentAction = .cleanupMissing
                    showingRecentActionConfirmation = true
                }
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showProjectSwitcher)) { _ in
                projectSwitcherQuery = ""
                showingProjectSwitcher = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showProjectSettings)) { _ in
                showingProjectSettings = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showImportExport)) { _ in
                showingImportExport = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showTimelineSheet)) { _ in
                showingTimelineSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showEntitiesSheet)) { _ in
                showingEntitiesSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showSourcesSheet)) { _ in
                showingSourcesSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showNotesSheet)) { _ in
                showingNotesSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showScratchpadSheet)) { _ in
                showingScratchpadSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showMoveSceneSheet)) { _ in
                showingMoveSceneSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showCommandPalette)) { _ in
                commandPaletteQuery = ""
                showingCommandPalette = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showInlineSearch)) { _ in
                commands.showInlineSearch()
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showGoalsDashboard)) { _ in
                showingGoalsDashboard = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showProjectSearch)) { _ in
                commands.showProjectSearch()
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .requestClearRecentProjects)) { _ in
                pendingRecentAction = .clearAll
                showingRecentActionConfirmation = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .requestCleanupMissingRecentProjects)) { _ in
                pendingRecentAction = .cleanupMissing
                showingRecentActionConfirmation = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showSaveAsSheet)) { _ in
                saveAsProjectName = workspace.projectDisplayName
                showingSaveAsSheet = true
            })
        view = AnyView(view.onReceive(NotificationCenter.default.publisher(for: .showRenameSheet)) { _ in
                renameProjectName = workspace.projectDisplayName
                showingRenameSheet = true
            })
        view = AnyView(view.fileImporter(
            isPresented: $showingOpenProjectPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let folder = urls.first else { return }
                actionNotice = commands.openProject(at: folder)
            case let .failure(error):
                actionNotice = "Could not open that project folder: \(error.localizedDescription)"
            }
        })
        view = AnyView(view.fileImporter(
            isPresented: $showingImportPicker,
            allowedContentTypes: [.plainText, .text, .utf8PlainText, UTType(filenameExtension: "md") ?? .plainText],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let file = urls.first else { return }
                actionNotice = workspace.importScenes(from: file)
            case let .failure(error):
                actionNotice = "Could not import that file: \(error.localizedDescription)"
            }
        })
        view = AnyView(view.fileImporter(
            isPresented: $showingResearchImportPicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let file = urls.first, let sourceID = pendingResearchImportSourceID else { return }
                actionNotice = workspace.importResearchFile(from: file, into: sourceID)
            case let .failure(error):
                actionNotice = "Could not import that research file: \(error.localizedDescription)"
            }
            pendingResearchImportSourceID = nil
        })
        view = AnyView(view.sheet(isPresented: $showingNewProjectSheet) {
            NewProjectSheet(
                title: "Create New Project",
                actionLabel: "Create",
                projectName: $newProjectName,
                onCancel: { showingNewProjectSheet = false },
                onCreate: {
                    actionNotice = commands.createProject(named: newProjectName)
                    showingNewProjectSheet = false
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingSaveAsSheet) {
            NewProjectSheet(
                title: "Save Project As",
                actionLabel: "Save As",
                projectName: $saveAsProjectName,
                onCancel: { showingSaveAsSheet = false },
                onCreate: {
                    actionNotice = commands.saveProjectAs(named: saveAsProjectName)
                    showingSaveAsSheet = false
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingRenameSheet) {
            NewProjectSheet(
                title: "Rename Project",
                actionLabel: "Rename",
                projectName: $renameProjectName,
                onCancel: { showingRenameSheet = false },
                onCreate: {
                    actionNotice = commands.renameProject(to: renameProjectName)
                    showingRenameSheet = false
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingProjectSwitcher) {
            ProjectSwitcherSheet(
                query: $projectSwitcherQuery,
                projects: commands.switchableProjects,
                onCancel: { showingProjectSwitcher = false },
                onSelect: { entry in
                    actionNotice = commands.openProject(at: entry.url)
                    showingProjectSwitcher = false
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingCommandPalette) {
            CommandPaletteSheet(
                workspace: workspace,
                query: $commandPaletteQuery,
                windowWidth: geometry.size.width,
                onCancel: { showingCommandPalette = false },
                onNotice: { notice in
                    actionNotice = notice
                },
                onShowNewProject: {
                    showingNewProjectSheet = true
                },
                onShowOpenProject: {
                    showingOpenProjectPicker = true
                },
                onShowSaveAs: {
                    saveAsProjectName = workspace.projectDisplayName
                    showingSaveAsSheet = true
                },
                onShowRename: {
                    renameProjectName = workspace.projectDisplayName
                    showingRenameSheet = true
                },
                onShowProjectSettings: {
                    showingProjectSettings = true
                },
                onShowImportExport: {
                    showingImportExport = true
                },
                onShowTimeline: {
                    showingTimelineSheet = true
                },
                onShowEntities: {
                    showingEntitiesSheet = true
                },
                onShowSources: {
                    showingSourcesSheet = true
                },
                onShowNotes: {
                    showingNotesSheet = true
                },
                onShowScratchpad: {
                    showingScratchpadSheet = true
                },
                onShowHelp: { entryID in
                    helpReferenceEntryID = entryID
                    showingHelpReference = true
                },
                onShowProjectSwitcher: {
                    projectSwitcherQuery = ""
                    showingProjectSwitcher = true
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingGoalsDashboard) {
            GoalsDashboardSheet(goalsManager: workspace.goalsManager)
        })
        view = AnyView(view.sheet(isPresented: $showingProjectSettings) {
            ProjectSettingsSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingImportExport) {
            ImportExportSheet(
                workspace: workspace,
                onNotice: { notice in
                    actionNotice = notice
                },
                onImport: {
                    showingImportPicker = true
                }
            )
        })
        view = AnyView(view.sheet(isPresented: $showingTimelineSheet) {
            TimelineSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingEntitiesSheet) {
            EntityTrackerSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingSourcesSheet) {
            SourceLibrarySheet(workspace: workspace, onImportResearch: { sourceID in
                pendingResearchImportSourceID = sourceID
                showingResearchImportPicker = true
            }) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingNotesSheet) {
            NotesSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingScratchpadSheet) {
            ScratchpadSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(isPresented: $showingMoveSceneSheet) {
            MoveSceneToChapterSheet(workspace: workspace) { notice in
                actionNotice = notice
            }
        })
        view = AnyView(view.sheet(
            isPresented: Binding(
                get: { workspace.isSearchPanelVisible },
                set: { isVisible in
                    if !isVisible {
                        commands.hideSearch()
                    }
                }
            )
        ) {
            SearchPanelSheet(workspace: workspace) { message in
                actionNotice = message
            }
        })
        view = AnyView(view.alert(recentActionTitle, isPresented: $showingRecentActionConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Help") {
                NotificationCenter.default.post(name: .showHelpReference, object: "open-recent")
            }
            Button(recentActionButtonTitle, role: .destructive) {
                performRecentAction(using: commands)
            }
        } message: {
            Text(recentActionMessage)
        })
        return view
    }

    @ViewBuilder
    private var sidebarPane: some View {
        VStack(spacing: 0) {
            SidebarView(
                navigationState: workspace.navigationState,
                nodes: sidebarNodes,
                baseFontSize: workspace.sidebarTextSize,
                onSelect: workspace.select(node:)
            )
            if workspace.stagingSceneCount > 0 {
                Divider()
                StagingTrayView(workspace: workspace) { notice in
                    actionNotice = notice
                }
                .frame(maxHeight: 240)
                .background(workspace.themePalette.panel)
            }
        }
        .font(.system(size: workspace.sidebarTextSize))
        .frame(minWidth: 220, idealWidth: 300, maxWidth: 420)
        .padding(10)
        .background(workspace.themePalette.sidebar, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
        .shadow(color: workspace.themePalette.softShadow, radius: 14, x: 0, y: 8)
    }

    private func mainPane(commands: WorkspaceCommandBindings, geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            workspaceChrome(commands: commands, geometry: geometry)
            breadcrumbBar
            if workspace.inspectorScene != nil {
                EditorEntityAssistantBar(workspace: workspace) { notice in
                    actionNotice = notice
                }
            }
            if workspace.modeController.activeMode == .modular {
                ModularBatchActionsBar(workspace: workspace) { notice in
                    actionNotice = notice
                }
            }
            ModeContainerView(
                modeController: workspace.modeController,
                linearState: workspace.linearState,
                modularState: workspace.modularState,
                navigationState: workspace.navigationState,
                editorState: workspace.editorState,
                splitState: workspace.splitEditorState,
                editorPresentation: workspace.editorPresentationSettings
            )
        }
        .background(workspace.themePalette.panel, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
        .shadow(color: workspace.themePalette.shadow, radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var inspectorPane: some View {
        InspectorPanelView(
            workspace: workspace,
            onNotice: { notice in
                actionNotice = notice
            },
            onShowMetadataSchema: {
                showingProjectSettings = true
            }
        )
        .frame(minWidth: 280, idealWidth: 340, maxWidth: 460)
        .padding(10)
        .background(workspace.themePalette.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
        .shadow(color: workspace.themePalette.softShadow, radius: 14, x: 0, y: 8)
    }

    private func workspaceChrome(commands: WorkspaceCommandBindings, geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: AppIconRenderer.brandImage(size: 56))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(workspace.themePalette.border, lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    Text(workspace.projectDisplayName)
                        .font(.title3.weight(.semibold))
                    Text("Long-form writing workspace")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(spacing: 8) {
                    chromeBadge(
                        title: workspace.hasUnsavedChanges ? "Unsaved changes" : "All changes saved",
                        tone: workspace.hasUnsavedChanges ? .orange : .secondary
                    )
                    chromeBadge(
                        title: "Session \(workspace.goalsManager.sessionProgressText())",
                        tone: .secondary
                    )
                    if let splitNotice {
                        chromeBadge(title: splitNotice, tone: .secondary)
                    }
                }
            }

            if let actionNotice {
                chromeNoticeRow(actionNotice)
            }

            if let recentUndoMessage {
                HStack(spacing: 8) {
                    chromeNoticeRow(recentUndoMessage)
                    Button("Undo") {
                        if let recentUndoSnapshot {
                            commands.restoreRecentProjects(from: recentUndoSnapshot)
                            actionNotice = "Recent project changes undone."
                        }
                        recentUndoSnapshot = nil
                        self.recentUndoMessage = nil
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }

            if workspace.isRecoveryMode {
                recoveryChromeBanner
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chromePrimaryButton("Commands") {
                        commandPaletteQuery = ""
                        showingCommandPalette = true
                    }
                    chromePrimaryButton("Find") {
                        commands.showProjectSearch()
                    }
                    .disabled(!commands.canSearchProject)
                    chromePrimaryButton("Save") {
                        actionNotice = commands.saveProject() ?? "Project saved."
                    }
                    .disabled(!commands.canSaveProject)
                    if commands.projectActionsDisabledReason != nil || commands.workspaceActionsDisabledReason != nil || commands.searchActionsDisabledReason != nil {
                        Button("Why Is This Disabled?") {
                            NotificationCenter.default.post(name: .showHelpReference, object: "disabled-commands")
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                    }

                    Menu("Project") {
                        Button("New Project") {
                            newProjectName = ""
                            showingNewProjectSheet = true
                        }
                        Button("Open Project") {
                            showingOpenProjectPicker = true
                        }
                        Button("Switch Project") {
                            projectSwitcherQuery = ""
                            showingProjectSwitcher = true
                        }
                        Button("Reopen Last") {
                            actionNotice = commands.reopenLastProject()
                        }
                        .disabled(!commands.canReopenLastProject)
                        Divider()
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
                        Divider()
                        Button("Backup") {
                            actionNotice = commands.createBackup()
                        }
                        .disabled(!commands.canCreateBackup)
                        Button("Save + Backup") {
                            actionNotice = commands.saveAndBackup()
                        }
                        .disabled(!commands.canSaveAndBackup)
                    }

                    Menu("Create") {
                        Button("New Chapter") {
                            actionNotice = commands.createChapter()
                        }
                        .disabled(!commands.canCreateProjectContent)
                        Button("New Scene") {
                            actionNotice = commands.createScene()
                        }
                        .disabled(!commands.canCreateProjectContent)
                        if commands.canCreateSceneBelow {
                            Button("New Scene Below") {
                                actionNotice = commands.createSceneBelow()
                            }
                        }
                    }

                    Menu("Panels") {
                        Button("Writing Goals & Statistics") {
                            showingGoalsDashboard = true
                        }
                        Button("Project Settings") {
                            showingProjectSettings = true
                        }
                        .disabled(!workspace.hasOpenProject)
                        Button("Import / Export") {
                            showingImportExport = true
                        }
                        .disabled(!commands.canShowImportExport)
                        Divider()
                        Button("Timeline") {
                            showingTimelineSheet = true
                        }
                        .disabled(!commands.canCreateProjectContent)
                        Button("Entities") {
                            showingEntitiesSheet = true
                        }
                        .disabled(!commands.canCreateProjectContent)
                        Button("Sources") {
                            showingSourcesSheet = true
                        }
                        .disabled(!commands.canCreateProjectContent)
                        Button("Notes") {
                            showingNotesSheet = true
                        }
                        .disabled(!commands.canCreateProjectContent)
                    }

                    Menu("Workspace") {
                        Menu("Theme") {
                            ForEach(AppTheme.allCases, id: \.self) { theme in
                                Button {
                                    actionNotice = commands.setTheme(theme)
                                } label: {
                                    if commands.currentTheme == theme {
                                        Label(theme.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(theme.displayName)
                                    }
                                }
                            }
                        }
                        if !commands.appearancePresets.isEmpty {
                            Menu("Appearance Presets") {
                                ForEach(commands.appearancePresets) { preset in
                                    Button {
                                        actionNotice = commands.applyAppearancePreset(preset.id)
                                    } label: {
                                        Text(preset.name)
                                    }
                                }
                            }
                        }
                        Button(workspace.isInspectorVisible ? "Hide Inspector" : "Show Inspector") {
                            commands.toggleInspector()
                        }
                        .disabled(!commands.canToggleInspector)
                        if workspace.modeController.activeMode == .linear {
                            Button(commands.splitToggleTitle) {
                                toggleSplit(windowWidth: geometry.size.width)
                            }
                            .disabled(!commands.canToggleSplitEditor)
                            Button("Open in Split") {
                                actionNotice = commands.openSelectionInSplit(defaultWindowWidth: geometry.size.width)
                            }
                            .disabled(!commands.canOpenSelectionInSplit)
                        }
                    }

                    recentProjectsMenu(commands: commands)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(workspace.themePalette.chrome, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
        .padding([.top, .horizontal], 12)
    }

    private func recentProjectsMenu(commands: WorkspaceCommandBindings) -> some View {
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
                    pendingRecentAction = .clearAll
                    showingRecentActionConfirmation = true
                }
            }
            if commands.hasStaleRecentProjects {
                if !commands.recentProjects.isEmpty {
                    Divider()
                }
                Button("Clean Missing Entries") {
                    pendingRecentAction = .cleanupMissing
                    showingRecentActionConfirmation = true
                }
            }
        }
        .disabled(commands.recentProjects.isEmpty && !commands.hasStaleRecentProjects)
    }

    @ViewBuilder
    private var breadcrumbBar: some View {
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
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
            }
            .background(workspace.themePalette.panel.opacity(0.92), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(workspace.themePalette.border, lineWidth: 1)
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
        }
    }

    private func chromePrimaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
    }

    private func chromeBadge(title: String, tone: Color) -> some View {
        Text(title)
            .font(.caption.weight(.medium))
            .foregroundStyle(tone)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tone == .secondary ? workspace.themePalette.mutedBadge : tone.opacity(0.12))
            )
    }

    private func chromeNoticeRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            Spacer(minLength: 0)
            Button("Help") {
                NotificationCenter.default.post(name: .showHelpReference, object: "help-reference")
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(workspace.themePalette.notice, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
    }

    private var recoveryChromeBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery Mode")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.orange)
                if let details = workspace.recoveryModeDetails {
                    Text(details)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                if let summary = workspace.recoverySummary {
                    Text(summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            Spacer()
            Button("Export Recovery") {
                actionNotice = workspace.exportRecoveryProject(format: .markdown)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Export recovery manuscript")
            .accessibilityHint("Creates a salvage markdown export outside the damaged project")
            Button("Duplicate Recovery") {
                actionNotice = workspace.duplicateRecoveryProjectAsWritableCopy()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Duplicate recovery project")
            .accessibilityHint("Creates a writable recovered copy beside the damaged project")
            Button("Help") {
                NotificationCenter.default.post(name: .showHelpReference, object: "recovery-actions")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(10)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    private var sidebarNodes: [SidebarNode] {
        guard let project = workspace.projectManager.currentProject else { return [] }
        return SidebarHierarchyBuilder.build(project: project, filters: workspace.navigationState.activeFilters)
    }

    private func toggleSplit(windowWidth: CGFloat) {
        splitNotice = workspace.toggleSplit(windowWidth: windowWidth)
    }

    private var recentActionTitle: String {
        switch pendingRecentAction {
        case .clearAll: return "Clear Recent Projects?"
        case .cleanupMissing: return "Clean Missing Recent Entries?"
        case .none: return "Confirm Recent Action"
        }
    }

    private var recentActionButtonTitle: String {
        switch pendingRecentAction {
        case .clearAll: return "Clear"
        case .cleanupMissing: return "Clean"
        case .none: return "Confirm"
        }
    }

    private var recentActionMessage: String {
        switch pendingRecentAction {
        case .clearAll:
            return "Remove all recent project entries? You can undo immediately after this action."
        case .cleanupMissing:
            return "Remove recent entries that point to missing projects? You can undo immediately after this action."
        case .none:
            return "Proceed?"
        }
    }

    private func performRecentAction(using commands: WorkspaceCommandBindings) {
        guard let pendingRecentAction else { return }
        let before = commands.snapshotRecentProjects()
        switch pendingRecentAction {
        case .clearAll:
            commands.clearRecentProjects()
            recentUndoMessage = "Recent projects cleared."
            actionNotice = "Recent projects cleared."
        case .cleanupMissing:
            commands.cleanupMissingRecentProjects()
            recentUndoMessage = "Missing recent projects removed."
            actionNotice = "Missing recent projects removed."
        }
        recentUndoSnapshot = before
        self.pendingRecentAction = nil
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
            HStack(alignment: .top, spacing: 12) {
                Image(nsImage: AppIconRenderer.brandImage(size: 72))
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 52, height: 52)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text("Notebook-first drafting for long-form writing.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
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

private struct InspectorPanelView: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    let onShowMetadataSchema: () -> Void
    @Environment(\.appThemePalette) private var palette
    @State private var metadataFieldMessages: [String: String] = [:]
    @State private var tagInput = ""
    @State private var metadataDrafts: [String: String] = [:]
    @State private var chapterGoalDraft = ""
    @State private var sceneTitleDraft = ""
    @State private var sceneSynopsisDraft = ""
    @State private var chapterTitleDraft = ""
    @State private var chapterSynopsisDraft = ""
    @State private var selectedEntityID: UUID?
    @State private var selectedNoteID: UUID?
    @State private var entityNameDraft = ""
    @State private var entityNotesDraft = ""
    @State private var entityAliasesDraft = ""
    @State private var entityTypeDraft: EntityType = .character
    @State private var noteTitleDraft = ""
    @State private var noteFolderDraft = ""
    @State private var noteContentDraft = ""
    @State private var inspectorMode: InspectorMode = .context

    private enum InspectorMode: String, CaseIterable, Identifiable {
        case context
        case entity
        case note

        var id: String { rawValue }
    }

    private var scene: ManifestScene? {
        workspace.inspectorScene
    }

    private var chapter: ManifestChapter? {
        workspace.inspectorChapter
    }

    private var sceneTags: [Tag] {
        guard let scene else { return [] }
        let tagsByID = Dictionary(uniqueKeysWithValues: workspace.inspectorAvailableTags.map { ($0.id, $0) })
        return scene.tags.compactMap { tagsByID[$0] }.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private var tagSuggestions: [Tag] {
        let prefix = tagInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prefix.isEmpty else { return [] }
        let currentTagIDs = Set(scene?.tags ?? [])
        return workspace.inspectorAvailableTags
            .filter { !currentTagIDs.contains($0.id) && $0.name.localizedCaseInsensitiveContains(prefix) }
            .sorted { lhs, rhs in
                let lhsPrefix = lhs.name.lowercased().hasPrefix(prefix.lowercased())
                let rhsPrefix = rhs.name.lowercased().hasPrefix(prefix.lowercased())
                if lhsPrefix != rhsPrefix {
                    return lhsPrefix && !rhsPrefix
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(5)
            .map { $0 }
    }

    private var colorOptions: [ColorLabel?] {
        [nil] + ColorLabel.allCases.filter { $0 != .none }.map(Optional.some)
    }

    private var sceneLinkedNotes: [Note] {
        guard let scene else { return [] }
        return workspace.notesLinkedToScene(scene.id)
    }

    private var sceneMentionedEntities: [Entity] {
        guard let scene else { return [] }
        return workspace.entitiesMentioned(in: scene.id)
    }

    private var selectedEntity: Entity? {
        guard let selectedEntityID else { return nil }
        return workspace.entities.first(where: { $0.id == selectedEntityID })
    }

    private var selectedNote: Note? {
        guard let selectedNoteID else { return nil }
        return workspace.notes.first(where: { $0.id == selectedNoteID })
    }

    private let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Inspector")
                            .font(.headline)
                        Text("Scene context, metadata, notes, and entity detail")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Menu("Scene Actions") {
                        if workspace.canCreateSceneBelow {
                            Button("New Scene Below") {
                                onNotice(workspace.createSceneBelowCurrent())
                            }
                        }
                        if workspace.canDuplicateSelectedScene {
                            Button("Duplicate Scene") {
                                onNotice(workspace.duplicateSelectedScene())
                            }
                        }
                        if workspace.canMoveSelectedSceneUp {
                            Button("Move Up") {
                                onNotice(workspace.moveSelectedSceneUp())
                            }
                        }
                        if workspace.canMoveSelectedSceneDown {
                            Button("Move Down") {
                                onNotice(workspace.moveSelectedSceneDown())
                            }
                        }
                        if workspace.canOpenSelectionInSplit {
                            Button("Open in Split") {
                                onNotice(workspace.openSelectionInSplit())
                            }
                        }
                        if workspace.canRevealSelectionInSidebar {
                            Button("Reveal in Sidebar") {
                                onNotice(workspace.revealSelectionInSidebar())
                            }
                        }
                        if workspace.canMoveSelectedSceneToAnotherChapter {
                            Button("Move to Chapter") {
                                NotificationCenter.default.post(name: .showMoveSceneSheet, object: nil)
                            }
                        }
                        if workspace.canSendSelectedSceneToStaging {
                            Button("Send to Staging") {
                                onNotice(workspace.sendSelectedSceneToStaging())
                            }
                        }
                        if workspace.inspectorScene?.parentChapterId == nil && !workspace.stagingRecoveryTargetChapters.isEmpty {
                            Button("Move Out of Staging") {
                                onNotice(workspace.moveSelectedSceneOutOfStaging())
                            }
                        }
                    }
                    .controlSize(.small)
                    Button("Project Settings") {
                        onShowMetadataSchema()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    Button("Hide") {
                        workspace.toggleInspector()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Picker("Inspector Mode", selection: $inspectorMode) {
                    Text("Context").tag(InspectorMode.context)
                    Text("Entity").tag(InspectorMode.entity)
                    Text("Note").tag(InspectorMode.note)
                }
                .pickerStyle(.segmented)
                InlineHelpTopics(topicIDs: ["inspector", "inspector-modes"])

                switch inspectorMode {
                case .context:
                    if let scene {
                        sceneSection(scene)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            ContentUnavailableView(
                                "No Scene Selected",
                                systemImage: "sidebar.right",
                                description: Text("Select a scene to edit tags, status, color labels, and metadata.")
                            )
                            Button("Help with Inspector") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "inspector")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                    if let chapter {
                        chapterSection(chapter)
                    }
                case .entity:
                    entityInspectorSection
                case .note:
                    noteInspectorSection
                }
            }
            .padding(16)
        }
        .font(.system(size: workspace.inspectorTextSize))
        .onAppear(perform: syncDraftsFromWorkspace)
        .onChange(of: workspace.inspectorScene?.id) { _, _ in
            syncDraftsFromWorkspace()
        }
        .onChange(of: workspace.inspectorChapter?.id) { _, _ in
            syncDraftsFromWorkspace()
        }
        .onChange(of: selectedEntityID) { _, _ in
            syncEntityDrafts()
        }
        .onChange(of: selectedNoteID) { _, _ in
            syncNoteDrafts()
        }
    }

    @ViewBuilder
    private var entityInspectorSection: some View {
        GroupBox("Entity Detail") {
            VStack(alignment: .leading, spacing: 12) {
                InlineHelpTopics(topicIDs: ["inspector-modes", "entity-relationships", "entities"])
                if sceneMentionedEntities.isEmpty {
                    Text("No tracked entities are linked to the current scene.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Entities") {
                        NotificationCenter.default.post(name: .showEntitiesSheet, object: nil)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Picker("Entity", selection: $selectedEntityID) {
                        ForEach(sceneMentionedEntities, id: \.id) { entity in
                            Text(entity.name).tag(Optional(entity.id))
                        }
                    }
                    .pickerStyle(.menu)
                    if let entity = selectedEntity {
                        TextField("Name", text: $entityNameDraft)
                            .textFieldStyle(.roundedBorder)
                        Picker("Type", selection: $entityTypeDraft) {
                            ForEach(EntityType.allCases, id: \.self) { type in
                                Text(type.rawValue.capitalized).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        TextField("Aliases (comma separated)", text: $entityAliasesDraft)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $entityNotesDraft)
                            .frame(minHeight: 80)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        HStack {
                            Spacer()
                            Button("Save Entity") {
                                onNotice(
                                    workspace.updateEntity(
                                        entity.id,
                                        name: entityNameDraft,
                                        type: entityTypeDraft,
                                        aliases: entityAliasesDraft.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
                                        fields: entity.fields,
                                        notes: entityNotesDraft
                                    )
                                )
                            }
                            .buttonStyle(.borderless)
                        }
                        let relationships = workspace.entityRelationships(entity.id)
                        if !relationships.isEmpty {
                            Text("Relationships")
                                .font(.caption.weight(.medium))
                            ForEach(relationships, id: \.target.id) { item in
                                Text(workspace.relationshipDescription(source: entity, relationship: item.relationship, target: item.target))
                                    .font(.caption2)
                            }
                        }
                        let linkedNotes = workspace.notesLinkedToEntity(entity.id)
                        if !linkedNotes.isEmpty {
                            Text("Notes")
                                .font(.caption.weight(.medium))
                            ForEach(linkedNotes, id: \.id) { note in
                                Button(note.title) {
                                    selectedNoteID = note.id
                                    inspectorMode = .note
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var noteInspectorSection: some View {
        GroupBox("Note Detail") {
            VStack(alignment: .leading, spacing: 12) {
                InlineHelpTopics(topicIDs: ["inspector-modes", "note-linking", "notes"])
                if sceneLinkedNotes.isEmpty {
                    Text("No notes are linked to the current scene.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Notes") {
                        workspace.focusNotes(onScene: scene?.id)
                        NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                    }
                    .buttonStyle(.borderless)
                } else {
                    Picker("Note", selection: $selectedNoteID) {
                        ForEach(sceneLinkedNotes, id: \.id) { note in
                            Text(note.title).tag(Optional(note.id))
                        }
                    }
                    .pickerStyle(.menu)
                    if let note = selectedNote {
                        TextField("Title", text: $noteTitleDraft)
                            .textFieldStyle(.roundedBorder)
                        TextField("Folder", text: $noteFolderDraft)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $noteContentDraft)
                            .frame(minHeight: 100)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        HStack {
                            Spacer()
                            Button("Save Note") {
                                onNotice(
                                    workspace.updateNote(
                                        note.id,
                                        title: noteTitleDraft,
                                        content: noteContentDraft,
                                        folder: noteFolderDraft,
                                        linkedSceneIDs: note.linkedSceneIds,
                                        linkedEntityIDs: note.linkedEntityIds
                                    )
                                )
                            }
                            .buttonStyle(.borderless)
                        }
                        if !note.linkedEntityIds.isEmpty {
                            Text("Linked Entities")
                                .font(.caption.weight(.medium))
                            ForEach(note.linkedEntityIds, id: \.self) { entityID in
                                Button(workspace.entityNameForDisplay(entityID)) {
                                    selectedEntityID = entityID
                                    inspectorMode = .entity
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sceneSection(_ scene: ManifestScene) -> some View {
        GroupBox("Scene") {
            VStack(alignment: .leading, spacing: 12) {
                editableInspectorTitleRow(label: "Title", text: $sceneTitleDraft, saveLabel: "Save Title") {
                    onNotice(workspace.setInspectorSceneTitle(sceneTitleDraft))
                }
                if let chapterTitle = chapter?.title {
                    inspectorRow("Chapter", value: chapterTitle)
                }
                inspectorRow("Words", value: "\(scene.wordCount)")
                VStack(alignment: .leading, spacing: 6) {
                    Text("Synopsis")
                        .font(.caption.weight(.medium))
                    TextEditor(text: $sceneSynopsisDraft)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.secondary.opacity(0.2))
                        )
                    HStack {
                        Spacer()
                        Button("Save Synopsis") {
                            onNotice(workspace.setInspectorSceneSynopsis(sceneSynopsisDraft))
                        }
                        .buttonStyle(.borderless)
                    }
                }

                Picker("Status", selection: Binding(
                    get: { scene.status },
                    set: { status in
                        onNotice(workspace.setInspectorSceneStatus(status))
                    }
                )) {
                    ForEach(ContentStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }

                Picker("Color Label", selection: Binding(
                    get: { scene.colorLabel },
                    set: { label in
                        onNotice(workspace.setInspectorSceneColorLabel(label))
                    }
                )) {
                    Text("None").tag(Optional<ColorLabel>.none)
                    ForEach(ColorLabel.allCases.filter { $0 != .none }, id: \.self) { label in
                        Text(workspace.inspectorColorLabelNames[label] ?? label.rawValue.capitalized).tag(Optional(label))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Tags")
                        .font(.subheadline.weight(.medium))
                    if sceneTags.isEmpty {
                        Text("No tags assigned.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(sceneTags) { tag in
                            HStack {
                                Text(tag.name)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(palette.tagFill(isEmphasized: true), in: Capsule())
                                    .foregroundStyle(palette.tagText)
                                Spacer()
                                Button("Remove") {
                                    onNotice(workspace.removeInspectorTag(tag.id))
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    HStack {
                        TextField("Add or create tag", text: $tagInput)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addTag)
                        Button("Add", action: addTag)
                            .disabled(tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if let exactSuggestion = tagSuggestions.first(where: {
                        $0.name.caseInsensitiveCompare(tagInput.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame
                    }) {
                        Text("Press Return to assign \(exactSuggestion.name).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if !tagInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Press Return to create and assign \(tagInput.trimmingCharacters(in: .whitespacesAndNewlines)).")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !tagSuggestions.isEmpty {
                        ForEach(tagSuggestions) { suggestion in
                            Button {
                                tagInput = suggestion.name
                                addTag()
                            } label: {
                                HStack {
                                    Text(suggestion.name)
                                    Spacer()
                                    Text("Assign")
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                            .font(.caption)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Metadata")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button("Manage Schema") {
                            onShowMetadataSchema()
                        }
                        .buttonStyle(.borderless)
                    }
                    if workspace.inspectorCustomFields.isEmpty {
                        Text("No custom metadata fields yet.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        let customFields = workspace.inspectorCustomFields
                        ForEach(Array(customFields.enumerated()), id: \.offset) { _, field in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(field.name)
                                    .font(.caption.weight(.medium))
                                metadataFieldEditor(field: field, scene: scene)
                                if let message = metadataFieldMessages[field.name] {
                                    Text(message)
                                        .font(.caption2)
                                        .foregroundStyle(message.hasPrefix("Saved") ? Color.secondary : Color.red)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Scene Notes")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button("Open Notes") {
                            workspace.focusNotes(onScene: scene.id)
                            NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                        }
                        .buttonStyle(.borderless)
                    }
                    let linkedNotes = workspace.notesLinkedToScene(scene.id)
                    if linkedNotes.isEmpty {
                        Text("No notes linked to this scene.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(linkedNotes, id: \.id) { note in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(note.title)
                                    .font(.caption.weight(.medium))
                                if !note.content.isEmpty {
                                    Text(note.content)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                            }
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mentioned Entities")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Button("Manage Entities") {
                            NotificationCenter.default.post(name: .showEntitiesSheet, object: nil)
                        }
                        .buttonStyle(.borderless)
                    }
                    let mentions = workspace.highlightedEntityMentions(in: scene.id)
                    if mentions.isEmpty {
                        Text("No tracked entity mentions in this scene.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(mentions, id: \.entity.id) { mention in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(mention.entity.name)
                                        .font(.caption.weight(.medium))
                                    Spacer()
                                    Button("Notes") {
                                        workspace.focusNotes(onEntity: mention.entity.id)
                                        NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                                    }
                                    .buttonStyle(.borderless)
                                }
                                Text(mention.snippet)
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.secondary)
                                    .textSelection(.enabled)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func chapterSection(_ chapter: ManifestChapter) -> some View {
        GroupBox("Chapter") {
            VStack(alignment: .leading, spacing: 12) {
                editableInspectorTitleRow(label: "Title", text: $chapterTitleDraft, saveLabel: "Save Title") {
                    onNotice(workspace.setInspectorChapterTitle(chapterTitleDraft))
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Synopsis")
                        .font(.caption.weight(.medium))
                    TextEditor(text: $chapterSynopsisDraft)
                        .frame(minHeight: 90)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(Color.secondary.opacity(0.2))
                        )
                    HStack {
                        Spacer()
                        Button("Save Synopsis") {
                            onNotice(workspace.setInspectorChapterSynopsis(chapterSynopsisDraft))
                        }
                        .buttonStyle(.borderless)
                    }
                }
                Picker("Status", selection: Binding(
                    get: { chapter.status },
                    set: { status in
                        onNotice(workspace.setInspectorChapterStatus(status))
                    }
                )) {
                    ForEach(ContentStatus.allCases, id: \.self) { status in
                        Text(status.rawValue).tag(status)
                    }
                }
                inspectorRow("Goal Progress", value: workspace.goalsManager.chapterGoalProgressText(chapterId: chapter.id) ?? "No goal")
                HStack {
                    TextField("Goal word count", text: $chapterGoalDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Set") {
                        let trimmed = chapterGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        let goal = Int(trimmed)
                        onNotice(workspace.setInspectorChapterGoal(goal))
                    }
                    .disabled(Int(chapterGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                    Button("Clear") {
                        chapterGoalDraft = ""
                        onNotice(workspace.setInspectorChapterGoal(nil))
                    }
                }
            }
        }
    }

    private func inspectorRow(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }

    private func editableInspectorTitleRow(
        label: String,
        text: Binding<String>,
        saveLabel: String,
        onSave: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(.secondary)
            HStack {
                TextField(label, text: text)
                    .textFieldStyle(.roundedBorder)
                Button(saveLabel, action: onSave)
                    .buttonStyle(.borderless)
                    .disabled(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }

    private func fieldTypeLabel(_ type: MetadataFieldType) -> String {
        switch type {
        case .text:
            return "Text"
        case .singleSelect:
            return "Single Select"
        case .multiSelect:
            return "Multi Select"
        case .number:
            return "Number"
        case .date:
            return "Date"
        }
    }

    private func syncEntityDrafts() {
        guard let entity = selectedEntity else {
            entityNameDraft = ""
            entityNotesDraft = ""
            entityAliasesDraft = ""
            entityTypeDraft = .character
            return
        }
        entityNameDraft = entity.name
        entityNotesDraft = entity.notes
        entityAliasesDraft = entity.aliases.joined(separator: ", ")
        entityTypeDraft = entity.entityType
    }

    private func syncNoteDrafts() {
        guard let note = selectedNote else {
            noteTitleDraft = ""
            noteFolderDraft = ""
            noteContentDraft = ""
            return
        }
        noteTitleDraft = note.title
        noteFolderDraft = note.folder ?? ""
        noteContentDraft = note.content
    }

    private func syncDraftsFromWorkspace() {
        if let scene = workspace.inspectorScene {
            sceneTitleDraft = scene.title
            metadataDrafts = scene.metadata
            sceneSynopsisDraft = scene.synopsis
        } else {
            sceneTitleDraft = ""
            metadataDrafts = [:]
            sceneSynopsisDraft = ""
        }
        chapterTitleDraft = workspace.inspectorChapter?.title ?? ""
        if let chapter = workspace.inspectorChapter, let goal = chapter.goalWordCount {
            chapterGoalDraft = "\(goal)"
        } else {
            chapterGoalDraft = ""
        }
        chapterSynopsisDraft = workspace.inspectorChapter?.synopsis ?? ""
        if selectedEntity == nil {
            selectedEntityID = sceneMentionedEntities.first?.id
        }
        if selectedNote == nil {
            selectedNoteID = sceneLinkedNotes.first?.id
        }
        syncEntityDrafts()
        syncNoteDrafts()
    }

    @ViewBuilder
    private func metadataFieldEditor(field: CustomMetadataField, scene: ManifestScene) -> some View {
        switch field.fieldType {
        case .text, .number:
            HStack {
                TextField(
                    field.fieldType == .number ? "Numeric value" : "Value",
                    text: Binding(
                        get: { metadataDrafts[field.name] ?? scene.metadata[field.name] ?? "" },
                        set: { metadataDrafts[field.name] = $0 }
                    )
                )
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    commitMetadataValue(field.name, value: metadataDrafts[field.name] ?? "")
                }
                if field.fieldType == .number {
                    Stepper("", onIncrement: {
                        stepNumericValue(field.name, delta: 1)
                    }, onDecrement: {
                        stepNumericValue(field.name, delta: -1)
                    })
                    .labelsHidden()
                }
                Button("Save") {
                    commitMetadataValue(field.name, value: metadataDrafts[field.name] ?? "")
                }
                .buttonStyle(.borderless)
            }
        case .singleSelect:
            Picker(
                field.name,
                selection: Binding(
                    get: { metadataDrafts[field.name] ?? scene.metadata[field.name] ?? field.options.first ?? "" },
                    set: { value in
                        metadataDrafts[field.name] = value
                        commitMetadataValue(field.name, value: value)
                    }
                )
            ) {
                ForEach(field.options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .labelsHidden()
        case .multiSelect:
            VStack(alignment: .leading, spacing: 4) {
                ForEach(field.options, id: \.self) { option in
                    Toggle(
                        option,
                        isOn: Binding(
                            get: { multiSelectValues(for: field, scene: scene).contains(option) },
                            set: { isSelected in
                                updateMultiSelectValue(field: field, scene: scene, option: option, isSelected: isSelected)
                            }
                        )
                    )
                    .toggleStyle(.checkbox)
                }
            }
        case .date:
            HStack {
                DatePicker(
                    "",
                    selection: Binding(
                        get: { dateValue(for: field, scene: scene) },
                        set: { value in
                            let stringValue = metadataDateFormatter.string(from: value)
                            metadataDrafts[field.name] = stringValue
                            commitMetadataValue(field.name, value: stringValue)
                        }
                    ),
                    displayedComponents: .date
                )
                .labelsHidden()
                Button("Today") {
                    let stringValue = metadataDateFormatter.string(from: Date())
                    metadataDrafts[field.name] = stringValue
                    commitMetadataValue(field.name, value: stringValue)
                }
                .buttonStyle(.borderless)
                Button("Clear") {
                    metadataDrafts[field.name] = ""
                    commitMetadataValue(field.name, value: "")
                }
                .buttonStyle(.borderless)
            }
        }
    }

    private func multiSelectValues(for field: CustomMetadataField, scene: ManifestScene) -> Set<String> {
        let raw = metadataDrafts[field.name] ?? scene.metadata[field.name] ?? ""
        return Set(
            raw.split(separator: ",")
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        )
    }

    private func updateMultiSelectValue(field: CustomMetadataField, scene: ManifestScene, option: String, isSelected: Bool) {
        var selected = multiSelectValues(for: field, scene: scene)
        if isSelected {
            selected.insert(option)
        } else {
            selected.remove(option)
        }
        let joined = field.options.filter { selected.contains($0) }.joined(separator: ", ")
        metadataDrafts[field.name] = joined
        commitMetadataValue(field.name, value: joined)
    }

    private func dateValue(for field: CustomMetadataField, scene: ManifestScene) -> Date {
        let raw = metadataDrafts[field.name] ?? scene.metadata[field.name] ?? ""
        return metadataDateFormatter.date(from: raw) ?? Date()
    }

    private func commitMetadataValue(_ field: String, value: String) {
        let message = workspace.setInspectorSceneMetadata(field: field, value: value)
        metadataFieldMessages[field] = message ?? "Saved."
        onNotice(message)
    }

    private func stepNumericValue(_ field: String, delta: Int) {
        let current = Int((metadataDrafts[field] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0
        let next = current + delta
        metadataDrafts[field] = String(next)
        commitMetadataValue(field, value: String(next))
    }

    private func addTag() {
        let message = workspace.addInspectorTag(named: tagInput)
        onNotice(message)
        if message == nil {
            tagInput = ""
        }
    }
}

private struct ProjectSettingsSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var projectNameDraft = ""
    @State private var autosaveIntervalSeconds = 30
    @State private var backupIntervalMinutes = 30
    @State private var backupRetentionCount = 20
    @State private var editorFontDraft = ""
    @State private var editorFontSize = 14
    @State private var editorLineHeight = 1.6
    @State private var editorContentWidth = 860.0
    @State private var selectedTheme: AppTheme = .system
    @State private var appearancePresetNameDraft = ""
    @State private var editingAppearancePresetID: UUID?
    @State private var selectedStagingRecoveryChapterID: UUID?
    @State private var newFieldName = ""
    @State private var newFieldType: MetadataFieldType = .text
    @State private var newFieldOptions = ""
    @State private var fieldNameDrafts: [UUID: String] = [:]
    @State private var fieldOptionsDrafts: [UUID: String] = [:]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WorkspaceSheetHeader(
                    title: "Project Settings",
                    subtitle: "General preferences, staging recovery, and metadata schema live here.",
                    dismissLabel: "Done",
                    helpTopicID: "project-settings",
                    onDismiss: { dismiss() }
                )

                WorkspaceMetricStrip(items: [
                    ("Autosave", "\(autosaveIntervalSeconds)s"),
                    ("Backup", "\(backupIntervalMinutes)m"),
                    ("Retention", "\(backupRetentionCount) copies"),
                    ("Theme", selectedTheme.displayName),
                    ("Width", "\(Int(editorContentWidth)) pt")
                ])

                GroupBox("General") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            TextField("Project name", text: $projectNameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button("Rename") {
                                onNotice(workspace.renameCurrentProject(to: projectNameDraft))
                                syncDrafts()
                            }
                            .disabled(projectNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        HStack {
                            Stepper("Autosave: \(autosaveIntervalSeconds)s", value: $autosaveIntervalSeconds, in: 5...300, step: 5)
                            Stepper("Backup every \(backupIntervalMinutes)m", value: $backupIntervalMinutes, in: 5...240, step: 5)
                        }
                        HStack {
                            Stepper("Retain \(backupRetentionCount) backups", value: $backupRetentionCount, in: 1...200)
                            TextField("Editor font", text: $editorFontDraft)
                                .textFieldStyle(.roundedBorder)
                        }
                        HStack {
                            Stepper("Font size: \(editorFontSize)", value: $editorFontSize, in: 8...36)
                            Stepper(
                                "Line height: \(String(format: "%.1f", editorLineHeight))",
                                value: $editorLineHeight,
                                in: 1.0...3.0,
                                step: 0.1
                            )
                            Stepper(
                                "Editor width: \(Int(editorContentWidth))",
                                value: $editorContentWidth,
                                in: 520...1600,
                                step: 20
                            )
                            Picker("Theme", selection: $selectedTheme) {
                                ForEach(AppTheme.allCases, id: \.self) { theme in
                                    Text(theme.displayName).tag(theme)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        themePreviewStrip
                        HStack {
                            Spacer()
                            Button("Save Settings") {
                                onNotice(
                                    workspace.updateProjectSettings(
                                        autosaveIntervalSeconds: autosaveIntervalSeconds,
                                        backupIntervalMinutes: backupIntervalMinutes,
                                        backupRetentionCount: backupRetentionCount,
                                        editorFont: editorFontDraft,
                                        editorFontSize: editorFontSize,
                                        editorLineHeight: editorLineHeight,
                                        editorContentWidth: editorContentWidth,
                                        theme: selectedTheme
                                    )
                                )
                                syncDrafts()
                            }
                            .disabled(editorFontDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                    }
                }

                GroupBox("Appearance Presets") {
                    VStack(alignment: .leading, spacing: 12) {
                        InlineHelpTopics(topicIDs: ["appearance-presets", "themes-and-presets"])
                        Text("Save the current theme, font, editor width, and line spacing as reusable appearance combinations.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("Tip: presets also appear in the Workspace menu and Command Palette, so you can switch writing looks without reopening settings.")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack {
                            TextField("Preset name", text: $appearancePresetNameDraft)
                                .textFieldStyle(.roundedBorder)
                            Button(editingAppearancePresetID == nil ? "Save Current" : "Update Preset") {
                                onNotice(workspace.saveAppearancePreset(id: editingAppearancePresetID, name: appearancePresetNameDraft))
                                syncDrafts()
                            }
                            .disabled(appearancePresetNameDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            if editingAppearancePresetID != nil {
                                Button("Cancel") {
                                    editingAppearancePresetID = nil
                                    appearancePresetNameDraft = ""
                                }
                            }
                        }
                        if workspace.appearancePresets.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ContentUnavailableView(
                                    "No Appearance Presets",
                                    systemImage: "paintbrush.pointed",
                                    description: Text("Save a preferred writing look here to quickly restore the same theme, font, spacing, and editor width later.")
                                )
                                Button("Help") {
                                    NotificationCenter.default.post(name: .showHelpReference, object: "appearance-presets")
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(workspace.appearancePresets) { preset in
                                    appearancePresetCard(for: preset)
                                }
                            }
                        }
                    }
                }

                GroupBox("Staging Recovery") {
                    VStack(alignment: .leading, spacing: 12) {
                        InlineHelpTopics(topicIDs: ["staging-tray", "staging-recovery", "scene-actions"])
                        Text("\(workspace.stagingSceneCount) staged scene(s) currently parked outside the manuscript flow.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if workspace.stagingRecoveryTargetChapters.isEmpty {
                            Text("Create a chapter before moving staging scenes back into the manuscript.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Picker("Default chapter", selection: $selectedStagingRecoveryChapterID) {
                                ForEach(workspace.stagingRecoveryTargetChapters, id: \.id) { chapter in
                                    Text(chapter.title).tag(Optional(chapter.id))
                                }
                            }
                            .pickerStyle(.menu)
                            HStack {
                                Button("Move Selected Out of Staging") {
                                    onNotice(workspace.moveSelectedSceneOutOfStaging(toChapter: selectedStagingRecoveryChapterID))
                                }
                                .disabled(workspace.inspectorScene?.parentChapterId != nil || selectedStagingRecoveryChapterID == nil)
                                Button("Move All Staging Scenes") {
                                    guard let selectedStagingRecoveryChapterID else { return }
                                    onNotice(workspace.moveAllStagingScenes(toChapter: selectedStagingRecoveryChapterID))
                                }
                                .disabled(workspace.stagingSceneCount == 0 || selectedStagingRecoveryChapterID == nil)
                            }
                        }
                    }
                }

                GroupBox("Goals") {
                    HStack {
                        Text(projectGoalSummaryText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Open Goals Dashboard") {
                            NotificationCenter.default.post(name: .showGoalsDashboard, object: nil)
                        }
                        .buttonStyle(.borderless)
                    }
                }

                GroupBox("Metadata Schema") {
                    VStack(alignment: .leading, spacing: 16) {
                        InlineHelpTopics(topicIDs: ["metadata-schema", "project-settings-metadata"])
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Add Field")
                                .font(.subheadline.weight(.medium))
                            TextField("Field name", text: $newFieldName)
                                .textFieldStyle(.roundedBorder)
                            Picker("Field Type", selection: $newFieldType) {
                                Text("Text").tag(MetadataFieldType.text)
                                Text("Single Select").tag(MetadataFieldType.singleSelect)
                                Text("Multi Select").tag(MetadataFieldType.multiSelect)
                                Text("Number").tag(MetadataFieldType.number)
                                Text("Date").tag(MetadataFieldType.date)
                            }
                            .pickerStyle(.segmented)
                            if fieldTypeUsesOptions(newFieldType) {
                                TextField("Options (comma-separated)", text: $newFieldOptions)
                                    .textFieldStyle(.roundedBorder)
                            }
                            Button("Add Field") {
                                let options = newFieldOptions.split(separator: ",").map(String.init)
                                onNotice(workspace.addInspectorMetadataField(named: newFieldName, type: newFieldType, options: options))
                                newFieldName = ""
                                newFieldType = .text
                                newFieldOptions = ""
                                syncDrafts()
                            }
                            .disabled(newFieldName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        }
                        if workspace.inspectorCustomFields.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ContentUnavailableView(
                                    "No Metadata Fields",
                                    systemImage: "tray",
                                    description: Text("Create reusable scene metadata fields here, then fill in scene values from the inspector.")
                                )
                                Button("Help") {
                                    NotificationCenter.default.post(name: .showHelpReference, object: "metadata-schema")
                                }
                                .buttonStyle(.borderless)
                            }
                        } else {
                            VStack(alignment: .leading, spacing: 12) {
                                ForEach(Array(workspace.inspectorCustomFields.enumerated()), id: \.element.id) { index, field in
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            TextField(
                                                "Field name",
                                                text: Binding(
                                                    get: { fieldNameDrafts[field.id] ?? field.name },
                                                    set: { fieldNameDrafts[field.id] = $0 }
                                                )
                                            )
                                            .textFieldStyle(.roundedBorder)
                                            Text(fieldTypeLabel(field.fieldType))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Spacer()
                                            Button("Save") {
                                                onNotice(workspace.renameInspectorMetadataField(field.id, to: fieldNameDrafts[field.id] ?? field.name))
                                                syncDrafts()
                                            }
                                            .buttonStyle(.borderless)
                                            Button {
                                                onNotice(workspace.moveInspectorMetadataField(field.id, by: -1))
                                                syncDrafts()
                                            } label: {
                                                Image(systemName: "arrow.up")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(index == 0)
                                            Button {
                                                onNotice(workspace.moveInspectorMetadataField(field.id, by: 1))
                                                syncDrafts()
                                            } label: {
                                                Image(systemName: "arrow.down")
                                            }
                                            .buttonStyle(.borderless)
                                            .disabled(index == workspace.inspectorCustomFields.count - 1)
                                            Button("Delete") {
                                                onNotice(workspace.deleteInspectorMetadataField(field.id))
                                                syncDrafts()
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        if fieldTypeUsesOptions(field.fieldType) {
                                            HStack {
                                                TextField(
                                                    "Options (comma-separated)",
                                                    text: Binding(
                                                        get: { fieldOptionsDrafts[field.id] ?? field.options.joined(separator: ", ") },
                                                        set: { fieldOptionsDrafts[field.id] = $0 }
                                                    )
                                                )
                                                .textFieldStyle(.roundedBorder)
                                                Button("Save Options") {
                                                    let options = (fieldOptionsDrafts[field.id] ?? field.options.joined(separator: ", "))
                                                        .split(separator: ",")
                                                        .map(String.init)
                                                    onNotice(workspace.updateInspectorMetadataFieldOptions(field.id, options: options))
                                                    syncDrafts()
                                                }
                                                .buttonStyle(.borderless)
                                            }
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 700, minHeight: 620)
        .onAppear(perform: syncDrafts)
    }

    private func syncDrafts() {
        projectNameDraft = workspace.projectDisplayName
        if let settings = workspace.projectSettings {
            autosaveIntervalSeconds = settings.autosaveIntervalSeconds
            backupIntervalMinutes = settings.backupIntervalMinutes
            backupRetentionCount = settings.backupRetentionCount
            editorFontDraft = settings.editorFont
            editorFontSize = settings.editorFontSize
            editorLineHeight = settings.editorLineHeight
            editorContentWidth = settings.editorContentWidth
            selectedTheme = settings.theme
        }
        if let editingAppearancePresetID,
           let preset = workspace.appearancePresets.first(where: { $0.id == editingAppearancePresetID }) {
            appearancePresetNameDraft = preset.name
        } else if editingAppearancePresetID == nil, appearancePresetNameDraft.isEmpty {
            appearancePresetNameDraft = ""
        }
        selectedStagingRecoveryChapterID = workspace.stagingRecoveryTargetChapters.first?.id
        fieldNameDrafts = Dictionary(uniqueKeysWithValues: workspace.inspectorCustomFields.map { ($0.id, $0.name) })
        fieldOptionsDrafts = Dictionary(uniqueKeysWithValues: workspace.inspectorCustomFields.map { ($0.id, $0.options.joined(separator: ", ")) })
    }

    private func fieldTypeUsesOptions(_ type: MetadataFieldType) -> Bool {
        type == .singleSelect || type == .multiSelect
    }

    private var themePreviewStrip: some View {
        HStack(spacing: 8) {
            ForEach(AppTheme.allCases, id: \.self) { theme in
                let palette = AppThemePalette.forTheme(theme)
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette.canvas)
                            .frame(width: 18, height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette.tint)
                            .frame(width: 18, height: 18)
                    }
                    Text(theme.displayName)
                        .font(.caption2)
                        .lineLimit(1)
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme == selectedTheme ? palette.card : workspace.themePalette.mutedBadge)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(theme == selectedTheme ? palette.tint : workspace.themePalette.border, lineWidth: theme == selectedTheme ? 2 : 1)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10))
                .onTapGesture {
                    selectedTheme = theme
                }
            }
        }
    }

    private func appearancePresetCard(for preset: AppearancePreset) -> some View {
        let palette = AppThemePalette.forTheme(preset.theme)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(palette.tint)
                    .frame(width: 10, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text(preset.name)
                        .font(.headline)
                    Text("\(preset.theme.displayName) • \(preset.fontName) \(preset.fontSize) pt • \(String(format: "%.1f", preset.lineHeight)) line height • \(Int(preset.editorContentWidth)) pt width")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Apply") {
                    onNotice(workspace.applyAppearancePreset(preset.id))
                    syncDrafts()
                }
                Button("Edit Name") {
                    editingAppearancePresetID = preset.id
                    appearancePresetNameDraft = preset.name
                }
                .buttonStyle(.borderless)
                Button("Delete") {
                    onNotice(workspace.deleteAppearancePreset(preset.id))
                    syncDrafts()
                }
                .buttonStyle(.borderless)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Preview")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette.canvas)
                            .frame(width: 22, height: 18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(palette.border, lineWidth: 1)
                            )
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette.tint)
                            .frame(width: 22, height: 18)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(palette.notice)
                            .frame(width: 22, height: 18)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A manuscript line preview")
                            .font(.custom(preset.fontName, size: CGFloat(preset.fontSize), relativeTo: .body))
                            .lineSpacing(max(0, (preset.lineHeight - 1.0) * CGFloat(preset.fontSize) * 0.45))
                            .foregroundStyle(Color(palette.editorText))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(palette.border.opacity(0.9))
                            .frame(width: min(CGFloat(preset.editorContentWidth) * 0.22, 220), height: 3)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(palette.editorBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                )
            }
        }
        .padding(10)
        .background(workspace.themePalette.panel.opacity(0.75), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(workspace.themePalette.border, lineWidth: 1)
        )
    }

    private var projectGoalSummaryText: String {
        if let goal = workspace.goalsManager.projectGoalWordCount {
            return "Project goal: \(workspace.goalsManager.currentTotalWordCount) / \(goal) words"
        }
        return "Project goal: not set"
    }

    private func fieldTypeLabel(_ type: MetadataFieldType) -> String {
        switch type {
        case .text:
            return "Text"
        case .singleSelect:
            return "Single Select"
        case .multiSelect:
            return "Multi Select"
        case .number:
            return "Number"
        case .date:
            return "Date"
        }
    }
}

private struct MoveSceneToChapterSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedChapterID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Move Scene to Chapter")
                .font(.headline)
            if workspace.moveSceneTargetChapters.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ContentUnavailableView(
                        "No Available Chapters",
                        systemImage: "tray",
                        description: Text("Create another chapter before moving this scene.")
                    )
                    Button("Help") {
                        NotificationCenter.default.post(name: .showHelpReference, object: "move-to-chapter")
                    }
                    .buttonStyle(.borderless)
                }
            } else {
                Picker("Chapter", selection: $selectedChapterID) {
                    ForEach(workspace.moveSceneTargetChapters, id: \.id) { chapter in
                        Text(chapter.title).tag(Optional(chapter.id))
                    }
                }
                .pickerStyle(.inline)
            }
            HStack {
                Spacer()
                Button("Cancel") {
                    dismiss()
                }
                Button("Move") {
                    guard let selectedChapterID else { return }
                    onNotice(workspace.moveSelectedScene(toChapter: selectedChapterID))
                    dismiss()
                }
                .disabled(selectedChapterID == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 360, minHeight: 220)
        .onAppear {
            selectedChapterID = workspace.moveSceneTargetChapters.first?.id
        }
    }
}

private struct StagingTrayView: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @State private var selectedChapterID: UUID?
    @Environment(\.appThemePalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Staging Tray")
                        .font(.headline)
                    Text("\(workspace.stagingSceneCount) scene(s) waiting for reassignment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: "staging-tray")
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }

            if workspace.stagingScenes.isEmpty {
                Text("No staged scenes right now. Send scenes here when you want them parked outside the manuscript flow.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(workspace.stagingScenes, id: \.id) { scene in
                            Button {
                                workspace.navigateToScene(scene.id)
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(scene.title)
                                        Text("\(scene.wordCount) words")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if workspace.inspectorScene?.id == scene.id {
                                        Text("Selected")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(maxHeight: 120)
            }

            if !workspace.stagingRecoveryTargetChapters.isEmpty {
                Picker("Recover to", selection: $selectedChapterID) {
                    ForEach(workspace.stagingRecoveryTargetChapters, id: \.id) { chapter in
                        Text(chapter.title).tag(Optional(chapter.id))
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Button("Move Selected") {
                        onNotice(workspace.moveSelectedSceneOutOfStaging(toChapter: selectedChapterID))
                    }
                    .disabled(workspace.inspectorScene?.parentChapterId != nil || selectedChapterID == nil)

                    Button("Move All") {
                        guard let selectedChapterID else { return }
                        onNotice(workspace.moveAllStagingScenes(toChapter: selectedChapterID))
                    }
                    .disabled(workspace.stagingSceneCount == 0 || selectedChapterID == nil)
                }
            }
        }
        .padding(12)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .onAppear {
            selectedChapterID = workspace.stagingRecoveryTargetChapters.first?.id
        }
    }
}

private struct EditorEntityAssistantBar: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.appThemePalette) private var palette

    private var scene: ManifestScene? {
        workspace.inspectorScene
    }

    private var mentionedEntities: [Entity] {
        guard let scene else { return [] }
        return workspace.entitiesMentioned(in: scene.id)
    }

    private var availableEntities: [Entity] {
        let mentionedIDs = Set(mentionedEntities.map(\.id))
        return workspace.entities.filter { !mentionedIDs.contains($0.id) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Entity Assistant")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button("Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: "entity-assistant")
                }
                .buttonStyle(.borderless)
                .font(.caption2)
                if mentionedEntities.isEmpty {
                    Text("No tracked mentions in this scene yet.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    Text("\(mentionedEntities.count) tracked mention(s)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(mentionedEntities, id: \.id) { entity in
                        HStack(spacing: 6) {
                            Text(entity.name)
                                .font(.caption)
                            Button("Insert") {
                                onNotice(workspace.insertEntityMention(entity.id))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Insert \(entity.name)")
                            Button("Jump") {
                                onNotice(workspace.navigateToEntityPrimaryScene(entity.id))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Jump to \(entity.name)")
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.secondary.opacity(0.08), in: Capsule())
                    }
                    if !availableEntities.isEmpty {
                        Menu("Insert Tracked Entity") {
                            ForEach(availableEntities, id: \.id) { entity in
                                Button(entity.name) {
                                    onNotice(workspace.insertEntityMention(entity.id))
                                }
                            }
                        }
                        .accessibilityLabel("Insert tracked entity")
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(palette.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }
}

private struct ImportExportSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    let onImport: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var presetName = ""
    @State private var presetFormat: ExportFormat = .markdown
    @State private var presetFontFamily = "Menlo"
    @State private var presetFontSize = 14
    @State private var presetLineSpacing = 1.6
    @State private var presetChapterHeadingStyle = "h2"
    @State private var presetSceneBreakMarker = "***"
    @State private var presetHTMLTheme: CompileHTMLTheme = .parchment
    @State private var presetPageSize: CompilePageSize = .letter
    @State private var presetTemplateStyle: CompileTemplateStyle = .classic
    @State private var marginTop = 1.0
    @State private var marginBottom = 1.0
    @State private var marginLeft = 1.0
    @State private var marginRight = 1.0
    @State private var presetSubtitle = ""
    @State private var presetAuthor = ""
    @State private var includeTitlePage = true
    @State private var includeTableOfContents = false
    @State private var includeStagingArea = false
    @State private var languageCode = "en"
    @State private var publisherName = ""
    @State private var copyrightText = ""
    @State private var dedicationText = ""
    @State private var includeAboutAuthor = false
    @State private var aboutAuthorText = ""
    @State private var presetSectionOrder: CompileSectionOrder = .manuscript
    @State private var bibliographyText = ""
    @State private var appendixTitle = ""
    @State private var appendixContent = ""
    @State private var stylesheetName = ""
    @State private var customCSS = ""
    @State private var selectedSectionIDs: Set<UUID> = []
    @State private var editingPresetID: UUID?
    @State private var previewContent = ""
    @State private var previewFormat: ExportFormat = .html

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Import / Export",
                subtitle: "Compile the manuscript to project exports, or import Markdown and text files as new scenes.",
                dismissLabel: "Done",
                helpTopicID: "import-export",
                onDismiss: { dismiss() }
            )

            WorkspaceMetricStrip(items: [
                ("Format", presetFormat.rawValue.uppercased()),
                ("Sections", "\(selectedSectionIDs.count)"),
                ("Template", presetTemplateStyle.rawValue.capitalized),
                ("Theme", presetHTMLTheme.rawValue.capitalized)
            ])

            GroupBox("Export") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["import-export", "epub-export"])
                    Text(workspace.isRecoveryMode ? "Recovery exports are written beside the damaged project in a matching recovery-exports folder so the original files stay untouched." : "Exports are written into the project’s `exports/` folder. Save a setup when you want to reuse these exact export settings later.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        Button("Export Markdown") {
                            onNotice(workspace.isRecoveryMode ? workspace.exportRecoveryProject(format: .markdown) : workspace.exportProject(format: .markdown))
                        }
                        .accessibilityLabel("Export markdown")
                        .buttonStyle(.bordered)
                        Button("Export HTML") {
                            onNotice(workspace.isRecoveryMode ? workspace.exportRecoveryProject(format: .html) : workspace.exportProject(format: .html))
                        }
                        .accessibilityLabel("Export HTML")
                        .buttonStyle(.bordered)
                        Button("Export DOCX") {
                            onNotice(workspace.isRecoveryMode ? workspace.exportRecoveryProject(format: .docx) : workspace.exportProject(format: .docx))
                        }
                        .accessibilityLabel("Export DOCX")
                        .buttonStyle(.bordered)
                        Button("Export PDF") {
                            onNotice(workspace.isRecoveryMode ? workspace.exportRecoveryProject(format: .pdf) : workspace.exportProject(format: .pdf))
                        }
                        .accessibilityLabel("Export PDF")
                        .buttonStyle(.bordered)
                        Button("Export EPUB") {
                            onNotice(workspace.isRecoveryMode ? workspace.exportRecoveryProject(format: .epub) : workspace.exportProject(format: .epub))
                        }
                        .accessibilityLabel("Export EPUB")
                        .accessibilityHint("Creates an EPUB file in the project exports folder")
                        .buttonStyle(.borderedProminent)
                    }
                    if workspace.isRecoveryMode {
                        Button("Create Writable Recovery Copy") {
                            onNotice(workspace.duplicateRecoveryProjectAsWritableCopy())
                        }
                        .accessibilityLabel("Duplicate as writable recovery copy")
                        .accessibilityHint("Creates a new writable project from the recovered manuscript")
                        .buttonStyle(.bordered)
                    }
                }
            }

            if workspace.isRecoveryMode {
                GroupBox("Recovery Notes") {
                    VStack(alignment: .leading, spacing: 8) {
                        InlineHelpTopics(topicIDs: ["recovery-actions", "recovery-banner"])
                        if let details = workspace.recoveryModeDetails {
                            Text(details)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        ForEach(Array(workspace.recoveryDiagnostics.enumerated()), id: \.offset) { _, diagnostic in
                            HStack(alignment: .top, spacing: 8) {
                                Text(diagnostic.severity.rawValue.capitalized)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(diagnostic.severity == .error ? .red : (diagnostic.severity == .warning ? .orange : .secondary))
                                Text(diagnostic.message)
                                    .font(.caption)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                }
            }

            GroupBox("Saved Export Setups") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        InlineHelpTopics(topicIDs: ["compile-presets", "export-review"])
                        Text("Build reusable export setups for print, sharing, or e-book output, then preview or export with the current settings below.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("Preset name", text: $presetName)
                            .textFieldStyle(.roundedBorder)
                        HStack {
                            Picker("Format", selection: $presetFormat) {
                                Text("Markdown").tag(ExportFormat.markdown)
                                Text("HTML").tag(ExportFormat.html)
                                Text("DOCX").tag(ExportFormat.docx)
                                Text("PDF").tag(ExportFormat.pdf)
                                Text("EPUB").tag(ExportFormat.epub)
                            }
                            .pickerStyle(.menu)
                            TextField("Font family", text: $presetFontFamily)
                                .textFieldStyle(.roundedBorder)
                            Stepper("Size \(presetFontSize)", value: $presetFontSize, in: 8...36)
                            Stepper("Spacing \(String(format: "%.1f", presetLineSpacing))", value: $presetLineSpacing, in: 1.0...3.0, step: 0.1)
                        }
                        HStack {
                            Picker("Chapter Heading", selection: $presetChapterHeadingStyle) {
                                Text("H1").tag("h1")
                                Text("H2").tag("h2")
                            }
                            .pickerStyle(.menu)
                            TextField("Scene break marker", text: $presetSceneBreakMarker)
                                .textFieldStyle(.roundedBorder)
                        }
                        Picker("HTML Theme", selection: $presetHTMLTheme) {
                            ForEach(CompileHTMLTheme.allCases, id: \.self) { theme in
                                Text(theme.rawValue.capitalized).tag(theme)
                            }
                        }
                        .pickerStyle(.menu)
                        HStack {
                            Picker("Page Size", selection: $presetPageSize) {
                                ForEach(CompilePageSize.allCases, id: \.self) { size in
                                    Text(size.rawValue.uppercased()).tag(size)
                                }
                            }
                            .pickerStyle(.menu)
                            Picker("Template", selection: $presetTemplateStyle) {
                                ForEach(CompileTemplateStyle.allCases, id: \.self) { style in
                                    Text(style.rawValue.capitalized).tag(style)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                        TextField("Stylesheet name", text: $stylesheetName)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $customCSS)
                            .frame(height: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                            .overlay(alignment: .topLeading) {
                                if customCSS.isEmpty {
                                    Text("Custom CSS / stylesheet overrides")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 6)
                                }
                            }
                        HStack {
                            Stepper("Top \(String(format: "%.2f", marginTop))in", value: $marginTop, in: 0.25...3.0, step: 0.25)
                            Stepper("Bottom \(String(format: "%.2f", marginBottom))in", value: $marginBottom, in: 0.25...3.0, step: 0.25)
                        }
                        HStack {
                            Stepper("Left \(String(format: "%.2f", marginLeft))in", value: $marginLeft, in: 0.25...3.0, step: 0.25)
                            Stepper("Right \(String(format: "%.2f", marginRight))in", value: $marginRight, in: 0.25...3.0, step: 0.25)
                        }
                        TextField("Subtitle", text: $presetSubtitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Author", text: $presetAuthor)
                            .textFieldStyle(.roundedBorder)
                        Toggle("Title Page", isOn: $includeTitlePage)
                        Toggle("Table of Contents", isOn: $includeTableOfContents)
                        Toggle("Include Staging Area", isOn: $includeStagingArea)
                        HStack {
                            TextField("Language code", text: $languageCode)
                                .textFieldStyle(.roundedBorder)
                            TextField("Publisher", text: $publisherName)
                                .textFieldStyle(.roundedBorder)
                        }
                        TextField("Copyright", text: $copyrightText)
                            .textFieldStyle(.roundedBorder)
                        TextField("Dedication", text: $dedicationText)
                            .textFieldStyle(.roundedBorder)
                        Toggle("About the Author", isOn: $includeAboutAuthor)
                        if includeAboutAuthor {
                            TextEditor(text: $aboutAuthorText)
                                .frame(height: 70)
                                .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        }
                        TextEditor(text: $bibliographyText)
                            .frame(height: 60)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                            .overlay(alignment: .topLeading) {
                                if bibliographyText.isEmpty {
                                    Text("Bibliography")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 6)
                                }
                            }
                        TextField("Appendix title", text: $appendixTitle)
                            .textFieldStyle(.roundedBorder)
                        Picker("Chapter Order", selection: $presetSectionOrder) {
                            ForEach(CompileSectionOrder.allCases, id: \.self) { order in
                                Text(order.rawValue.capitalized).tag(order)
                            }
                        }
                        .pickerStyle(.menu)
                        TextEditor(text: $appendixContent)
                            .frame(height: 70)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                            .overlay(alignment: .topLeading) {
                                if appendixContent.isEmpty {
                                    Text("Appendix content")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 6)
                                }
                            }
                        Text("Included chapters")
                            .font(.caption.weight(.medium))
                        ForEach(workspace.searchableChapters, id: \.id) { chapter in
                            Toggle(
                                chapter.title,
                                isOn: Binding(
                                    get: { selectedSectionIDs.contains(chapter.id) },
                                    set: { isSelected in
                                        if isSelected {
                                            selectedSectionIDs.insert(chapter.id)
                                        } else {
                                            selectedSectionIDs.remove(chapter.id)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                        let warnings = workspace.compileWarnings(
                            includedSectionIds: Array(selectedSectionIDs),
                            pageMargins: Margins(top: marginTop, bottom: marginBottom, left: marginLeft, right: marginRight),
                            format: presetFormat,
                            languageCode: languageCode,
                            publisherName: publisherName
                        )
                        GroupBox("Export Review") {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("\(presetFormat.rawValue.uppercased()) • \(selectedSectionIDs.count) chapter(s) • \(presetTemplateStyle.rawValue.capitalized) template")
                                    .font(.caption.weight(.medium))
                                Text("\(presetHTMLTheme.rawValue.capitalized) theme • \(presetPageSize.rawValue.uppercased()) • \(presetFontFamily) \(presetFontSize)pt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(frontMatterSummary)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                if warnings.isEmpty {
                                    Text("Current settings are ready for preview or export.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("\(warnings.count) warning(s) should be reviewed before export.")
                                        .font(.caption)
                                        .foregroundStyle(.orange)
                                }
                            }
                        }
                        if !warnings.isEmpty {
                            GroupBox("Export Warnings") {
                                VStack(alignment: .leading, spacing: 6) {
                                    ForEach(warnings, id: \.self) { warning in
                                        Text(warning)
                                            .font(.caption)
                                            .foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                        HStack {
                            Button("Save Preset") {
                                onNotice(
                                    workspace.saveCompilePreset(
                                        id: editingPresetID,
                                        name: presetName,
                                        format: presetFormat,
                                        includedSectionIds: Array(selectedSectionIDs),
                                        fontFamily: presetFontFamily,
                                        fontSize: presetFontSize,
                                        lineSpacing: presetLineSpacing,
                                        chapterHeadingStyle: presetChapterHeadingStyle,
                                        sceneBreakMarker: presetSceneBreakMarker,
                                        htmlTheme: presetHTMLTheme,
                                        pageSize: presetPageSize,
                                        templateStyle: presetTemplateStyle,
                                        pageMargins: Margins(top: marginTop, bottom: marginBottom, left: marginLeft, right: marginRight),
                                        subtitle: presetSubtitle,
                                        authorName: presetAuthor,
                                        includeTitlePage: includeTitlePage,
                                        includeTableOfContents: includeTableOfContents,
                                        includeStagingArea: includeStagingArea,
                                        languageCode: languageCode,
                                        publisherName: publisherName,
                                        copyrightText: copyrightText,
                                        dedicationText: dedicationText,
                                        includeAboutAuthor: includeAboutAuthor,
                                        aboutAuthorText: aboutAuthorText,
                                        sectionOrder: presetSectionOrder,
                                        bibliographyText: bibliographyText,
                                        appendixTitle: appendixTitle,
                                        appendixContent: appendixContent,
                                        stylesheetName: stylesheetName,
                                        customCSS: customCSS
                                    )
                                )
                                syncDrafts()
                            }
                            .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            Button("Export with Current Settings") {
                                onNotice(
                                    workspace.exportProjectDraft(
                                        format: presetFormat,
                                        includedSectionIds: Array(selectedSectionIDs),
                                        fontFamily: presetFontFamily,
                                        fontSize: presetFontSize,
                                        lineSpacing: presetLineSpacing,
                                        chapterHeadingStyle: presetChapterHeadingStyle,
                                        sceneBreakMarker: presetSceneBreakMarker,
                                        htmlTheme: presetHTMLTheme,
                                        pageSize: presetPageSize,
                                        templateStyle: presetTemplateStyle,
                                        pageMargins: Margins(top: marginTop, bottom: marginBottom, left: marginLeft, right: marginRight),
                                        subtitle: presetSubtitle,
                                        authorName: presetAuthor,
                                        includeTitlePage: includeTitlePage,
                                        includeTableOfContents: includeTableOfContents,
                                        includeStagingArea: includeStagingArea,
                                        languageCode: languageCode,
                                        publisherName: publisherName,
                                        copyrightText: copyrightText,
                                        dedicationText: dedicationText,
                                        includeAboutAuthor: includeAboutAuthor,
                                        aboutAuthorText: aboutAuthorText,
                                        sectionOrder: presetSectionOrder,
                                        bibliographyText: bibliographyText,
                                        appendixTitle: appendixTitle,
                                        appendixContent: appendixContent,
                                        stylesheetName: stylesheetName,
                                        customCSS: customCSS,
                                        recoveryMode: workspace.isRecoveryMode
                                    )
                                )
                            }
                            .disabled(!warnings.isEmpty)
                            Button("Refresh Preview") {
                                previewContent = workspace.compilePreview(
                                    format: previewFormat,
                                    includedSectionIds: Array(selectedSectionIDs),
                                    fontFamily: presetFontFamily,
                                    fontSize: presetFontSize,
                                    lineSpacing: presetLineSpacing,
                                    chapterHeadingStyle: presetChapterHeadingStyle,
                                    sceneBreakMarker: presetSceneBreakMarker,
                                    htmlTheme: presetHTMLTheme,
                                    pageSize: presetPageSize,
                                    templateStyle: presetTemplateStyle,
                                    pageMargins: Margins(top: marginTop, bottom: marginBottom, left: marginLeft, right: marginRight),
                                    subtitle: presetSubtitle,
                                    authorName: presetAuthor,
                                    includeTitlePage: includeTitlePage,
                                    includeTableOfContents: includeTableOfContents,
                                    includeStagingArea: includeStagingArea,
                                    languageCode: languageCode,
                                    publisherName: publisherName,
                                    copyrightText: copyrightText,
                                    dedicationText: dedicationText,
                                    includeAboutAuthor: includeAboutAuthor,
                                    aboutAuthorText: aboutAuthorText,
                                    sectionOrder: presetSectionOrder,
                                    bibliographyText: bibliographyText,
                                    appendixTitle: appendixTitle,
                                    appendixContent: appendixContent,
                                    stylesheetName: stylesheetName,
                                    customCSS: customCSS
                                ) ?? ""
                            }
                        }
                        if !warnings.isEmpty {
                            Text("Export with current settings is disabled until the warnings above are resolved.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Picker("Preview As", selection: $previewFormat) {
                            Text("Markdown").tag(ExportFormat.markdown)
                            Text("HTML").tag(ExportFormat.html)
                            Text("DOCX Preview").tag(ExportFormat.docx)
                            Text("PDF Preview").tag(ExportFormat.pdf)
                            Text("EPUB Preview").tag(ExportFormat.epub)
                        }
                        .pickerStyle(.segmented)
                        Text("Markdown and DOCX previews show the manuscript draft text. PDF and EPUB previews show the generated HTML layout.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextEditor(text: $previewContent)
                            .font(.system(.caption, design: .monospaced))
                            .frame(height: 160)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))

                        if !workspace.compilePresets.isEmpty {
                            Divider()
                            ForEach(workspace.compilePresets, id: \.id) { preset in
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(preset.name)
                                        Text("\(preset.format.rawValue.uppercased()) • \(preset.includedSectionIds.count) section(s) • \(preset.styleOverrides.templateStyle.rawValue.capitalized)")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Button("Export") {
                                        onNotice(workspace.exportProject(using: preset.id))
                                    }
                                    .buttonStyle(.borderless)
                                    Button("Edit") {
                                        loadPreset(preset)
                                    }
                                    .buttonStyle(.borderless)
                                    Button("Delete") {
                                        onNotice(workspace.deleteCompilePreset(preset.id))
                                        syncDrafts()
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 280)
            }

            GroupBox("Import") {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Import `.md` or `.txt` files into the current or first chapter. `##` headings create separate scenes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Choose Import File") {
                        onImport()
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 520)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
        .onAppear(perform: syncDrafts)
    }

    private func syncDrafts() {
        editingPresetID = nil
        presetName = ""
        presetFontFamily = workspace.projectSettings?.editorFont ?? "Menlo"
        presetFontSize = workspace.projectSettings?.editorFontSize ?? 14
        presetLineSpacing = workspace.projectSettings?.editorLineHeight ?? 1.6
        presetChapterHeadingStyle = "h2"
        presetSceneBreakMarker = "***"
        presetHTMLTheme = .parchment
        presetPageSize = .letter
        presetTemplateStyle = .classic
        marginTop = 1
        marginBottom = 1
        marginLeft = 1
        marginRight = 1
        presetSubtitle = ""
        presetAuthor = workspace.projectDisplayName
        includeTitlePage = true
        includeTableOfContents = false
        includeStagingArea = false
        languageCode = "en"
        publisherName = ""
        copyrightText = ""
        dedicationText = ""
        includeAboutAuthor = false
        aboutAuthorText = ""
        presetSectionOrder = .manuscript
        bibliographyText = ""
        appendixTitle = ""
        appendixContent = ""
        stylesheetName = ""
        customCSS = ""
        selectedSectionIDs = Set(workspace.searchableChapters.map(\.id))
        previewContent = ""
    }

    private func loadPreset(_ preset: CompilePreset) {
        editingPresetID = preset.id
        presetName = preset.name
        presetFormat = preset.format
        presetFontFamily = preset.styleOverrides.fontFamily
        presetFontSize = preset.styleOverrides.fontSize
        presetLineSpacing = preset.styleOverrides.lineSpacing
        presetChapterHeadingStyle = preset.styleOverrides.chapterHeadingStyle
        presetSceneBreakMarker = preset.styleOverrides.sceneBreakMarker
        presetHTMLTheme = preset.styleOverrides.htmlTheme
        presetPageSize = preset.styleOverrides.pageSize
        presetTemplateStyle = preset.styleOverrides.templateStyle
        marginTop = preset.styleOverrides.pageMargins.top
        marginBottom = preset.styleOverrides.pageMargins.bottom
        marginLeft = preset.styleOverrides.pageMargins.left
        marginRight = preset.styleOverrides.pageMargins.right
        presetSubtitle = preset.frontMatter.titlePageContent?.subtitle ?? ""
        presetAuthor = preset.frontMatter.titlePageContent?.author ?? workspace.projectDisplayName
        includeTitlePage = preset.frontMatter.includeTitlePage
        includeTableOfContents = preset.frontMatter.includeTableOfContents
        includeStagingArea = preset.frontMatter.includeStagingArea
        languageCode = preset.frontMatter.languageCode ?? "en"
        publisherName = preset.frontMatter.publisherName ?? ""
        copyrightText = preset.frontMatter.copyrightText ?? ""
        dedicationText = preset.frontMatter.dedicationText ?? ""
        includeAboutAuthor = preset.backMatter.includeAboutAuthor
        aboutAuthorText = preset.backMatter.aboutAuthorText ?? ""
        presetSectionOrder = preset.backMatter.sectionOrder
        bibliographyText = preset.backMatter.bibliographyText ?? ""
        appendixTitle = preset.backMatter.appendices.first?.title ?? ""
        appendixContent = preset.backMatter.appendices.first?.content ?? ""
        stylesheetName = preset.styleOverrides.stylesheetName ?? ""
        customCSS = preset.styleOverrides.customCSS ?? ""
        selectedSectionIDs = Set(preset.includedSectionIds)
        previewContent = ""
    }

    private var frontMatterSummary: String {
        var parts: [String] = []
        if includeTitlePage { parts.append("title page") }
        if includeTableOfContents { parts.append("table of contents") }
        if includeStagingArea { parts.append("staging included") }
        if includeAboutAuthor { parts.append("about author") }
        if parts.isEmpty {
            return "No optional front/back matter is enabled."
        }
        return "Includes \(parts.joined(separator: ", "))."
    }
}

private struct ModularBatchActionsBar: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @State private var selectedChapterID: UUID?

    var body: some View {
        HStack(spacing: 12) {
            Text("\(workspace.selectedModularSceneCount) scene(s) selected")
                .font(.caption)
                .foregroundStyle(.secondary)
            if !workspace.stagingRecoveryTargetChapters.isEmpty {
                Picker("Move to", selection: $selectedChapterID) {
                    ForEach(workspace.stagingRecoveryTargetChapters, id: \.id) { chapter in
                        Text(chapter.title).tag(Optional(chapter.id))
                    }
                }
                .pickerStyle(.menu)
                Button("Move Selected") {
                    guard let selectedChapterID else { return }
                    onNotice(workspace.batchMoveSelectedScenes(toChapter: selectedChapterID))
                }
                .disabled(!workspace.canBatchMoveSelectedScenesToChapter || selectedChapterID == nil)
            }
            Button("Send Selected to Staging") {
                onNotice(workspace.batchSendSelectedScenesToStaging())
            }
            .disabled(!workspace.canBatchStageSelectedScenes)
            Button("Help") {
                NotificationCenter.default.post(name: .showHelpReference, object: "modular-batch-actions")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
        .onAppear {
            selectedChapterID = workspace.stagingRecoveryTargetChapters.first?.id
        }
    }
}

private struct TimelineSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var eventTitle = ""
    @State private var eventDescription = ""
    @State private var eventTrack = "Main Plot"
    @State private var usesAbsoluteDate = false
    @State private var absoluteDate = Date()
    @State private var relativeOrder = 1
    @State private var colorHex = ""
    @State private var selectedSceneIDs: Set<UUID> = []
    @State private var editingEventID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Timeline",
                subtitle: "Track story events, ordering, and scene links in one chronology view.",
                dismissLabel: "Done",
                helpTopicID: "timeline-events",
                onDismiss: { dismiss() }
            )

            GroupBox(editingEventID == nil ? "New Event" : "Edit Event") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        InlineHelpTopics(topicIDs: ["timeline-events", "timeline-tracks"])
                        TextField("Title", text: $eventTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Track", text: $eventTrack)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $eventDescription)
                            .frame(height: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        Toggle("Use Absolute Date", isOn: $usesAbsoluteDate)
                        if usesAbsoluteDate {
                            DatePicker("Date", selection: $absoluteDate, displayedComponents: .date)
                        } else {
                            Stepper("Relative Order \(relativeOrder)", value: $relativeOrder, in: 1...500)
                        }
                        TextField("Color (hex)", text: $colorHex)
                            .textFieldStyle(.roundedBorder)
                        Text("Linked Scenes")
                            .font(.caption.weight(.medium))
                        ForEach(workspace.searchableChapters, id: \.id) { chapter in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                ForEach(chapter.scenes.compactMap(sceneForID), id: \.id) { scene in
                                    Toggle(
                                        scene.title,
                                        isOn: Binding(
                                            get: { selectedSceneIDs.contains(scene.id) },
                                            set: { isOn in
                                                if isOn {
                                                    selectedSceneIDs.insert(scene.id)
                                                } else {
                                                    selectedSceneIDs.remove(scene.id)
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        Button(editingEventID == nil ? "Add Event" : "Save Event") {
                            let position: TimelinePosition = usesAbsoluteDate ? .absolute(absoluteDate) : .relative(order: relativeOrder)
                            if let editingEventID {
                                onNotice(
                                    workspace.updateTimelineEvent(
                                        editingEventID,
                                        title: eventTitle,
                                        description: eventDescription,
                                        track: eventTrack,
                                        position: position,
                                        linkedSceneIDs: Array(selectedSceneIDs),
                                        color: colorHex
                                    )
                                )
                            } else {
                                onNotice(
                                    workspace.addTimelineEvent(
                                        title: eventTitle,
                                        description: eventDescription,
                                        track: eventTrack,
                                        position: position,
                                        linkedSceneIDs: Array(selectedSceneIDs),
                                        color: colorHex
                                    )
                                )
                            }
                            resetDrafts()
                        }
                        .disabled(eventTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || eventTrack.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxHeight: 300)
            }

            GroupBox("Events") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["timeline-events", "scene-actions"])
                    if workspace.timelineEvents.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ContentUnavailableView(
                                "No Timeline Events Yet",
                                systemImage: "timeline.selection",
                                description: Text("Add events here to map plot beats, chronology, and scene-linked story tracks.")
                            )
                            Button("Help") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "timeline-events")
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(workspace.timelineEvents, id: \.id) { event in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(event.title)
                                                Text("\(event.track) • \(positionLabel(event.position))")
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button("Edit") {
                                                loadEvent(event)
                                            }
                                            .buttonStyle(.borderless)
                                            Button("Delete") {
                                                onNotice(workspace.deleteTimelineEvent(event.id))
                                                if editingEventID == event.id {
                                                    resetDrafts()
                                                }
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        if !event.description.isEmpty {
                                            Text(event.description)
                                                .font(.caption)
                                        }
                                        if !event.linkedSceneIds.isEmpty {
                                            Text(event.linkedSceneIds.map(workspace.sceneTitleForDisplay).joined(separator: " • "))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(12)
                                    .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(palette.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 540)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
    }

    private func sceneForID(_ sceneID: UUID) -> ManifestScene? {
        workspace.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })
    }

    private func positionLabel(_ position: TimelinePosition) -> String {
        switch position {
        case let .absolute(date):
            return date.formatted(date: .abbreviated, time: .omitted)
        case let .relative(order):
            return "Order \(order)"
        }
    }

    private func resetDrafts() {
        editingEventID = nil
        eventTitle = ""
        eventDescription = ""
        eventTrack = "Main Plot"
        usesAbsoluteDate = false
        absoluteDate = Date()
        relativeOrder = 1
        colorHex = ""
        selectedSceneIDs = []
    }

    private func loadEvent(_ event: TimelineEvent) {
        editingEventID = event.id
        eventTitle = event.title
        eventDescription = event.description
        eventTrack = event.track
        switch event.position {
        case let .absolute(date):
            usesAbsoluteDate = true
            absoluteDate = date
            relativeOrder = 1
        case let .relative(order):
            usesAbsoluteDate = false
            relativeOrder = order
        }
        colorHex = event.color ?? ""
        selectedSceneIDs = Set(event.linkedSceneIds)
    }
}

private struct SourceLibrarySheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onImportResearch: (UUID) -> Void
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var sourceTitle = ""
    @State private var sourceAuthor = ""
    @State private var sourceDate = ""
    @State private var sourceURL = ""
    @State private var sourcePublication = ""
    @State private var sourceVolume = ""
    @State private var sourcePages = ""
    @State private var sourceDOI = ""
    @State private var sourceNotes = ""
    @State private var citationKey = ""
    @State private var selectedSceneIDs: Set<UUID> = []
    @State private var selectedEntityIDs: Set<UUID> = []
    @State private var selectedNoteIDs: Set<UUID> = []
    @State private var libraryFilter = ""
    @State private var editingSourceID: UUID?
    @State private var selectedSourceID: UUID?
    @State private var selectedAttachmentID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Sources",
                subtitle: "Research references, imported files, citations, and cross-links.",
                dismissLabel: "Done",
                helpTopicID: "sources",
                onDismiss: { dismiss() }
            )

            WorkspaceMetricStrip(items: [
                ("Sources", "\(workspace.sources.count)"),
                ("Shown", "\(filteredSources.count)"),
                ("Research Files", "\(workspace.sources.reduce(0) { $0 + $1.attachments.count })"),
                ("Selected", selectedSource?.title ?? "None")
            ])

            TextField("Filter sources", text: $libraryFilter)
                .textFieldStyle(.roundedBorder)
                .accessibilityLabel("Filter sources")
                .accessibilityHint("Filter the source library by title, citation key, author, or notes")

            sourceEditorSection
            librarySection
            researchBrowserSection
        }
        .padding(20)
        .frame(minWidth: 720, minHeight: 620)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
        .onAppear {
            if selectedSourceID == nil {
                selectedSourceID = workspace.sources.first?.id
            }
            if selectedAttachmentID == nil {
                selectedAttachmentID = workspace.sources.first?.attachments.first?.id
            }
        }
        .onChange(of: filteredSources.map(\.id)) { _, ids in
            if let selectedSourceID, ids.contains(selectedSourceID) {
                return
            }
            self.selectedSourceID = ids.first
        }
        .onChange(of: selectedSourceID) { _, _ in
            selectedAttachmentID = selectedSource?.attachments.first?.id
        }
        .onChange(of: selectedSource?.attachments.map(\.id) ?? []) { _, ids in
            if let selectedAttachmentID, ids.contains(selectedAttachmentID) {
                return
            }
            self.selectedAttachmentID = ids.first
        }
    }

    private var selectedSource: Source? {
        guard let selectedSourceID else { return nil }
        return workspace.sources.first(where: { $0.id == selectedSourceID })
    }

    private var sourceEditorSection: some View {
        GroupBox(editingSourceID == nil ? "New Source" : "Edit Source") {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["sources", "citation-insertion", "source-links"])
                    TextField("Title", text: $sourceTitle)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Source title")
                    HStack {
                        TextField("Author", text: $sourceAuthor)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source author")
                        TextField("Date", text: $sourceDate)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source date")
                    }
                    HStack {
                        TextField("Publication", text: $sourcePublication)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source publication")
                        TextField("Volume", text: $sourceVolume)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source volume")
                        TextField("Pages", text: $sourcePages)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source pages")
                    }
                    HStack {
                        TextField("DOI", text: $sourceDOI)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source DOI")
                        TextField("URL", text: $sourceURL)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("Source URL")
                    }
                    TextField("Citation key", text: $citationKey)
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Source citation key")
                    TextEditor(text: $sourceNotes)
                        .frame(height: 90)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        .accessibilityLabel("Source notes")
                    linkedSelectionSection
                    Button(editingSourceID == nil ? "Add Source" : "Save Source") {
                        if let editingSourceID {
                            onNotice(
                                workspace.updateSource(
                                    editingSourceID,
                                    title: sourceTitle,
                                    author: sourceAuthor,
                                    date: sourceDate,
                                    url: sourceURL,
                                    publication: sourcePublication,
                                    volume: sourceVolume,
                                    pages: sourcePages,
                                    doi: sourceDOI,
                                    notes: sourceNotes,
                                    citationKey: citationKey,
                                    linkedSceneIDs: Array(selectedSceneIDs),
                                    linkedEntityIDs: Array(selectedEntityIDs),
                                    linkedNoteIDs: Array(selectedNoteIDs)
                                )
                            )
                        } else {
                            onNotice(
                                workspace.addSource(
                                    title: sourceTitle,
                                    author: sourceAuthor,
                                    date: sourceDate,
                                    url: sourceURL,
                                    publication: sourcePublication,
                                    volume: sourceVolume,
                                    pages: sourcePages,
                                    doi: sourceDOI,
                                    notes: sourceNotes,
                                    citationKey: citationKey,
                                    linkedSceneIDs: Array(selectedSceneIDs),
                                    linkedEntityIDs: Array(selectedEntityIDs),
                                    linkedNoteIDs: Array(selectedNoteIDs)
                                )
                            )
                        }
                        resetDrafts()
                    }
                    .disabled(sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel(editingSourceID == nil ? "Add source" : "Save source")
                }
            }
            .frame(maxHeight: 300)
        }
    }

    private var librarySection: some View {
        GroupBox("Library") {
            VStack(alignment: .leading, spacing: 10) {
                InlineHelpTopics(topicIDs: ["sources", "source-links", "citation-insertion"])
                if filteredSources.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No sources yet. Add a reference, URL, or research file to start your library." : "No sources match the current filter. Clear or change the filter to see more references.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Button("Help") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "sources")
                            }
                            .buttonStyle(.borderless)
                        }
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(filteredSources, id: \.id) { source in
                                sourceRow(source)
                            }
                        }
                    }
                }
            }
        }
    }

    private var researchBrowserSection: some View {
        GroupBox("Research Browser") {
            VStack(alignment: .leading, spacing: 10) {
                InlineHelpTopics(topicIDs: ["research-browser", "source-attachments"])
                if let selectedSource {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(selectedSource.title)
                                .font(.headline)
                            Text(sourceSummary(selectedSource))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(researchAttachmentSummary(for: selectedSource))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            if let url = selectedSource.url, !url.isEmpty {
                                Text(url)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            researchAttachmentBrowser(for: selectedSource)
                            linkedScenesSection(for: selectedSource)
                            citationMentionsSection(for: selectedSource)
                            linkedEntitiesSection(for: selectedSource)
                            linkedNotesSection(for: selectedSource)
                        }
                    }
                } else {
                    Text("Select a source to browse research files, linked scenes, citations, entities, and notes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var filteredSources: [Source] {
        let query = libraryFilter.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return workspace.sources }
        return workspace.sources.filter { source in
            let haystack = [
                source.title,
                source.citationKey,
                source.author ?? "",
                source.notes
            ]
            .joined(separator: " ")
            .localizedLowercase
            return haystack.contains(query.localizedLowercase)
        }
    }

    private var linkedSelectionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.caption.weight(.medium))
            if !workspace.searchableChapters.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Scenes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(workspace.searchableChapters, id: \.id) { chapter in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(chapter.scenes.compactMap(sceneForID), id: \.id) { scene in
                                Toggle(scene.title, isOn: binding(for: scene.id, in: $selectedSceneIDs))
                                    .toggleStyle(.checkbox)
                            }
                        }
                    }
                }
            }
            if !workspace.entities.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Entities")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(workspace.entities, id: \.id) { entity in
                        Toggle(entity.name, isOn: binding(for: entity.id, in: $selectedEntityIDs))
                            .toggleStyle(.checkbox)
                    }
                }
            }
            if !workspace.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    ForEach(workspace.notes, id: \.id) { note in
                        Toggle(note.title, isOn: binding(for: note.id, in: $selectedNoteIDs))
                            .toggleStyle(.checkbox)
                    }
                }
            }
        }
    }

    private func sourceSummary(_ source: Source) -> String {
        [
            source.author,
            source.publication,
            source.date,
            source.doi.map { "DOI \($0)" }
        ]
        .compactMap { $0 }
        .filter { !$0.isEmpty }
        .joined(separator: " • ")
    }

    private func researchAttachmentSummary(for source: Source) -> String {
        let attachmentCount = source.attachments.count
        let linkedCount = source.linkedSceneIds.count + source.linkedEntityIds.count + source.linkedNoteIds.count
        return "\(attachmentCount) research file(s) • \(linkedCount) linked reference(s)"
    }

    @ViewBuilder
    private func sourceRow(_ source: Source) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(source.title)
                    Text("@\(source.citationKey)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedSourceID == source.id {
                    Text("Selected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("Insert Citation") {
                    onNotice(workspace.insertCitation(source.id))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Insert citation for \(source.title)")
                Button("Jump to Mention") {
                    onNotice(workspace.openFirstCitationMention(for: source.id))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Jump to first citation mention for \(source.title)")
                Button("Import Research") {
                    onImportResearch(source.id)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Import research file for \(source.title)")
                Button("Edit") {
                    loadSource(source)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Edit source \(source.title)")
                Button("Delete") {
                    onNotice(workspace.deleteSource(source.id))
                    if editingSourceID == source.id {
                        resetDrafts()
                    }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Delete source \(source.title)")
            }
            Text(sourceSummary(source))
                .font(.caption)
                .foregroundStyle(.secondary)
            if !source.attachments.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Research")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    ForEach(source.attachments, id: \.id) { attachment in
                        HStack {
                            Text(attachment.filename)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Text(attachment.mimeType)
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Button("Reveal") {
                                onNotice(workspace.revealResearchAttachment(attachment.id, from: source.id))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Reveal research file \(attachment.filename)")
                            Button("Remove") {
                                onNotice(workspace.removeResearchAttachment(attachment.id, from: source.id))
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Remove research file \(attachment.filename)")
                        }
                    }
                }
            }
            let citationScenes = workspace.sourceSceneMentions(source.id)
            if !citationScenes.isEmpty {
                Text("Mentions: \(citationScenes.map(\.title).joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !source.linkedSceneIds.isEmpty {
                Text("Linked scenes: \(source.linkedSceneIds.map(workspace.sceneTitleForDisplay).joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let linkedEntities = workspace.sourceLinkedEntities(source.id)
            if !linkedEntities.isEmpty {
                Text("Linked entities: \(linkedEntities.map(\.name).joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            let linkedNotes = workspace.sourceLinkedNotes(source.id)
            if !linkedNotes.isEmpty {
                Text("Linked notes: \(linkedNotes.map(\.title).joined(separator: " • "))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            if !source.notes.isEmpty {
                Text(source.notes)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            selectedSourceID = source.id
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selectedSourceID == source.id ? palette.tint.opacity(0.12) : palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedSourceID == source.id ? palette.tint.opacity(0.55) : palette.border, lineWidth: 1)
        )
    }

    private func researchAttachmentBrowser(for source: Source) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Imported Files")
                .font(.caption.weight(.medium))
            if source.attachments.isEmpty {
                Text("No research files imported yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(source.attachments, id: \.id) { attachment in
                    attachmentRow(attachment, sourceID: source.id)
                }
            }
        }
    }

    @ViewBuilder
    private func attachmentRow(_ attachment: ResearchAttachment, sourceID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.filename)
                        .font(.caption)
                    Text(attachment.mimeType)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if selectedAttachmentID == attachment.id {
                    Text("Selected")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Button("Open") {
                    onNotice(workspace.openResearchAttachment(attachment.id, from: sourceID))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Open research file \(attachment.filename)")
                Button("Reveal") {
                    onNotice(workspace.revealResearchAttachment(attachment.id, from: sourceID))
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Reveal research file \(attachment.filename)")
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedAttachmentID = attachment.id
            }
            if selectedAttachmentID == attachment.id {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Imported \(attachment.importedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    if let fileURL = workspace.researchAttachmentURL(sourceID: sourceID, attachmentID: attachment.id) {
                        Text(fileURL.lastPathComponent)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    } else {
                        Text("This file is missing from the research folder.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(selectedAttachmentID == attachment.id ? palette.tint.opacity(0.12) : palette.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selectedAttachmentID == attachment.id ? palette.tint.opacity(0.55) : palette.border, lineWidth: 1)
        )
    }

    private func linkedScenesSection(for source: Source) -> some View {
        let linkedScenes = workspace.sourceLinkedScenes(source.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Linked Scenes")
                .font(.caption.weight(.medium))
            if linkedScenes.isEmpty {
                Text("No linked scenes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(linkedScenes, id: \.id) { scene in
                    Button(scene.title) {
                        workspace.navigateToScene(scene.id)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func citationMentionsSection(for source: Source) -> some View {
        let mentionScenes = workspace.sourceSceneMentions(source.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Citation Mentions")
                .font(.caption.weight(.medium))
            if mentionScenes.isEmpty {
                Text("No citation mentions in manuscript scenes yet.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(mentionScenes, id: \.id) { scene in
                    Button(scene.title) {
                        workspace.navigateToScene(scene.id)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func linkedEntitiesSection(for source: Source) -> some View {
        let linkedEntities = workspace.sourceLinkedEntities(source.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Linked Entities")
                .font(.caption.weight(.medium))
            if linkedEntities.isEmpty {
                Text("No linked entities.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(linkedEntities, id: \.id) { entity in
                    Button(entity.name) {
                        NotificationCenter.default.post(name: .showEntitiesSheet, object: nil)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func linkedNotesSection(for source: Source) -> some View {
        let linkedNotes = workspace.sourceLinkedNotes(source.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Linked Notes")
                .font(.caption.weight(.medium))
            if linkedNotes.isEmpty {
                Text("No linked notes.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(linkedNotes, id: \.id) { note in
                    Button(note.title) {
                        workspace.focusNotes(onScene: note.linkedSceneIds.first)
                        NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                    }
                    .buttonStyle(.link)
                }
            }
        }
    }

    private func binding(for id: UUID, in set: Binding<Set<UUID>>) -> Binding<Bool> {
        Binding(
            get: { set.wrappedValue.contains(id) },
            set: { isOn in
                if isOn {
                    set.wrappedValue.insert(id)
                } else {
                    set.wrappedValue.remove(id)
                }
            }
        )
    }

    private func sceneForID(_ sceneID: UUID) -> ManifestScene? {
        workspace.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })
    }

    private func resetDrafts() {
        editingSourceID = nil
        sourceTitle = ""
        sourceAuthor = ""
        sourceDate = ""
        sourceURL = ""
        sourcePublication = ""
        sourceVolume = ""
        sourcePages = ""
        sourceDOI = ""
        sourceNotes = ""
        citationKey = ""
        selectedSceneIDs = []
        selectedEntityIDs = []
        selectedNoteIDs = []
    }

    private func loadSource(_ source: Source) {
        editingSourceID = source.id
        sourceTitle = source.title
        sourceAuthor = source.author ?? ""
        sourceDate = source.date ?? ""
        sourceURL = source.url ?? ""
        sourcePublication = source.publication ?? ""
        sourceVolume = source.volume ?? ""
        sourcePages = source.pages ?? ""
        sourceDOI = source.doi ?? ""
        sourceNotes = source.notes
        citationKey = source.citationKey
        selectedSceneIDs = Set(source.linkedSceneIds)
        selectedEntityIDs = Set(source.linkedEntityIds)
        selectedNoteIDs = Set(source.linkedNoteIds)
    }
}

private struct ScratchpadSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var itemTitle = ""
    @State private var itemContent = ""
    @State private var itemKind: ScratchpadItemKind = .scratch
    @State private var editingItemID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Scratchpad",
                subtitle: "Save loose text, reusable snippets, and captured selections for quick reuse.",
                dismissLabel: "Done",
                helpTopicID: "scratchpad",
                trailingContent: {
                    AnyView(
                        Button("Capture Selection") {
                            onNotice(workspace.captureSelectionToScratchpad(title: itemTitle, as: itemKind))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .accessibilityLabel("Capture selected text to scratchpad")
                    )
                },
                onDismiss: { dismiss() }
            )

            GroupBox(editingItemID == nil ? "New Item" : "Edit Item") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["scratchpad", "scratchpad-capture"])
                    TextField("Title", text: $itemTitle)
                        .textFieldStyle(.roundedBorder)
                    Picker("Kind", selection: $itemKind) {
                        ForEach(ScratchpadItemKind.allCases, id: \.self) { kind in
                            Text(kind.rawValue.capitalized).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    TextEditor(text: $itemContent)
                        .frame(height: 120)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                    HStack {
                        Button(editingItemID == nil ? "Add Item" : "Save Item") {
                            if let editingItemID {
                                onNotice(workspace.updateScratchpadItem(editingItemID, title: itemTitle, content: itemContent, kind: itemKind))
                            } else {
                                onNotice(workspace.addScratchpadItem(title: itemTitle, content: itemContent, kind: itemKind))
                            }
                            resetDraft()
                        }
                        .disabled(itemContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel(editingItemID == nil ? "Add scratchpad item" : "Save scratchpad item")
                        Button("Clear") {
                            resetDraft()
                        }
                    }
                }
            }

            GroupBox("Items") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["scratchpad", "scratchpad-capture"])
                    if workspace.scratchpadItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ContentUnavailableView(
                                "No Scratchpad Items Yet",
                                systemImage: "square.and.pencil.on.square",
                                description: Text("Capture a selection or add a reusable snippet here for fast reinsertion while drafting.")
                            )
                            Button("Help") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "scratchpad")
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(workspace.scratchpadItems, id: \.id) { item in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(item.title)
                                                Text(item.kind.rawValue.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button("Insert") {
                                                onNotice(workspace.insertScratchpadItem(item.id))
                                            }
                                            .buttonStyle(.borderless)
                                            .accessibilityLabel("Insert scratchpad item \(item.title)")
                                            Button("Edit") {
                                                itemTitle = item.title
                                                itemContent = item.content
                                                itemKind = item.kind
                                                editingItemID = item.id
                                            }
                                            .buttonStyle(.borderless)
                                            .accessibilityLabel("Edit scratchpad item \(item.title)")
                                            Button("Delete") {
                                                onNotice(workspace.deleteScratchpadItem(item.id))
                                                if editingItemID == item.id {
                                                    resetDraft()
                                                }
                                            }
                                            .buttonStyle(.borderless)
                                            .accessibilityLabel("Delete scratchpad item \(item.title)")
                                        }
                                        Text(item.content)
                                            .font(.caption)
                                            .lineLimit(4)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(12)
                                    .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(palette.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 500)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
    }

    private func resetDraft() {
        itemTitle = ""
        itemContent = ""
        itemKind = .scratch
        editingItemID = nil
    }
}

private struct EntityTrackerSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var entityName = ""
    @State private var entityType: EntityType = .character
    @State private var aliasDraft = ""
    @State private var fieldKeyDraft = ""
    @State private var fieldValueDraft = ""
    @State private var entityAliases: [String] = []
    @State private var entityFields: [String: String] = [:]
    @State private var entityNotes = ""
    @State private var linkSelectedScene = true
    @State private var editingEntityID: UUID?
    @State private var relationshipTargetID: UUID?
    @State private var relationshipLabel = ""
    @State private var relationshipBidirectional = true

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Entities",
                subtitle: "Track characters, places, objects, aliases, and linked scene context.",
                dismissLabel: "Done",
                helpTopicID: "entities",
                onDismiss: { dismiss() }
            )

            WorkspaceMetricStrip(items: [
                ("Tracked", "\(workspace.entities.count)"),
                ("Scene Linked", "\(workspace.entities.filter { !$0.sceneMentions.isEmpty }.count)"),
                ("Editing", editingEntityID == nil ? "New" : "Existing")
            ])

            GroupBox("New Entity") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["entities", "entity-relationships"])
                    TextField("Name", text: $entityName)
                        .textFieldStyle(.roundedBorder)
                    Picker("Type", selection: $entityType) {
                        ForEach(EntityType.allCases, id: \.self) { type in
                            Text(type.rawValue.capitalized).tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        TextField("Alias", text: $aliasDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Add Alias") {
                            let alias = aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !alias.isEmpty else { return }
                            entityAliases.append(alias)
                            aliasDraft = ""
                        }
                        .disabled(aliasDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !entityAliases.isEmpty {
                        FlowAliasesView(values: entityAliases) { alias in
                            entityAliases.removeAll { $0 == alias }
                        }
                    }
                    HStack {
                        TextField("Field", text: $fieldKeyDraft)
                            .textFieldStyle(.roundedBorder)
                        TextField("Value", text: $fieldValueDraft)
                            .textFieldStyle(.roundedBorder)
                        Button("Add Field") {
                            let key = fieldKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            let value = fieldValueDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !key.isEmpty, !value.isEmpty else { return }
                            entityFields[key] = value
                            fieldKeyDraft = ""
                            fieldValueDraft = ""
                        }
                        .disabled(fieldKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || fieldValueDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    if !entityFields.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(entityFields.keys.sorted(), id: \.self) { key in
                                HStack {
                                    Text("\(key): \(entityFields[key] ?? "")")
                                        .font(.caption)
                                    Spacer()
                                    Button("Remove") {
                                        entityFields.removeValue(forKey: key)
                                    }
                                    .buttonStyle(.borderless)
                                }
                            }
                        }
                    }
                    TextEditor(text: $entityNotes)
                        .frame(height: 80)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                    Toggle("Link selected scene", isOn: $linkSelectedScene)
                    if let editingEntityID {
                        Divider()
                        Text("Relationships")
                            .font(.caption.weight(.medium))
                        HStack {
                            Picker("Target", selection: $relationshipTargetID) {
                                Text("Select Entity").tag(Optional<UUID>.none)
                                ForEach(workspace.entities.filter { $0.id != editingEntityID }, id: \.id) { entity in
                                    Text(entity.name).tag(Optional(entity.id))
                                }
                            }
                            .pickerStyle(.menu)
                            TextField("Relationship", text: $relationshipLabel)
                                .textFieldStyle(.roundedBorder)
                        }
                        Toggle("Bidirectional", isOn: $relationshipBidirectional)
                        Button("Add Relationship") {
                            guard let relationshipTargetID else { return }
                            onNotice(
                                workspace.addEntityRelationship(
                                    from: editingEntityID,
                                    to: relationshipTargetID,
                                    label: relationshipLabel,
                                    bidirectional: relationshipBidirectional
                                )
                            )
                            relationshipLabel = ""
                            self.relationshipTargetID = nil
                        }
                        .disabled(relationshipTargetID == nil || relationshipLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Button(editingEntityID == nil ? "Add Entity" : "Save Entity") {
                        if let editingEntityID {
                            onNotice(
                                workspace.updateEntity(
                                    editingEntityID,
                                    name: entityName,
                                    type: entityType,
                                    aliases: entityAliases,
                                    fields: entityFields,
                                    notes: entityNotes
                                )
                            )
                        } else {
                            onNotice(
                                workspace.addEntity(
                                    name: entityName,
                                    type: entityType,
                                    aliases: entityAliases,
                                    fields: entityFields,
                                    notes: entityNotes,
                                    linkSelectedScene: linkSelectedScene
                                )
                            )
                        }
                        resetDrafts()
                    }
                    .disabled(entityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            GroupBox("Tracked") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["entities", "entity-relationships"])
                    if workspace.entities.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ContentUnavailableView(
                                "No Entities Yet",
                                systemImage: "person.2.crop.square.stack",
                                description: Text("Track characters, places, objects, and aliases here so scene context and mention scanning have something to build on.")
                            )
                            Button("Help") {
                                NotificationCenter.default.post(name: .showHelpReference, object: "entities")
                            }
                            .buttonStyle(.borderless)
                        }
                    } else {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 10) {
                                ForEach(workspace.entities, id: \.id) { entity in
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack(alignment: .top) {
                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(entity.name)
                                                Text(entity.entityType.rawValue.capitalized)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                                Text("\(entity.sceneMentions.count) linked scene(s)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                                Text("\(workspace.notesLinkedToEntity(entity.id).count) note(s)")
                                                    .font(.caption2)
                                                    .foregroundStyle(.secondary)
                                            }
                                            Spacer()
                                            Button("Link Current Scene") {
                                                onNotice(workspace.linkSelectedSceneToEntity(entity.id))
                                            }
                                            .buttonStyle(.borderless)
                                            Button("Scan Mentions") {
                                                onNotice(workspace.scanEntityMentions(entity.id))
                                            }
                                            .buttonStyle(.borderless)
                                            Button("Notes") {
                                                workspace.focusNotes(onEntity: entity.id)
                                                NotificationCenter.default.post(name: .showNotesSheet, object: nil)
                                            }
                                            .buttonStyle(.borderless)
                                            Button("Edit") {
                                                loadEntity(entity)
                                            }
                                            .buttonStyle(.borderless)
                                            Button("Delete") {
                                                onNotice(workspace.deleteEntity(entity.id))
                                            }
                                            .buttonStyle(.borderless)
                                        }
                                        if !entity.aliases.isEmpty {
                                            Text("Aliases: \(entity.aliases.joined(separator: ", "))")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !entity.fields.isEmpty {
                                            Text(entity.fields.keys.sorted().map { "\($0): \(entity.fields[$0] ?? "")" }.joined(separator: " • "))
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                        }
                                        let relationships = workspace.entityRelationships(entity.id)
                                        if !relationships.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Relationships")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                ForEach(relationships, id: \.target.id) { item in
                                                    HStack {
                                                        Text(workspace.relationshipDescription(source: entity, relationship: item.relationship, target: item.target))
                                                            .font(.caption2)
                                                        Spacer()
                                                        Button("Remove") {
                                                            onNotice(workspace.removeEntityRelationship(from: entity.id, to: item.target.id, label: item.relationship.label))
                                                        }
                                                        .buttonStyle(.borderless)
                                                    }
                                                }
                                            }
                                        }
                                        let linkedScenes = workspace.entityLinkedScenes(entity.id)
                                        if !linkedScenes.isEmpty {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("Linked Scenes")
                                                    .font(.caption2.weight(.semibold))
                                                    .foregroundStyle(.secondary)
                                                ForEach(linkedScenes, id: \.id) { scene in
                                                    HStack {
                                                        Text(scene.title)
                                                            .font(.caption2)
                                                        Spacer()
                                                        Button("Open") {
                                                            workspace.navigateToScene(scene.id)
                                                        }
                                                        .buttonStyle(.borderless)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    .padding(12)
                                    .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(palette.border, lineWidth: 1)
                                    )
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
        }
        .padding(20)
        .frame(minWidth: 520, minHeight: 420)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
    }

    private func resetDrafts() {
        editingEntityID = nil
        entityName = ""
        entityType = .character
        aliasDraft = ""
        fieldKeyDraft = ""
        fieldValueDraft = ""
        entityAliases = []
        entityFields = [:]
        entityNotes = ""
        linkSelectedScene = true
        relationshipTargetID = nil
        relationshipLabel = ""
        relationshipBidirectional = true
    }

    private func loadEntity(_ entity: Entity) {
        editingEntityID = entity.id
        entityName = entity.name
        entityType = entity.entityType
        entityAliases = entity.aliases
        entityFields = entity.fields
        entityNotes = entity.notes
        linkSelectedScene = false
        relationshipTargetID = nil
        relationshipLabel = ""
        relationshipBidirectional = true
    }
}

private struct NotesSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    @State private var noteTitle = ""
    @State private var noteFolder = ""
    @State private var noteContent = ""
    @State private var selectedSceneIDs: Set<UUID> = []
    @State private var selectedEntityIDs: Set<UUID> = []
    @State private var editingNoteID: UUID?
    @State private var folderFilter = ""
    @State private var filteredSceneID: UUID?
    @State private var filteredEntityID: UUID?

    private var filteredNotes: [Note] {
        workspace.notes.filter { note in
            let folderMatches = folderFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
                (note.folder?.localizedCaseInsensitiveContains(folderFilter.trimmingCharacters(in: .whitespacesAndNewlines)) == true)
            let sceneMatches = filteredSceneID == nil || note.linkedSceneIds.contains(filteredSceneID!)
            let entityMatches = filteredEntityID == nil || note.linkedEntityIds.contains(filteredEntityID!)
            return folderMatches && sceneMatches && entityMatches
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            WorkspaceSheetHeader(
                title: "Notes",
                subtitle: "Linked working notes for scenes, entities, and folders.",
                dismissLabel: "Done",
                helpTopicID: "notes",
                onDismiss: { dismiss() }
            )

            WorkspaceMetricStrip(items: [
                ("Notes", "\(workspace.notes.count)"),
                ("Shown", "\(filteredNotes.count)"),
                ("Scene Filter", filteredSceneID.map(workspace.sceneTitleForDisplay) ?? "All"),
                ("Entity Filter", filteredEntityID.map(workspace.entityNameForDisplay) ?? "All")
            ])

            GroupBox(editingNoteID == nil ? "New Note" : "Edit Note") {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        InlineHelpTopics(topicIDs: ["notes", "note-linking"])
                        TextField("Title", text: $noteTitle)
                            .textFieldStyle(.roundedBorder)
                        TextField("Folder", text: $noteFolder)
                            .textFieldStyle(.roundedBorder)
                        TextEditor(text: $noteContent)
                            .frame(height: 120)
                            .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.secondary.opacity(0.2)))
                        Text("Linked Scenes")
                            .font(.caption.weight(.medium))
                        ForEach(workspace.searchableChapters, id: \.id) { chapter in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(chapter.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                let scenes = chapter.scenes.compactMap { sceneID in
                                    workspace.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })
                                }
                                ForEach(scenes, id: \.id) { scene in
                                    Toggle(
                                        scene.title,
                                        isOn: Binding(
                                            get: { selectedSceneIDs.contains(scene.id) },
                                            set: { isOn in
                                                if isOn {
                                                    selectedSceneIDs.insert(scene.id)
                                                } else {
                                                    selectedSceneIDs.remove(scene.id)
                                                }
                                            }
                                        )
                                    )
                                    .toggleStyle(.checkbox)
                                }
                            }
                        }
                        Text("Linked Entities")
                            .font(.caption.weight(.medium))
                        ForEach(workspace.entities, id: \.id) { entity in
                            Toggle(
                                entity.name,
                                isOn: Binding(
                                    get: { selectedEntityIDs.contains(entity.id) },
                                    set: { isOn in
                                        if isOn {
                                            selectedEntityIDs.insert(entity.id)
                                        } else {
                                            selectedEntityIDs.remove(entity.id)
                                        }
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                        Button(editingNoteID == nil ? "Add Note" : "Save Note") {
                            if let editingNoteID {
                                onNotice(
                                    workspace.updateNote(
                                        editingNoteID,
                                        title: noteTitle,
                                        content: noteContent,
                                        folder: noteFolder,
                                        linkedSceneIDs: Array(selectedSceneIDs),
                                        linkedEntityIDs: Array(selectedEntityIDs)
                                    )
                                )
                            } else {
                                onNotice(
                                    workspace.addNote(
                                        title: noteTitle,
                                        content: noteContent,
                                        folder: noteFolder,
                                        linkedSceneIDs: Array(selectedSceneIDs),
                                        linkedEntityIDs: Array(selectedEntityIDs)
                                    )
                                )
                            }
                            resetDrafts()
                        }
                        .disabled(noteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .frame(maxHeight: 320)
            }

            GroupBox("Filters") {
                VStack(alignment: .leading, spacing: 10) {
                    InlineHelpTopics(topicIDs: ["notes-filters", "notes"])
                    TextField("Filter by folder", text: $folderFilter)
                        .textFieldStyle(.roundedBorder)
                    Picker("Scene", selection: $filteredSceneID) {
                        Text("All Scenes").tag(Optional<UUID>.none)
                        ForEach(workspace.searchableChapters, id: \.id) { chapter in
                            ForEach(chapter.scenes.compactMap({ sceneID in
                                workspace.projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneID })
                            }), id: \.id) { scene in
                                Text(scene.title).tag(Optional(scene.id))
                            }
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Entity", selection: $filteredEntityID) {
                        Text("All Entities").tag(Optional<UUID>.none)
                        ForEach(workspace.entities, id: \.id) { entity in
                            Text(entity.name).tag(Optional(entity.id))
                        }
                    }
                    .pickerStyle(.menu)
                    HStack {
                        Spacer()
                        Button("Clear Filters") {
                            folderFilter = ""
                            filteredSceneID = nil
                            filteredEntityID = nil
                            workspace.clearNotesFocus()
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            GroupBox("Saved Notes") {
                if filteredNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ContentUnavailableView(
                            "No Notes Yet",
                            systemImage: "note.text",
                            description: Text("Create a note to capture loose ideas, scene context, entity details, or research takeaways.")
                        )
                        Button("Help") {
                            NotificationCenter.default.post(name: .showHelpReference, object: "notes")
                        }
                        .buttonStyle(.borderless)
                    }
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(filteredNotes, id: \.id) { note in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(note.title)
                                            if let folder = note.folder, !folder.isEmpty {
                                                Text(folder)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer()
                                        Button("Edit") {
                                            loadNote(note)
                                        }
                                        .buttonStyle(.borderless)
                                        Button("Delete") {
                                            onNotice(workspace.deleteNote(note.id))
                                        }
                                        .buttonStyle(.borderless)
                                    }
                                    if !note.content.isEmpty {
                                        Text(note.content)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(3)
                                    }
                                    if !note.linkedSceneIds.isEmpty {
                                        HStack {
                                            Text("Scenes:")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            ForEach(note.linkedSceneIds, id: \.self) { sceneID in
                                                Button(workspace.sceneTitleForDisplay(sceneID)) {
                                                    workspace.navigateToScene(sceneID)
                                                }
                                                .buttonStyle(.borderless)
                                                .font(.caption2)
                                            }
                                        }
                                    }
                                    if !note.linkedEntityIds.isEmpty {
                                        HStack {
                                            Text("Entities:")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                            ForEach(note.linkedEntityIds, id: \.self) { entityID in
                                                Button(workspace.entityNameForDisplay(entityID)) {
                                                    workspace.focusNotes(onEntity: entityID)
                                                    filteredEntityID = entityID
                                                }
                                                .buttonStyle(.borderless)
                                                .font(.caption2)
                                            }
                                        }
                                    }
                                }
                                .padding(12)
                                .background(palette.card, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(palette.border, lineWidth: 1)
                                )
                            }
                        }
                    }
                    .frame(maxHeight: 220)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 520)
        .groupBoxStyle(WorkspacePanelGroupBoxStyle())
        .background(palette.canvas.opacity(0.96))
        .onAppear(perform: applyWorkspaceFocus)
        .onChange(of: workspace.notesFocusSceneID) { _, _ in
            applyWorkspaceFocus()
        }
        .onChange(of: workspace.notesFocusEntityID) { _, _ in
            applyWorkspaceFocus()
        }
    }

    private func resetDrafts() {
        editingNoteID = nil
        noteTitle = ""
        noteFolder = ""
        noteContent = ""
        selectedSceneIDs = []
        selectedEntityIDs = []
    }

    private func loadNote(_ note: Note) {
        editingNoteID = note.id
        noteTitle = note.title
        noteFolder = note.folder ?? ""
        noteContent = note.content
        selectedSceneIDs = Set(note.linkedSceneIds)
        selectedEntityIDs = Set(note.linkedEntityIds)
    }

    private func applyWorkspaceFocus() {
        if let sceneID = workspace.notesFocusSceneID {
            filteredSceneID = sceneID
        }
        if let entityID = workspace.notesFocusEntityID {
            filteredEntityID = entityID
        }
    }
}

private struct FlowAliasesView: View {
    let values: [String]
    let onRemove: (String) -> Void
    @Environment(\.appThemePalette) private var palette

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 90), spacing: 6)], spacing: 6) {
            ForEach(values, id: \.self) { value in
                HStack(spacing: 4) {
                    Text(value)
                        .lineLimit(1)
                    Button {
                        onRemove(value)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                    .buttonStyle(.plain)
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(palette.card)
                .overlay(
                    Capsule()
                        .stroke(palette.border, lineWidth: 1)
                )
                .clipShape(Capsule())
            }
        }
    }
}

private struct WorkspacePanelGroupBoxStyle: GroupBoxStyle {
    @Environment(\.appThemePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            configuration.label
                .font(.headline.weight(.semibold))
            configuration.content
        }
        .padding(16)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.softShadow, radius: 10, x: 0, y: 6)
    }
}

private struct InteractiveSurfaceButtonStyle: ButtonStyle {
    let isSelected: Bool
    let isHovered: Bool
    @Environment(\.appThemePalette) private var palette

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        palette.interactiveFill(
                            isSelected: isSelected,
                            isHovered: isHovered,
                            isPressed: configuration.isPressed
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        palette.interactiveBorder(
                            isSelected: isSelected,
                            isHovered: isHovered,
                            isPressed: configuration.isPressed
                        ),
                        lineWidth: isSelected ? 1.5 : 1
                    )
            )
            .shadow(
                color: isHovered ? palette.softShadow.opacity(1.25) : .clear,
                radius: 8,
                x: 0,
                y: 4
            )
            .scaleEffect(configuration.isPressed ? 0.992 : (isHovered ? 1.003 : 1.0))
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
            .animation(.easeOut(duration: 0.14), value: isHovered)
    }
}

private struct GroupedResultsSectionHeaderView: View {
    let title: String
    let matchCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    @Environment(\.appThemePalette) private var palette
    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(matchCount)")
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(palette.mutedBadge, in: Capsule())
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveSurfaceButtonStyle(isSelected: false, isHovered: isHovering))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct GroupedResultsSceneHeaderView: View {
    let title: String
    let matchCount: Int
    let isCollapsed: Bool
    let onToggle: () -> Void
    @State private var isHovering = false

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveSurfaceButtonStyle(isSelected: false, isHovered: isHovering))
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct GroupedResultsItemRowView: View {
    let resultIndex: Int
    let snippet: Text
    let isSelected: Bool
    let onSelect: () -> Void
    @Environment(\.appThemePalette) private var palette
    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            HStack(alignment: .top, spacing: 10) {
                Text("\(resultIndex + 1).")
                    .font(.caption.monospacedDigit().weight(.medium))
                    .foregroundStyle(isSelected ? palette.tint : .secondary)
                    .frame(width: 34, alignment: .leading)

                snippet
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .multilineTextAlignment(.leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(InteractiveSurfaceButtonStyle(isSelected: isSelected, isHovered: isHovering))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? palette.focusRing : .clear, lineWidth: 0.5)
        )
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct WorkspaceSheetHeader: View {
    let title: String
    let subtitle: String
    let dismissLabel: String
    let helpTopicID: String?
    let trailingContent: () -> AnyView
    let onDismiss: () -> Void
    @Environment(\.appThemePalette) private var palette

    init(
        title: String,
        subtitle: String,
        dismissLabel: String,
        helpTopicID: String?,
        trailingContent: @escaping () -> AnyView = { AnyView(EmptyView()) },
        onDismiss: @escaping () -> Void
    ) {
        self.title = title
        self.subtitle = subtitle
        self.dismissLabel = dismissLabel
        self.helpTopicID = helpTopicID
        self.trailingContent = trailingContent
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if let helpTopicID {
                Button("Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: helpTopicID)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            trailingContent()
            Button(dismissLabel, action: onDismiss)
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
        .shadow(color: palette.softShadow, radius: 10, x: 0, y: 6)
    }
}

private struct InlineHelpTopics: View {
    let topicIDs: [String]

    private var entries: [HelpReferenceEntry] {
        topicIDs.compactMap(HelpReferenceLibrary.entry(for:))
    }

    var body: some View {
        if !entries.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("Related Help:")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(entries) { entry in
                    Button(entry.title) {
                        NotificationCenter.default.post(name: .showHelpReference, object: entry.id)
                    }
                    .buttonStyle(.borderless)
                    .font(.caption2)
                }
            }
        }
    }
}

private struct WorkspaceMetricStrip: View {
    let items: [(String, String)]
    @Environment(\.appThemePalette) private var palette

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.0)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(item.1)
                            .font(.caption.weight(.medium))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(palette.card, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(palette.border, lineWidth: 1)
                    )
                    .shadow(color: palette.softShadow, radius: 6, x: 0, y: 3)
                }
            }
        }
    }
}

private struct GoalsDashboardSheet: View {
    @ObservedObject var goalsManager: GoalsManager
    @Environment(\.dismiss) private var dismiss
    @State private var projectGoalDraft = ""
    @State private var selectedDeadlineEnabled = false
    @State private var projectDeadlineDraft = Date()
    @State private var sessionGoalDraft = ""
    @State private var selectedHistoryRange = 90

    private var historyRecords: [DailyWritingRecord] {
        goalsManager.recordsForLastNDays(selectedHistoryRange)
    }

    private var average30DayWords: Int {
        Int(goalsManager.averageDailyWords(lastNDays: 30).rounded())
    }

    private var projectProgress: Double {
        guard let goal = goalsManager.projectGoalWordCount, goal > 0 else { return 0 }
        return min(max(Double(goalsManager.currentTotalWordCount) / Double(goal), 0), 1)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                sessionSection
                projectSection
                historySection
            }
            .padding(20)
        }
        .frame(minWidth: 760, minHeight: 620)
        .onAppear(perform: syncDrafts)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            WorkspaceSheetHeader(
                title: "Writing Goals & Statistics",
                subtitle: "Session progress, project pacing, and recent history.",
                dismissLabel: "Close",
                helpTopicID: "goals-dashboard",
                onDismiss: { dismiss() }
            )
            WorkspaceMetricStrip(items: [
                ("Current", formatCount(goalsManager.currentTotalWordCount)),
                ("Today", formatCount(goalsManager.todayWordsWritten())),
                ("Streak", "\(goalsManager.currentStreak)"),
                ("Projected", projectedCompletionText)
            ])
        }
    }

    private var sessionSection: some View {
        GroupBox("Session") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    goalsMetric("Net", goalsManager.sessionProgressText())
                    goalsMetric("Gross", "\(goalsManager.sessionGrossWords) words")
                    goalsMetric("Timer", formatDuration(goalsManager.sessionElapsedSeconds))
                    goalsMetric("Streak", "\(goalsManager.currentStreak) day\(goalsManager.currentStreak == 1 ? "" : "s")")
                }
                if let goal = goalsManager.sessionGoal, goal > 0 {
                    ProgressView(value: Double(goalsManager.sessionWordsWritten), total: Double(goal))
                    Text("\(goalsManager.sessionWordsWritten) / \(goal)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Session goal", text: $sessionGoalDraft)
                        .textFieldStyle(.roundedBorder)
                    Button("Set Goal") {
                        let value = Int(sessionGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                        goalsManager.sessionGoal = value
                    }
                    .disabled(Int(sessionGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                    Button(goalsManager.isTimerRunning ? "Pause Timer" : "Start Timer") {
                        if goalsManager.isTimerRunning {
                            goalsManager.pauseTimer()
                        } else {
                            if goalsManager.sessionStartTime == nil {
                                goalsManager.startSession(goal: goalsManager.sessionGoal)
                            }
                            goalsManager.startTimer()
                        }
                    }
                    Button("End Session") {
                        goalsManager.endSession()
                        syncDrafts()
                    }
                    .disabled(goalsManager.sessionStartTime == nil)
                }
                if let message = goalsManager.lastGoalNotificationMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.green)
                }
                if let warning = goalsManager.lastWarningMessage {
                    Text(warning)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var projectSection: some View {
        GroupBox("Project Goal") {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    goalsMetric("Current", formatCount(goalsManager.currentTotalWordCount))
                    goalsMetric("30-Day Avg", "\(average30DayWords) / day")
                    goalsMetric("Today", formatCount(goalsManager.todayWordsWritten()))
                    goalsMetric("Projected", projectedCompletionText)
                }
                if let goal = goalsManager.projectGoalWordCount, goal > 0 {
                    ProgressView(value: projectProgress)
                    Text("\(formatCount(goalsManager.currentTotalWordCount)) / \(formatCount(goal))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(projectDeadlineStatus(goal: goal))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No project goal set.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack {
                    TextField("Project goal", text: $projectGoalDraft)
                        .textFieldStyle(.roundedBorder)
                    Toggle("Deadline", isOn: $selectedDeadlineEnabled)
                    DatePicker("", selection: $projectDeadlineDraft, displayedComponents: .date)
                        .labelsHidden()
                        .disabled(!selectedDeadlineEnabled)
                    Button("Save Goal") {
                        let goal = Int(projectGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines))
                        goalsManager.setProjectGoal(wordCount: goal, deadline: selectedDeadlineEnabled ? projectDeadlineDraft : nil)
                        syncDrafts()
                    }
                    .disabled(Int(projectGoalDraft.trimmingCharacters(in: .whitespacesAndNewlines)) == nil)
                    Button("Clear") {
                        goalsManager.setProjectGoal(wordCount: nil, deadline: nil)
                        syncDrafts()
                    }
                }
            }
        }
    }

    private var historySection: some View {
        GroupBox("History") {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Range", selection: $selectedHistoryRange) {
                    Text("30 Days").tag(30)
                    Text("60 Days").tag(60)
                    Text("90 Days").tag(90)
                }
                .pickerStyle(.segmented)

                GoalsHeatmapView(records: historyRecords)
                    .frame(height: 110)

                GoalsLineChartView(records: historyRecords)
                    .frame(height: 180)

                HStack {
                    goalsMetric("Best Day", bestDayText)
                    goalsMetric("Sessions", "\(historyRecords.reduce(0) { $0 + $1.sessionsCount })")
                    goalsMetric("Gross Typed", formatCount(historyRecords.reduce(0) { $0 + $1.wordsGross }))
                }
            }
        }
    }

    private func goalsMetric(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var projectedCompletionText: String {
        guard let projected = goalsManager.projectedCompletionDate() else {
            return "No projection"
        }
        return projected.formatted(date: .abbreviated, time: .omitted)
    }

    private var bestDayText: String {
        guard let best = historyRecords.max(by: { $0.wordsWritten < $1.wordsWritten }) else {
            return "0"
        }
        return "\(formatCount(best.wordsWritten)) on \(best.date)"
    }

    private func projectDeadlineStatus(goal: Int) -> String {
        let remaining = max(0, goal - goalsManager.currentTotalWordCount)
        guard let deadline = goalsManager.projectGoalDeadline else {
            return "\(formatCount(remaining)) words remaining."
        }
        let calendar = Calendar.current
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: deadline)).day ?? 0
        if days < 0 {
            return "Deadline passed \(-days) day\((-days) == 1 ? "" : "s") ago. \(formatCount(remaining)) words remaining."
        }
        if days == 0 {
            return "Deadline is today. \(formatCount(remaining)) words remaining."
        }
        let pace = days > 0 ? Int(ceil(Double(remaining) / Double(days))) : remaining
        return "\(formatCount(remaining)) words remaining across \(days) day\(days == 1 ? "" : "s") (\(formatCount(pace))/day)."
    }

    private func syncDrafts() {
        if let goal = goalsManager.projectGoalWordCount {
            projectGoalDraft = "\(goal)"
        } else {
            projectGoalDraft = ""
        }
        if let deadline = goalsManager.projectGoalDeadline {
            selectedDeadlineEnabled = true
            projectDeadlineDraft = deadline
        } else {
            selectedDeadlineEnabled = false
            projectDeadlineDraft = Date()
        }
        if let sessionGoal = goalsManager.sessionGoal {
            sessionGoalDraft = "\(sessionGoal)"
        } else {
            sessionGoalDraft = ""
        }
    }

    private func formatCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}

private struct GoalsHeatmapView: View {
    let records: [DailyWritingRecord]

    var body: some View {
        let words = records.map(\.wordsWritten)
        let maxWords = max(1, words.max() ?? 1)
        let columns = Array(repeating: GridItem(.flexible(minimum: 8, maximum: 18), spacing: 4), count: 15)

        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(records, id: \.date) { record in
                RoundedRectangle(cornerRadius: 3)
                    .fill(heatColor(for: record.wordsWritten, maxWords: maxWords))
                    .frame(height: 16)
                    .help("\(record.date): \(record.wordsWritten) words")
            }
        }
    }

    private func heatColor(for words: Int, maxWords: Int) -> Color {
        guard words > 0 else { return Color.secondary.opacity(0.12) }
        let intensity = Double(words) / Double(maxWords)
        return Color(red: 0.17, green: 0.49, blue: 0.31).opacity(0.25 + (intensity * 0.75))
    }
}

private struct GoalsLineChartView: View {
    let records: [DailyWritingRecord]

    var body: some View {
        GeometryReader { geometry in
            let values = records.map { max(0, $0.wordsWritten) }
            let maxValue = max(1, values.max() ?? 1)
            let widthStep = geometry.size.width / CGFloat(max(records.count - 1, 1))

            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.secondary.opacity(0.08))

                Path { path in
                    for (index, value) in values.enumerated() {
                        let x = CGFloat(index) * widthStep
                        let normalized = CGFloat(value) / CGFloat(maxValue)
                        let y = geometry.size.height - (normalized * max(geometry.size.height - 12, 1)) - 6
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

private struct SearchPanelSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @State private var showingReplaceConfirmation = false
    @State private var quickSelectThreshold = 1
    @State private var replaceUndoNotice: String?
    @State private var replaceRedoNotice: String?
    @State private var replacePreviewFilter: ReplacePreviewFilter = .all
    @State private var replacePreviewSort: ReplacePreviewSort = .manuscriptOrder
    @State private var collapsedSearchChapters: Set<String> = []
    @State private var collapsedSearchScenes: Set<UUID> = []

    var body: some View {
        let commands = WorkspaceCommandBindings(workspace: workspace)
        sheetContent(commands: commands)
        .padding(20)
        .frame(minWidth: 640, minHeight: 420)
        .onChange(of: workspace.searchQueryText) { _, _ in
            commands.runSearch()
        }
        .onChange(of: workspace.searchScope) { _, _ in
            commands.runSearch()
        }
        .onChange(of: workspace.searchIsRegex) { _, _ in
            commands.runSearch()
        }
        .onChange(of: workspace.searchIsCaseSensitive) { _, _ in
            commands.runSearch()
        }
        .onChange(of: workspace.searchIsWholeWord) { _, _ in
            commands.runSearch()
        }
        .onChange(of: collapsedSearchSignature) { _, _ in
            synchronizeCollapsedSearchGroups()
        }
        .alert("Replace All?", isPresented: $showingReplaceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Help") {
                NotificationCenter.default.post(name: .showHelpReference, object: "replace-batches")
            }
            Button("Replace", role: .destructive) {
                let message = commands.replaceAllSearchResults()
                replaceUndoNotice = workspace.canUndoLastReplaceBatch ? message : nil
                replaceRedoNotice = nil
                onNotice(message)
            }
        } message: {
            Text("Replace \(replacePreview.replacementCount) matches across \(replacePreview.selectedScenes) selected scene(s). \(replacePreview.excludedScenes) matched scene(s) will be left unchanged.")
        }
    }

    private func sheetContent(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Find & Replace")
                    .font(.headline)
                Spacer()
                Button("Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: "find-project")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            searchInputs(commands: commands)
            replaceControls(commands: commands)
            replaceMeta(commands: commands)
            searchOptions(commands: commands)
            searchStatus
            highlightSettings
            groupedResultsList(commands: commands)
                .frame(minHeight: 220)
            HStack {
                Spacer()
                Button("Close") {
                    commands.hideSearch()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
    }

    private func searchInputs(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                SearchQueryField(
                    text: $workspace.searchQueryText,
                    onNext: { commands.navigateToNextSearchResult() },
                    onPrevious: { commands.navigateToPreviousSearchResult() }
                )
                Button("Search") {
                    commands.runSearch()
                }
            }

            HStack(spacing: 8) {
                Text(commands.searchResultPositionText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Previous") {
                    commands.navigateToPreviousSearchResult()
                }
                .keyboardShortcut(.return, modifiers: [.shift])
                .disabled(workspace.searchResults.isEmpty)
                Button("Next") {
                    commands.navigateToNextSearchResult()
                }
                .keyboardShortcut(.return)
                .disabled(workspace.searchResults.isEmpty)
            }
        }
    }

    private func replaceControls(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Replace", text: $workspace.searchReplacementText)
                    .textFieldStyle(.roundedBorder)
                Button("Replace Next") {
                    onNotice(commands.replaceNextSearchResult())
                }
                .disabled(workspace.searchQueryText.isEmpty || workspace.searchResults.isEmpty || workspace.isReplacingAll)
                Button("Replace All") {
                    if replacePreview.replacementCount > 0 && replacePreview.selectedScenes > 0 {
                        showingReplaceConfirmation = true
                    } else {
                        onNotice(replacePreview.selectedScenes == 0 ? "No scenes selected for replace." : "No matches to replace.")
                    }
                }
                .disabled(workspace.searchQueryText.isEmpty || workspace.isReplacingAll)
            }

            if let helpText = workspace.regexReplacementHelpText {
                Text(helpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let warning = workspace.regexReplacementWarning {
                Text(warning)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
    }

    private func replaceMeta(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if workspace.isReplacingAll {
                GroupBox("Replace Progress") {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: Double(workspace.replaceProgressStatus.completedScenes), total: Double(max(1, workspace.replaceProgressStatus.totalScenes)))
                        Text("Processed \(workspace.replaceProgressStatus.completedScenes) of \(workspace.replaceProgressStatus.totalScenes) scene(s); \(workspace.replaceProgressStatus.replacementsCompleted) replacement(s) applied.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let currentSceneTitle = workspace.replaceProgressStatus.currentSceneTitle {
                            Text("Current scene: \(currentSceneTitle)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            GroupBox("Replace Preview") {
                replacePreviewContent(commands: commands)
            }
            replaceUndoContent(commands: commands)
            replaceRedoContent(commands: commands)
            replaceHistoryContent(commands: commands)
            GroupBox("Commands") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Navigation: Return next match, Shift+Return previous match.")
                    Text("Find menu: Option+Command+I selects all matched scenes, Option+Command+U deselects all matched scenes.")
                    Text("Preview rows: use the Include/Exclude button or checkbox to change Replace All scope, and click a snippet to jump to that match.")
                    if commands.canUndoLastReplaceBatch {
                        Text("Safety: \(workspace.replaceUndoDepth) replace batch(es) can be undone right now.")
                    }
                    if commands.canRedoLastReplaceBatch {
                        Text("Recovery: \(workspace.replaceRedoDepth) replace batch(es) can be redone right now.")
                    }
                }
                .font(.caption2)
                .foregroundStyle(.secondary)
            }
        }
    }

    private func searchOptions(commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Picker("Scope", selection: $workspace.searchScope) {
                    ForEach(WorkspaceSearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.menu)
                Toggle("Regex", isOn: $workspace.searchIsRegex)
                Toggle("Case Sensitive", isOn: $workspace.searchIsCaseSensitive)
                Toggle("Whole Word", isOn: $workspace.searchIsWholeWord)
            }
            .toggleStyle(.checkbox)

            if workspace.searchScope == .selectedChapters {
                selectedChapterScopeContent(commands: commands)
            }
        }
    }

    private func selectedChapterScopeContent(commands: WorkspaceCommandBindings) -> some View {
        GroupBox("Chapter Scope") {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(workspace.selectedSearchChapterIDs.count) of \(workspace.searchableChapters.count) chapters selected")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Save Preset") {
                        onNotice(commands.saveSelectedSearchChapterPreset())
                    }
                    .buttonStyle(.borderless)
                    Button("Select All") {
                        workspace.selectAllSearchChapters()
                        commands.runSearch()
                    }
                    .buttonStyle(.borderless)
                    Button("Clear") {
                        workspace.clearSearchChapterSelection()
                        commands.runSearch()
                    }
                    .buttonStyle(.borderless)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(workspace.searchableChapters) { chapter in
                            Toggle(
                                chapter.title,
                                isOn: Binding(
                                    get: { workspace.selectedSearchChapterIDs.contains(chapter.id) },
                                    set: {
                                        workspace.setChapterSelectedForSearch(chapter.id, isSelected: $0)
                                        commands.runSearch()
                                    }
                                )
                            )
                            .toggleStyle(.checkbox)
                        }
                    }
                }
                .frame(maxHeight: 140)

                if !workspace.searchChapterPresets.isEmpty {
                    Divider()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Recent Presets")
                            .font(.caption.weight(.semibold))
                        ForEach(workspace.searchChapterPresets) { preset in
                            HStack(alignment: .top, spacing: 8) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                    Text(preset.summary)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("Apply") {
                                    commands.applySearchChapterPreset(preset.id)
                                    commands.runSearch()
                                }
                                .buttonStyle(.borderless)
                                Button("Delete") {
                                    commands.deleteSearchChapterPreset(preset.id)
                                }
                                .buttonStyle(.borderless)
                            }
                            .font(.caption)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var searchStatus: some View {
        if let error = workspace.searchErrorMessage {
            Text(error)
                .font(.caption)
                .foregroundStyle(.red)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("\(workspace.searchResults.count) matches")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if workspace.isSearchIndexing {
                        Text("Indexing... (\(workspace.searchIndexStatus.percentage)%)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if workspace.hiddenSearchHighlightCount > 0 {
                        Text("Showing first \(workspace.searchHighlightCap) highlights. \(workspace.hiddenSearchHighlightCount) hidden.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Show All Highlights") {
                            workspace.toggleShowAllSearchHighlights()
                        }
                        .disabled(!workspace.canEnableShowAllSearchHighlights)
                        .buttonStyle(.borderless)
                    } else if workspace.searchShowAllHighlights && workspace.searchResults.count > workspace.searchHighlightCap {
                        Button("Use Capped Highlights") {
                            workspace.toggleShowAllSearchHighlights()
                        }
                        .buttonStyle(.borderless)
                    }
                }
                if let safetyMessage = workspace.searchHighlightSafetyMessage {
                    Text(safetyMessage)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }

    private var highlightSettings: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 8) {
                Text("Highlight cap limits how many matches are drawn at once for performance.")
                    .foregroundStyle(.secondary)
                Stepper(
                    "Highlight cap: \(workspace.searchHighlightCap)",
                    value: Binding(
                        get: { workspace.searchHighlightCap },
                        set: { workspace.updateSearchHighlightCap($0) }
                    ),
                    in: workspace.searchHighlightCapRange,
                    step: 10
                )
                Text("Safety threshold blocks Show All when a scene has too many matches.")
                    .foregroundStyle(.secondary)
                Stepper(
                    "Show-all safety threshold: \(workspace.searchHighlightSafetyThreshold)",
                    value: Binding(
                        get: { workspace.searchHighlightSafetyThreshold },
                        set: { workspace.updateSearchHighlightSafetyThreshold($0) }
                    ),
                    in: workspace.searchHighlightSafetyThresholdRange,
                    step: 100
                )
                HStack {
                    Spacer()
                    Button("Reset to Defaults") {
                        workspace.resetSearchHighlightPreferencesToDefaults()
                    }
                    .disabled(workspace.usesDefaultSearchHighlightPreferences)
                }
            }
            .font(.caption)
        } label: {
            HStack(spacing: 6) {
                Text("Highlight Settings")
                Button {
                    workspace.showSearchHighlightHelp()
                } label: {
                    Image(systemName: "info.circle")
                }
                .buttonStyle(.plain)
                .help("Learn how cap and safety threshold work")
                .popover(isPresented: $workspace.isSearchHighlightHelpVisible, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Highlight Settings")
                            .font(.headline)
                        Text("Highlight cap controls how many matches are drawn at once.")
                        Text("Safety threshold blocks Show All when a scene has many matches.")
                        Text("Example: If cap is 100 and threshold is 2,000, scenes over 2,000 matches stay capped.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .padding(12)
                    .frame(maxWidth: 320, alignment: .leading)
                }
            }
        }
    }

    private var replacePreview: (replacementCount: Int, scenesAffected: Int, selectedScenes: Int, excludedScenes: Int) {
        let allPreviewItems = workspace.replacePreviewItems()
        let scenesAffected = allPreviewItems.count
        let selectedSceneIDs = Set(allPreviewItems.filter(\.isIncluded).map(\.id))
        let replacementCount = workspace.searchResults.filter { selectedSceneIDs.contains($0.sceneId) }.count
        let selectedScenes = workspace.selectedReplaceSceneCount
        return (replacementCount, scenesAffected, selectedScenes, max(0, scenesAffected - selectedScenes))
    }

    @ViewBuilder
    private func replacePreviewContent(commands: WorkspaceCommandBindings) -> some View {
        let items = workspace.replacePreviewItems(filter: replacePreviewFilter, sort: replacePreviewSort)
        let totalItems = workspace.replacePreviewItems()
        if totalItems.isEmpty {
            Text("No scene matches to preview.")
                .font(.caption)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Picker("Selection Mode", selection: $workspace.replaceSceneSelectionMode) {
                    ForEach(ReplaceSceneSelectionMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)

                HStack {
                    Picker("Show", selection: $replacePreviewFilter) {
                        ForEach(ReplacePreviewFilter.allCases) { filter in
                            Text(filter.title).tag(filter)
                        }
                    }
                    .pickerStyle(.menu)
                    Picker("Sort", selection: $replacePreviewSort) {
                        ForEach(ReplacePreviewSort.allCases) { sort in
                            Text(sort.title).tag(sort)
                        }
                    }
                    .pickerStyle(.menu)
                    Spacer()
                    Text("Showing \(items.count) of \(totalItems.count)")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("\(workspace.selectedReplaceSceneCount) of \(totalItems.count) scenes selected")
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Include All") {
                        commands.includeAllReplaceScenes()
                    }
                    .buttonStyle(.borderless)
                    Button("Exclude All") {
                        commands.excludeAllReplaceScenes()
                    }
                    .buttonStyle(.borderless)
                }
                if totalItems.count != workspace.selectedReplaceSceneCount {
                    Text("\(totalItems.count - workspace.selectedReplaceSceneCount) scene(s) excluded from Replace All.")
                        .foregroundStyle(.orange)
                }
                HStack {
                    Stepper("Match threshold: >\(quickSelectThreshold)", value: $quickSelectThreshold, in: 0...500, step: 1)
                    Button("Select >N Matches") {
                        workspace.includeReplaceScenes(withMatchCountGreaterThan: quickSelectThreshold)
                    }
                    .buttonStyle(.borderless)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(items) { item in
                            replacePreviewRow(for: item, commands: commands)
                        }
                    }
                }
                .frame(maxHeight: 220)
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private func replaceUndoContent(commands: WorkspaceCommandBindings) -> some View {
        if let notice = replaceUndoNotice {
            HStack {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(undoButtonTitle) {
                    replaceUndoNotice = commands.undoLastReplaceBatch()
                }
                .buttonStyle(.borderless)
                .disabled(!commands.canUndoLastReplaceBatch)
            }
        } else if commands.canUndoLastReplaceBatch {
            HStack {
                Button(undoButtonTitle) {
                    replaceUndoNotice = commands.undoLastReplaceBatch()
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .font(.caption)
        }
    }

    private var undoButtonTitle: String {
        let depth = workspace.replaceUndoDepth
        if depth > 1 {
            return "Undo Last Replace (\(depth) remaining)"
        }
        return "Undo Last Replace"
    }

    private var redoButtonTitle: String {
        let depth = workspace.replaceRedoDepth
        if depth > 1 {
            return "Redo Last Replace (\(depth) remaining)"
        }
        return "Redo Last Replace"
    }

    private func replacePreviewRow(for item: ReplacePreviewSceneItem, commands: WorkspaceCommandBindings) -> some View {
        let isIncluded = workspace.isSceneIncludedForReplace(item.id)
        return HStack(spacing: 8) {
            Toggle(
                "",
                isOn: Binding(
                    get: { workspace.isSceneIncludedForReplace(item.id) },
                    set: { workspace.setSceneIncludedForReplace(item.id, included: $0) }
                )
            )
            .toggleStyle(.checkbox)
            .labelsHidden()

            VStack(alignment: .leading, spacing: 2) {
                Text("\(item.chapterTitle) • \(item.sceneTitle)")
                    .lineLimit(1)
                    .foregroundStyle(isIncluded ? .primary : .secondary)
                Text("\(item.matchCount) match(es)")
                    .foregroundStyle(isIncluded ? .secondary : Color.orange)
                if !item.matchTargets.isEmpty {
                    VStack(alignment: .leading, spacing: 1) {
                        ForEach(item.matchTargets) { target in
                            Button {
                                commands.selectReplacePreviewMatch(sceneID: item.id, resultIndex: target.resultIndex)
                            } label: {
                                previewSnippetText(target.snippet)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            Spacer()

            if !isIncluded {
                Text("Excluded")
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(workspace.themePalette.warningFill(), in: Capsule())
                    .foregroundStyle(workspace.themePalette.warningText)
            }

            Button(isIncluded ? "Exclude" : "Include") {
                workspace.setSceneIncludedForReplace(item.id, included: !isIncluded)
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func replaceHistoryContent(commands: WorkspaceCommandBindings) -> some View {
        let undoHistory = workspace.replaceUndoHistory
        let redoHistory = workspace.replaceRedoHistory
        if !undoHistory.isEmpty || !redoHistory.isEmpty {
            GroupBox("Replace History") {
                VStack(alignment: .leading, spacing: 6) {
                    if !undoHistory.isEmpty {
                        Text("Undo")
                            .font(.caption.weight(.semibold))
                        ForEach(undoHistory.prefix(3)) { entry in
                            historyRow(entry: entry, isActive: undoHistory.first?.id == entry.id, actionTitle: undoButtonTitle) {
                                replaceUndoNotice = commands.undoLastReplaceBatch()
                                replaceRedoNotice = nil
                            }
                        }
                    }
                    if !redoHistory.isEmpty {
                        Text("Redo")
                            .font(.caption.weight(.semibold))
                        ForEach(redoHistory.prefix(3)) { entry in
                            historyRow(entry: entry, isActive: redoHistory.first?.id == entry.id, actionTitle: redoButtonTitle) {
                                replaceRedoNotice = commands.redoLastReplaceBatch()
                                replaceUndoNotice = nil
                            }
                        }
                    }
                }
            }
        }
    }

    private func historyRow(entry: ReplaceBatchHistoryItem, isActive: Bool, actionTitle: String, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.title)
                Text(entry.summary)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isActive {
                Button(actionTitle) {
                    action()
                }
                .buttonStyle(.borderless)
            } else {
                Text("Pending")
                    .foregroundStyle(.secondary)
            }
        }
        .font(.caption)
    }

    @ViewBuilder
    private func replaceRedoContent(commands: WorkspaceCommandBindings) -> some View {
        if let notice = replaceRedoNotice {
            HStack {
                Text(notice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button(redoButtonTitle) {
                    replaceRedoNotice = commands.redoLastReplaceBatch()
                }
                .buttonStyle(.borderless)
                .disabled(!commands.canRedoLastReplaceBatch)
            }
        } else if commands.canRedoLastReplaceBatch {
            HStack {
                Button(redoButtonTitle) {
                    replaceRedoNotice = commands.redoLastReplaceBatch()
                }
                .buttonStyle(.borderless)
                Spacer()
            }
            .font(.caption)
        }
    }

    private func previewSnippetText(_ snippet: String) -> Text {
        guard let range = snippet.range(
            of: workspace.searchQueryText,
            options: workspace.searchIsCaseSensitive ? [] : [.caseInsensitive]
        ) else {
            return Text(snippet)
        }

        let prefix = String(snippet[..<range.lowerBound])
        let match = String(snippet[range])
        let suffix = String(snippet[range.upperBound...])
        return Text(prefix) + Text(match).bold() + Text(suffix)
    }

    private func highlightedSnippetText(for result: SearchResult) -> Text {
        guard !result.matchText.isEmpty,
              let range = result.contextSnippet.range(
                of: result.matchText,
                options: workspace.searchIsCaseSensitive ? [] : [.caseInsensitive]
              ) else {
            return Text(result.contextSnippet)
        }

        let prefix = String(result.contextSnippet[..<range.lowerBound])
        let match = String(result.contextSnippet[range])
        let suffix = String(result.contextSnippet[range.upperBound...])
        return Text(prefix) + Text(match).bold() + Text(suffix)
    }

    private func groupedResultsList(commands: WorkspaceCommandBindings) -> some View {
        List {
            ForEach(workspace.groupedSearchResults) { section in
                Section {
                    if !collapsedSearchChapters.contains(section.id) {
                        ForEach(section.scenes) { scene in
                            groupedResultsScene(scene, commands: commands)
                        }
                    }
                } header: {
                    groupedResultsSectionHeader(section)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func groupedResultsSectionHeader(_ section: SearchResultSection) -> some View {
        GroupedResultsSectionHeaderView(
            title: section.chapterTitle,
            matchCount: section.matchCount,
            isCollapsed: collapsedSearchChapters.contains(section.id),
            onToggle: { toggleChapterCollapse(section.id) }
        )
        .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 4, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func groupedResultsScene(_ scene: SearchResultSceneGroup, commands: WorkspaceCommandBindings) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GroupedResultsSceneHeaderView(
                title: scene.sceneTitle,
                matchCount: scene.matchCount,
                isCollapsed: collapsedSearchScenes.contains(scene.id),
                onToggle: { toggleSceneCollapse(scene.id) }
            )

            if !collapsedSearchScenes.contains(scene.id) {
                ForEach(scene.results) { item in
                    groupedResultsItem(item, commands: commands)
                }
            }
        }
        .padding(.vertical, 4)
        .listRowInsets(EdgeInsets(top: 0, leading: 10, bottom: 4, trailing: 10))
        .listRowSeparator(.hidden)
        .listRowBackground(Color.clear)
    }

    private func groupedResultsItem(_ item: SearchResultListItem, commands: WorkspaceCommandBindings) -> some View {
        GroupedResultsItemRowView(
            resultIndex: item.resultIndex,
            snippet: highlightedSnippetText(for: item.result),
            isSelected: workspace.currentSearchResultIndex == item.resultIndex,
            onSelect: { commands.selectSearchResult(at: item.resultIndex) }
        )
        .padding(.leading, 18)
    }

    private func toggleChapterCollapse(_ chapterID: String) {
        if collapsedSearchChapters.contains(chapterID) {
            collapsedSearchChapters.remove(chapterID)
        } else {
            collapsedSearchChapters.insert(chapterID)
        }
    }

    private func toggleSceneCollapse(_ sceneID: UUID) {
        if collapsedSearchScenes.contains(sceneID) {
            collapsedSearchScenes.remove(sceneID)
        } else {
            collapsedSearchScenes.insert(sceneID)
        }
    }

    private func synchronizeCollapsedSearchGroups() {
        let activeChapterIDs = Set(workspace.groupedSearchResults.map(\.id))
        collapsedSearchChapters = collapsedSearchChapters.intersection(activeChapterIDs)

        let activeSceneIDs = Set(workspace.groupedSearchResults.flatMap(\.scenes).map(\.id))
        collapsedSearchScenes = collapsedSearchScenes.intersection(activeSceneIDs)
    }

    private var collapsedSearchSignature: String {
        let chapterIDs = workspace.groupedSearchResults.map(\.id)
        let sceneIDs = workspace.groupedSearchResults
            .flatMap(\.scenes)
            .map { $0.id.uuidString }
        return (chapterIDs + sceneIDs).joined(separator: "|")
    }
}

private struct CommandPaletteSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    @Binding var query: String
    let windowWidth: CGFloat
    let onCancel: () -> Void
    let onNotice: (String?) -> Void
    let onShowNewProject: () -> Void
    let onShowOpenProject: () -> Void
    let onShowSaveAs: () -> Void
    let onShowRename: () -> Void
    let onShowProjectSettings: () -> Void
    let onShowImportExport: () -> Void
    let onShowTimeline: () -> Void
    let onShowEntities: () -> Void
    let onShowSources: () -> Void
    let onShowNotes: () -> Void
    let onShowScratchpad: () -> Void
    let onShowHelp: (String?) -> Void
    let onShowProjectSwitcher: () -> Void
    @State private var selectedItemID: String?

    private var commands: WorkspaceCommandBindings {
        WorkspaceCommandBindings(workspace: workspace)
    }

    private var filteredItems: [CommandPaletteItem] {
        WorkspaceCommandPalette.filteredItems(workspace: workspace, commands: commands, query: query)
    }

    private var selectedItem: CommandPaletteItem? {
        guard let selectedItemID else { return filteredItems.first(where: { $0.isEnabled }) ?? filteredItems.first }
        return filteredItems.first(where: { $0.id == selectedItemID }) ?? filteredItems.first(where: { $0.isEnabled }) ?? filteredItems.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Command Palette")
                .font(.headline)
            TextField("Search actions, scenes, and projects", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit(runSelectedItem)
                .accessibilityLabel("Command palette search")
                .accessibilityHint("Search actions, projects, chapters, and scenes")
            if filteredItems.isEmpty {
                ContentUnavailableView(
                    "No Matching Commands",
                    systemImage: "magnifyingglass",
                    description: Text("Try a different search term.")
                )
                .frame(minHeight: 260)
            } else {
                List(selection: $selectedItemID) {
                    ForEach(filteredItems) { item in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 8) {
                                    Text(item.title)
                                        .foregroundStyle(item.isEnabled ? .primary : .secondary)
                                    Text(item.category)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Text(item.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let shortcut = item.shortcut {
                                Text(shortcut)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .opacity(item.isEnabled ? 1 : 0.55)
                        .tag(item.id)
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            execute(item)
                        }
                        .onTapGesture {
                            selectedItemID = item.id
                        }
                    }
                }
                .frame(minHeight: 320)
                .onMoveCommand { direction in
                    switch direction {
                    case .down:
                        moveSelection(offset: 1)
                    case .up:
                        moveSelection(offset: -1)
                    default:
                        break
                    }
                }
                .onExitCommand(perform: onCancel)
            }
            HStack {
                Text("\(filteredItems.count) command\(filteredItems.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Run", action: runSelectedItem)
                    .keyboardShortcut(.defaultAction)
                    .disabled(selectedItem?.isEnabled != true)
                    .accessibilityLabel("Run selected command")
            }
        }
        .padding(20)
        .frame(minWidth: 620, minHeight: 420)
        .onAppear {
            synchronizeSelection()
        }
        .onChange(of: filteredItems.map(\.id)) { _, _ in
            synchronizeSelection()
        }
    }

    private func synchronizeSelection() {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }
        if let selectedItemID,
           filteredItems.contains(where: { $0.id == selectedItemID && $0.isEnabled }) {
            return
        }
        selectedItemID = filteredItems.first(where: { $0.isEnabled })?.id ?? filteredItems.first?.id
    }

    private func moveSelection(offset: Int) {
        guard !filteredItems.isEmpty else {
            selectedItemID = nil
            return
        }
        let ids = filteredItems.map(\.id)
        guard let selectedItemID,
              let currentIndex = ids.firstIndex(of: selectedItemID) else {
            self.selectedItemID = filteredItems.first(where: { $0.isEnabled })?.id ?? filteredItems.first?.id
            return
        }
        let nextIndex = min(max(currentIndex + offset, 0), ids.count - 1)
        self.selectedItemID = ids[nextIndex]
    }

    private func runSelectedItem() {
        guard let selectedItem, selectedItem.isEnabled else { return }
        execute(selectedItem)
    }

    private func execute(_ item: CommandPaletteItem) {
        guard item.isEnabled else { return }
        onCancel()
        switch item.action {
        case let .showHelp(entryID):
            DispatchQueue.main.async {
                onShowHelp(entryID)
            }
        case .createProject:
            DispatchQueue.main.async(execute: onShowNewProject)
        case .openProject:
            DispatchQueue.main.async(execute: onShowOpenProject)
        case .switchProject:
            DispatchQueue.main.async(execute: onShowProjectSwitcher)
        case .reopenLastProject:
            onNotice(commands.reopenLastProject())
        case let .openRecentProject(url):
            onNotice(commands.openProject(at: url))
        case .saveProject:
            onNotice(commands.saveProject() ?? "Project saved.")
        case .saveProjectAs:
            DispatchQueue.main.async(execute: onShowSaveAs)
        case .renameProject:
            DispatchQueue.main.async(execute: onShowRename)
        case .duplicateRecoveryProject:
            onNotice(commands.duplicateRecoveryProject())
        case .exportRecoveryMarkdown:
            onNotice(commands.exportRecoveryProject(format: .markdown))
        case .showProjectSettings:
            DispatchQueue.main.async(execute: onShowProjectSettings)
        case let .setTheme(theme):
            onNotice(commands.setTheme(theme))
        case let .applyAppearancePreset(presetID):
            onNotice(commands.applyAppearancePreset(presetID))
        case .showImportExport:
            DispatchQueue.main.async(execute: onShowImportExport)
        case .showTimeline:
            DispatchQueue.main.async(execute: onShowTimeline)
        case .showEntities:
            DispatchQueue.main.async(execute: onShowEntities)
        case .showSources:
            DispatchQueue.main.async(execute: onShowSources)
        case .showNotes:
            DispatchQueue.main.async(execute: onShowNotes)
        case .showScratchpad:
            DispatchQueue.main.async(execute: onShowScratchpad)
        case .createChapter:
            onNotice(commands.createChapter())
        case .createScene:
            onNotice(commands.createScene())
        case .createSceneBelow:
            onNotice(commands.createSceneBelow())
        case .duplicateSelectedScene:
            onNotice(commands.duplicateSelectedScene())
        case .createBackup:
            onNotice(commands.createBackup())
        case .saveAndBackup:
            onNotice(commands.saveAndBackup())
        case let .setMode(mode):
            switch mode {
            case .linear:
                commands.setModeLinear()
            case .modular:
                commands.setModeModular()
            }
            onNotice(nil)
        case .toggleSplit:
            onNotice(commands.toggleSplit(defaultWindowWidth: windowWidth))
        case .openSelectionInSplit:
            onNotice(commands.openSelectionInSplit(defaultWindowWidth: windowWidth))
        case .revealSelectionInSidebar:
            onNotice(commands.revealSelectionInSidebar())
        case .showCorkboard:
            commands.showCorkboardMode()
            onNotice(nil)
        case .showOutliner:
            commands.showOutlinerMode()
            onNotice(nil)
        case .modularGroupingChapter:
            commands.groupModularByChapter()
            onNotice(nil)
        case .modularGroupingFlat:
            commands.groupModularFlat()
            onNotice(nil)
        case .modularGroupingStatus:
            commands.groupModularByStatus()
            onNotice(nil)
        case .corkboardDensityComfortable:
            commands.setCorkboardDensityComfortable()
            onNotice(nil)
        case .corkboardDensityCompact:
            commands.setCorkboardDensityCompact()
            onNotice(nil)
        case .collapseAllModularGroups:
            commands.collapseAllModularGroups()
            onNotice(nil)
        case .expandAllModularGroups:
            commands.expandAllModularGroups()
            onNotice(nil)
        case .toggleInspector:
            commands.toggleInspector()
            onNotice(nil)
        case .moveSelectedSceneUp:
            onNotice(commands.moveSelectedSceneUp())
        case .moveSelectedSceneDown:
            onNotice(commands.moveSelectedSceneDown())
        case .moveSelectedSceneToChapter:
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .showMoveSceneSheet, object: nil)
            }
        case .sendSelectedSceneToStaging:
            onNotice(commands.sendSelectedSceneToStaging())
        case .navigateToPreviousScene:
            _ = commands.navigateToPreviousScene()
            onNotice(nil)
        case .navigateToNextScene:
            _ = commands.navigateToNextScene()
            onNotice(nil)
        case .showInlineSearch:
            DispatchQueue.main.async {
                commands.showInlineSearch()
            }
        case .showProjectSearch:
            DispatchQueue.main.async {
                commands.showProjectSearch()
            }
        case .undoLastReplaceBatch:
            onNotice(commands.undoLastReplaceBatch())
        case .redoLastReplaceBatch:
            onNotice(commands.redoLastReplaceBatch())
        case let .navigateToChapter(chapterID):
            workspace.navigateToChapter(chapterID)
            onNotice(nil)
        case let .navigateToScene(sceneID):
            workspace.navigateToScene(sceneID)
            onNotice(nil)
        }
    }
}

private struct SearchQueryField: NSViewRepresentable {
    @Binding var text: String
    let onNext: () -> Void
    let onPrevious: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onNext: onNext, onPrevious: onPrevious)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: text)
        field.placeholderString = "Find"
        field.delegate = context.coordinator
        field.isBezeled = true
        field.bezelStyle = .roundedBezel
        return field
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        context.coordinator.text = $text
    }

    final class Coordinator: NSObject, NSTextFieldDelegate {
        var text: Binding<String>
        let onNext: () -> Void
        let onPrevious: () -> Void

        init(text: Binding<String>, onNext: @escaping () -> Void, onPrevious: @escaping () -> Void) {
            self.text = text
            self.onNext = onNext
            self.onPrevious = onPrevious
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) ||
                commandSelector == #selector(NSResponder.insertLineBreak(_:)) {
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    onPrevious()
                } else {
                    onNext()
                }
                return true
            }
            return false
        }
    }
}

private struct ProjectSwitcherSheet: View {
    @Binding var query: String
    let projects: [RecentProjectEntry]
    let onCancel: () -> Void
    let onSelect: (RecentProjectEntry) -> Void
    @State private var selection = ProjectSwitcherSelection()

    private var filteredProjects: [RecentProjectEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return projects }
        return projects.filter { entry in
            entry.name.localizedCaseInsensitiveContains(trimmed) ||
            entry.url.path.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var selectedProject: RecentProjectEntry? {
        selection.selectedProject(in: filteredProjects)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Switch Project")
                    .font(.headline)
                Spacer()
                Button("Help") {
                    NotificationCenter.default.post(name: .showHelpReference, object: "project-switcher")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            TextField("Search projects", text: $query)
                .textFieldStyle(.roundedBorder)
                .onSubmit(openSelectedProject)
            List(selection: $selection.selectedProjectID) {
                ForEach(filteredProjects) { project in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(project.name)
                        Text(project.url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(project.id)
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        onSelect(project)
                    }
                    .onTapGesture {
                        selection.selectedProjectID = project.id
                    }
                }
            }
            .frame(minHeight: 220)
            .onMoveCommand { direction in
                switch direction {
                case .down:
                    selection.moveSelection(offset: 1, in: filteredProjects)
                case .up:
                    selection.moveSelection(offset: -1, in: filteredProjects)
                default:
                    break
                }
            }
            .onExitCommand(perform: onCancel)
            HStack {
                Spacer()
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                Button("Open") {
                    openSelectedProject()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedProject == nil)
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 360)
        .onAppear {
            selection.synchronizeSelection(with: filteredProjects)
        }
        .onChange(of: filteredProjects.map(\.id)) { _, _ in
            selection.synchronizeSelection(with: filteredProjects)
        }
    }

    private func openSelectedProject() {
        guard let selectedProject else { return }
        onSelect(selectedProject)
    }
}

private enum RecentProjectsAction {
    case clearAll
    case cleanupMissing
}

private extension Notification.Name {
    static let showCommandPalette = Notification.Name("workspace.showCommandPalette")
    static let showProjectSwitcher = Notification.Name("workspace.showProjectSwitcher")
    static let showGoalsDashboard = Notification.Name("workspace.showGoalsDashboard")
    static let showProjectSettings = Notification.Name("workspace.showProjectSettings")
    static let showImportExport = Notification.Name("workspace.showImportExport")
    static let showTimelineSheet = Notification.Name("workspace.showTimelineSheet")
    static let showEntitiesSheet = Notification.Name("workspace.showEntitiesSheet")
    static let showSourcesSheet = Notification.Name("workspace.showSourcesSheet")
    static let showNotesSheet = Notification.Name("workspace.showNotesSheet")
    static let showScratchpadSheet = Notification.Name("workspace.showScratchpadSheet")
    static let showHelpReference = Notification.Name("workspace.showHelpReference")
    static let showMoveSceneSheet = Notification.Name("workspace.showMoveSceneSheet")
    static let showInlineSearch = Notification.Name("workspace.showInlineSearch")
    static let showProjectSearch = Notification.Name("workspace.showProjectSearch")
    static let requestClearRecentProjects = Notification.Name("workspace.requestClearRecentProjects")
    static let requestCleanupMissingRecentProjects = Notification.Name("workspace.requestCleanupMissingRecentProjects")
    static let showSaveAsSheet = Notification.Name("workspace.showSaveAsSheet")
    static let showRenameSheet = Notification.Name("workspace.showRenameSheet")
}
