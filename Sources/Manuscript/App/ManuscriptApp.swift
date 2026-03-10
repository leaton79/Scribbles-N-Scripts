import SwiftUI
import UniformTypeIdentifiers
import AppKit

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
                Button("Switch Project…") {
                    NotificationCenter.default.post(name: .showProjectSwitcher, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command])

                Divider()

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
    @State private var showingProjectSwitcher = false
    @State private var projectSwitcherQuery = ""
    @State private var pendingRecentAction: RecentProjectsAction?
    @State private var showingRecentActionConfirmation = false
    @State private var recentUndoSnapshot: RecentProjectsSnapshot?
    @State private var recentUndoMessage: String?
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
                            if let recentUndoMessage {
                                Text(recentUndoMessage)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button("Undo") {
                                    if let recentUndoSnapshot {
                                        commands.restoreRecentProjects(from: recentUndoSnapshot)
                                        actionNotice = "Recent project changes undone."
                                    }
                                    recentUndoSnapshot = nil
                                    self.recentUndoMessage = nil
                                }
                                .buttonStyle(.borderless)
                            }
                            if let splitNotice {
                                Text(splitNotice)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Switch Project") {
                                projectSwitcherQuery = ""
                                showingProjectSwitcher = true
                            }
                            Button("Find") {
                                commands.showProjectSearch()
                            }
                            .disabled(!commands.canSearchProject)
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
                .onAppear {
                    if commands.hasStaleRecentProjects {
                        pendingRecentAction = .cleanupMissing
                        showingRecentActionConfirmation = true
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .showProjectSwitcher)) { _ in
                    projectSwitcherQuery = ""
                    showingProjectSwitcher = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .showInlineSearch)) { _ in
                    commands.showInlineSearch()
                }
                .onReceive(NotificationCenter.default.publisher(for: .showProjectSearch)) { _ in
                    commands.showProjectSearch()
                }
                .onReceive(NotificationCenter.default.publisher(for: .requestClearRecentProjects)) { _ in
                    pendingRecentAction = .clearAll
                    showingRecentActionConfirmation = true
                }
                .onReceive(NotificationCenter.default.publisher(for: .requestCleanupMissingRecentProjects)) { _ in
                    pendingRecentAction = .cleanupMissing
                    showingRecentActionConfirmation = true
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
                .sheet(isPresented: $showingProjectSwitcher) {
                    ProjectSwitcherSheet(
                        query: $projectSwitcherQuery,
                        projects: commands.switchableProjects,
                        onCancel: { showingProjectSwitcher = false },
                        onSelect: { entry in
                            actionNotice = commands.openProject(at: entry.url)
                            showingProjectSwitcher = false
                        }
                    )
                }
                .sheet(
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
                }
                .alert(recentActionTitle, isPresented: $showingRecentActionConfirmation) {
                    Button("Cancel", role: .cancel) {}
                    Button(recentActionButtonTitle, role: .destructive) {
                        performRecentAction(using: commands)
                    }
                } message: {
                    Text(recentActionMessage)
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

private struct SearchPanelSheet: View {
    @ObservedObject var workspace: WorkspaceCoordinator
    let onNotice: (String?) -> Void
    @State private var showingReplaceConfirmation = false

    var body: some View {
        let commands = WorkspaceCommandBindings(workspace: workspace)
        VStack(alignment: .leading, spacing: 12) {
            Text("Find & Replace")
                .font(.headline)

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

            HStack(spacing: 8) {
                TextField("Replace", text: $workspace.searchReplacementText)
                    .textFieldStyle(.roundedBorder)
                Button("Replace Next") {
                    onNotice(commands.replaceNextSearchResult())
                }
                .disabled(workspace.searchQueryText.isEmpty || workspace.searchResults.isEmpty)
                Button("Replace All") {
                    if replacePreview.replacementCount > 0 {
                        showingReplaceConfirmation = true
                    } else {
                        onNotice("No matches to replace.")
                    }
                }
                .disabled(workspace.searchQueryText.isEmpty)
            }

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

            if let error = workspace.searchErrorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            } else {
                Text("\(workspace.searchResults.count) matches")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            List {
                ForEach(Array(workspace.searchResults.enumerated()), id: \.offset) { index, result in
                    Button {
                        commands.selectSearchResult(at: index)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(result.chapterTitle) • \(result.sceneTitle)")
                                .font(.subheadline.weight(workspace.currentSearchResultIndex == index ? .semibold : .regular))
                            highlightedSnippetText(for: result)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(minHeight: 220)

            HStack {
                Spacer()
                Button("Close") {
                    commands.hideSearch()
                }
                .keyboardShortcut(.cancelAction)
            }
        }
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
        .alert("Replace All?", isPresented: $showingReplaceConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Replace", role: .destructive) {
                onNotice(commands.replaceAllSearchResults())
            }
        } message: {
            Text("\(replacePreview.replacementCount) replacements across \(replacePreview.scenesAffected) scenes. Proceed?")
        }
    }

    private var replacePreview: (replacementCount: Int, scenesAffected: Int) {
        let scenesAffected = Set(workspace.searchResults.map(\.sceneId)).count
        return (workspace.searchResults.count, scenesAffected)
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
            Text("Switch Project")
                .font(.headline)
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
    static let showProjectSwitcher = Notification.Name("workspace.showProjectSwitcher")
    static let showInlineSearch = Notification.Name("workspace.showInlineSearch")
    static let showProjectSearch = Notification.Name("workspace.showProjectSearch")
    static let requestClearRecentProjects = Notification.Name("workspace.requestClearRecentProjects")
    static let requestCleanupMissingRecentProjects = Notification.Name("workspace.requestCleanupMissingRecentProjects")
    static let showSaveAsSheet = Notification.Name("workspace.showSaveAsSheet")
    static let showRenameSheet = Notification.Name("workspace.showRenameSheet")
}
