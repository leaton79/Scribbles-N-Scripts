import Foundation
import SwiftUI

struct RecentProjectEntry: Identifiable, Equatable {
    let id: String
    let name: String
    let url: URL
}

struct RecentProjectsSnapshot: Equatable {
    let paths: [String]
    let lastOpenedPath: String?
}

@MainActor
final class WorkspaceCoordinator: ObservableObject {
    private static let lastOpenedProjectPathKey = "workspace.lastOpenedProjectPath"
    private static let recentProjectsKey = "workspace.recentProjects"
    private static let maxRecentProjects = 10

    let projectManager: FileSystemProjectManager
    let navigationState: NavigationState
    let editorState: EditorState
    let linearState: LinearModeState
    let modularState: ModularModeState
    let modeController: ModeController
    let splitEditorState: SplitEditorState
    let goalsManager: GoalsManager
    private let recentProjectStore: UserDefaults
    private lazy var searchEngine = makeSearchEngine()

    @Published var loadError: String?
    @Published var isSearchPanelVisible = false
    @Published var searchQueryText = ""
    @Published var searchReplacementText = ""
    @Published var searchScope: WorkspaceSearchScope = .currentScene
    @Published var searchIsRegex = false
    @Published var searchIsCaseSensitive = false
    @Published var searchIsWholeWord = false
    @Published private(set) var searchResults: [SearchResult] = []
    @Published private(set) var searchErrorMessage: String?

    var hasOpenProject: Bool {
        projectManager.currentProject != nil
    }

    var canReopenLastProject: Bool {
        lastOpenedProjectURL() != nil
    }

    var recentProjects: [RecentProjectEntry] {
        recentProjectURLs().map { url in
            RecentProjectEntry(id: url.path, name: url.lastPathComponent, url: url)
        }
    }

    var switchableProjects: [RecentProjectEntry] {
        var entries: [RecentProjectEntry] = []
        var seen = Set<String>()

        if let current = currentProjectEntry {
            entries.append(current)
            seen.insert(current.id)
        }
        for recent in recentProjects where !seen.contains(recent.id) {
            entries.append(recent)
            seen.insert(recent.id)
        }
        return entries
    }

    var hasStaleRecentProjects: Bool {
        let stored = recentProjectPaths()
        let valid = Set(recentProjectURLs().map(\.path))
        return stored.contains { !valid.contains($0) }
    }

    var canClearRecentProjects: Bool {
        !recentProjects.isEmpty
    }

    var canSaveProjectAs: Bool {
        hasOpenProject
    }

    var canRenameProject: Bool {
        hasOpenProject
    }

    var projectDisplayName: String {
        projectManager.currentProject?.name ?? "Scribbles N Scripts"
    }

    var hasUnsavedChanges: Bool {
        guard projectManager.currentProject != nil else {
            return false
        }
        if projectManager.isDirty || editorState.isModified {
            return true
        }
        if splitEditorState.isSplit && (splitEditorState.primaryEditor.isModified || splitEditorState.secondaryEditor.isModified) {
            return true
        }
        return false
    }

    var canSaveProject: Bool {
        hasUnsavedChanges
    }

    var canNavigateToNextScene: Bool {
        guard projectManager.currentProject != nil,
              modeController.activeMode == .linear,
              let current = editorState.currentSceneId,
              let index = linearState.orderedSceneIds.firstIndex(of: current) else {
            return false
        }
        return index + 1 < linearState.orderedSceneIds.count
    }

    var canNavigateToPreviousScene: Bool {
        guard projectManager.currentProject != nil,
              modeController.activeMode == .linear,
              let current = editorState.currentSceneId,
              let index = linearState.orderedSceneIds.firstIndex(of: current) else {
            return false
        }
        return index > 0
    }

    var canToggleSplitEditor: Bool {
        guard projectManager.currentProject != nil else {
            return false
        }
        if splitEditorState.isSplit {
            return true
        }
        guard modeController.activeMode == .linear else {
            return false
        }
        return resolveSceneForSplitOpen() != nil
    }

    var canSwitchToLinearMode: Bool {
        hasOpenProject && modeController.activeMode != .linear
    }

    var canSwitchToModularMode: Bool {
        hasOpenProject && modeController.activeMode != .modular
    }

    init(
        projectManager manager: FileSystemProjectManager = FileSystemProjectManager(),
        bootstrapRootURL: URL? = nil,
        bootstrapProjectName: String = "Sandbox",
        splitSettingsStore: UserDefaults = .standard,
        recentProjectStore: UserDefaults = .standard
    ) {
        self.projectManager = manager
        self.recentProjectStore = recentProjectStore

        do {
            try Self.bootstrapProject(
                using: manager,
                rootURL: bootstrapRootURL,
                projectName: bootstrapProjectName,
                recentProjectStore: recentProjectStore
            )
            let dependencies = Self.makeDependencies(
                manager: manager,
                splitSettingsStore: splitSettingsStore,
                splitSettingsNamespace: Self.splitSettingsNamespace(for: manager)
            )
            self.navigationState = dependencies.navigationState
            self.editorState = dependencies.editorState
            self.linearState = dependencies.linearState
            self.modularState = dependencies.modularState
            self.modeController = dependencies.modeController
            self.splitEditorState = dependencies.splitEditorState
            self.goalsManager = dependencies.goalsManager
            self.goalsManager.bind(to: self.editorState)
            persistLastOpenedProject()

            if dependencies.editorState.currentSceneId == nil, let first = dependencies.linearState.orderedSceneIds.first {
                dependencies.linearState.goToScene(id: first)
                dependencies.splitEditorState.primarySceneId = first
            }
            startSearchIndexing()
        } catch {
            self.loadError = error.localizedDescription
            let dependencies = Self.makeDependencies(
                manager: manager,
                splitSettingsStore: splitSettingsStore,
                splitSettingsNamespace: Self.splitSettingsNamespace(for: manager)
            )
            self.navigationState = dependencies.navigationState
            self.editorState = dependencies.editorState
            self.linearState = dependencies.linearState
            self.modularState = dependencies.modularState
            self.modeController = dependencies.modeController
            self.splitEditorState = dependencies.splitEditorState
            self.goalsManager = dependencies.goalsManager
            self.goalsManager.bind(to: self.editorState)
        }
    }

    func select(node: SidebarNode) {
        guard hasOpenProject else { return }
        switch node.level {
        case .scene:
            guard sceneExists(node.id) else { return }
            navigateToSceneInActivePane(node.id)
        case .chapter:
            guard chapterExists(node.id) else { return }
            navigationState.navigateTo(chapterId: node.id)
        case .part, .manuscript:
            break
        }
    }

    func select(breadcrumb: BreadcrumbItem) {
        guard hasOpenProject else { return }
        switch breadcrumb.type {
        case .scene:
            guard sceneExists(breadcrumb.id) else { return }
            navigateToSceneInActivePane(breadcrumb.id)
        case .chapter:
            guard chapterExists(breadcrumb.id) else { return }
            navigationState.navigateTo(chapterId: breadcrumb.id)
        case .part, .manuscript:
            break
        }
    }

    func openSplitFromCurrentContext(windowWidth: CGFloat, preferredOrientation: SplitOrientation = .vertical) -> String? {
        guard projectManager.currentProject != nil else {
            return nil
        }
        guard modeController.activeMode == .linear else { return nil }
        guard let targetSceneId = resolveSceneForSplitOpen() else {
            return nil
        }

        let applied = splitEditorState.openSplit(
            sceneId: targetSceneId,
            preferredOrientation: preferredOrientation,
            windowWidth: windowWidth
        )
        splitEditorState.setActivePane(1)

        if preferredOrientation == .vertical, applied == .horizontal {
            return "Window too narrow for side-by-side split. Using stacked layout."
        }
        return nil
    }

    func toggleSplit(windowWidth: CGFloat, preferredOrientation: SplitOrientation = .vertical) -> String? {
        guard projectManager.currentProject != nil else {
            return ProjectIOError.noOpenProject.localizedDescription
        }
        if splitEditorState.isSplit {
            splitEditorState.closeSplit()
            return nil
        }
        return openSplitFromCurrentContext(windowWidth: windowWidth, preferredOrientation: preferredOrientation)
    }

    func handleModeChange(_ mode: ViewMode) {
        if mode == .modular, splitEditorState.isSplit {
            splitEditorState.closeSplit()
        }
    }

    func setMode(_ mode: ViewMode) {
        guard hasOpenProject else {
            return
        }
        modeController.switchTo(mode)
        handleModeChange(mode)
    }

    @discardableResult
    func createAndOpenProject(named rawName: String) -> String? {
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not create project: Project name cannot be empty."
        }

        do {
            if hasOpenProject {
                autosaveOpenEditors()
                try projectManager.saveManifest()
            }
            let rootURL = try projectRootForNewProjects()
            _ = try projectManager.createProject(name: name, at: rootURL)
            didOpenProject()
            return nil
        } catch {
            return "Could not create project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func openProject(at projectURL: URL) -> String? {
        do {
            if hasOpenProject {
                autosaveOpenEditors()
                try projectManager.saveManifest()
            }
            _ = try projectManager.openProject(at: projectURL)
            didOpenProject()
            return nil
        } catch {
            return "Could not open project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func reopenLastProject() -> String? {
        guard let projectURL = lastOpenedProjectURL() else {
            return "Could not reopen project: No recent project found."
        }
        return openProject(at: projectURL)
    }

    func clearRecentProjects() {
        recentProjectStore.removeObject(forKey: Self.recentProjectsKey)
        recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
    }

    func snapshotRecentProjects() -> RecentProjectsSnapshot {
        RecentProjectsSnapshot(
            paths: recentProjectPaths(),
            lastOpenedPath: recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey)
        )
    }

    func restoreRecentProjects(from snapshot: RecentProjectsSnapshot) {
        recentProjectStore.set(snapshot.paths, forKey: Self.recentProjectsKey)
        if let lastOpenedPath = snapshot.lastOpenedPath {
            recentProjectStore.set(lastOpenedPath, forKey: Self.lastOpenedProjectPathKey)
        } else {
            recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
        }
    }

    func cleanupMissingRecentProjects() {
        let cleaned = recentProjectPaths().filter { path in
            let url = URL(fileURLWithPath: path, isDirectory: true)
            return FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path)
        }
        recentProjectStore.set(cleaned, forKey: Self.recentProjectsKey)

        if let last = recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey), !cleaned.contains(last) {
            recentProjectStore.removeObject(forKey: Self.lastOpenedProjectPathKey)
        }
    }

    func showInlineSearchPanel() {
        guard hasOpenProject else { return }
        isSearchPanelVisible = true
        searchScope = .currentScene
        runSearch()
    }

    func showProjectSearchPanel() {
        guard hasOpenProject else { return }
        isSearchPanelVisible = true
        searchScope = .entireProject
        runSearch()
    }

    func hideSearchPanel() {
        isSearchPanelVisible = false
    }

    func runSearch() {
        guard hasOpenProject else {
            searchResults = []
            searchErrorMessage = nil
            return
        }
        let query = makeSearchQuery()
        searchResults = searchEngine.search(query: query)
        searchErrorMessage = searchEngine.lastErrorMessage
    }

    @discardableResult
    func replaceAllSearchResults() -> String? {
        guard hasOpenProject else {
            return "Could not replace: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        guard !searchQueryText.isEmpty else {
            return "Could not replace: Search text cannot be empty."
        }
        do {
            let report = try searchEngine.replaceAll(query: makeSearchQuery(), replacement: searchReplacementText)
            refreshDerivedStates()
            reloadOpenEditorScenes()
            runSearch()
            return "Replaced \(report.replacementCount) matches across \(report.scenesAffected) scenes."
        } catch {
            return "Could not replace: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveProjectAs(named rawName: String) -> String? {
        guard hasOpenProject else {
            return "Could not save project as: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not save project as: Project name cannot be empty."
        }

        let sourceURL = projectManager.projectRootURL!
        let destinationURL: URL
        do {
            destinationURL = try destinationProjectURL(forName: name)
        } catch {
            return "Could not save project as: \(error.localizedDescription)"
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return "Could not save project as: A project named \"\(name)\" already exists."
        }

        var copied = false
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
            copied = true
            let copiedLock = destinationURL.appendingPathComponent(".lock")
            if FileManager.default.fileExists(atPath: copiedLock.path) {
                try? FileManager.default.removeItem(at: copiedLock)
            }
            _ = try projectManager.openProject(at: destinationURL)
            try projectManager.updateProjectName(name)
            try projectManager.saveManifest()
            didOpenProject()
            return nil
        } catch {
            if copied {
                try? FileManager.default.removeItem(at: destinationURL)
                if projectManager.currentProject == nil {
                    _ = try? projectManager.openProject(at: sourceURL)
                    didOpenProject()
                }
            }
            return "Could not save project as: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func renameCurrentProject(to rawName: String) -> String? {
        guard hasOpenProject else {
            return "Could not rename project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let name = normalizeTitle(rawName, fallback: "")
        guard !name.isEmpty else {
            return "Could not rename project: Project name cannot be empty."
        }

        let sourceURL = projectManager.projectRootURL!
        if sourceURL.lastPathComponent == name {
            return nil
        }

        let destinationURL: URL
        do {
            destinationURL = try destinationProjectURL(forName: name)
        } catch {
            return "Could not rename project: \(error.localizedDescription)"
        }
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            return "Could not rename project: A project named \"\(name)\" already exists."
        }

        var closed = false
        var moved = false
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try projectManager.closeProject()
            closed = true
            try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
            moved = true
            _ = try projectManager.openProject(at: destinationURL)
            try projectManager.updateProjectName(name)
            try projectManager.saveManifest()
            didOpenProject()
            return nil
        } catch {
            if moved {
                _ = try? projectManager.openProject(at: destinationURL)
                didOpenProject()
            } else if closed {
                _ = try? projectManager.openProject(at: sourceURL)
                didOpenProject()
            }
            return "Could not rename project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createChapter(title: String? = nil) -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create chapter: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let resolvedTitle: String
        if let title {
            let normalized = normalizeTitle(title, fallback: "")
            if !normalized.isEmpty {
                resolvedTitle = normalized
            } else {
                resolvedTitle = nextGeneratedChapterTitle()
            }
        } else {
            resolvedTitle = nextGeneratedChapterTitle()
        }

        do {
            let chapter = try projectManager.addChapter(to: nil, at: nil, title: resolvedTitle)
            refreshDerivedStates()
            navigationState.navigateTo(chapterId: chapter.id)
            return nil
        } catch {
            return "Could not create chapter: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createScene(title: String? = nil) -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create scene: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let resolvedTitle: String
        if let title {
            let normalized = normalizeTitle(title, fallback: "")
            if !normalized.isEmpty {
                resolvedTitle = normalized
            } else {
                resolvedTitle = nextGeneratedSceneTitle()
            }
        } else {
            resolvedTitle = nextGeneratedSceneTitle()
        }
        do {
            let chapterId = try resolveChapterForSceneCreation()
            let scene = try projectManager.addScene(to: chapterId, at: nil, title: resolvedTitle)
            refreshDerivedStates()
            navigateToSceneInActivePane(scene.id)
            return nil
        } catch {
            return "Could not create scene: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func toggleSplitForCommand(defaultWindowWidth: CGFloat = 1200) -> String? {
        toggleSplit(windowWidth: defaultWindowWidth)
    }

    @discardableResult
    func navigateToNextScene() -> Bool {
        guard projectManager.currentProject != nil, modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToNextScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func navigateToPreviousScene() -> Bool {
        guard projectManager.currentProject != nil, modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToPreviousScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func saveProjectNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not save project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            return nil
        } catch {
            return "Could not save project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createBackupNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not create backup: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        let beforeCount = projectManager.listBackups().count
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            try projectManager.createBackup()
            let backups = projectManager.listBackups()
            if let latest = backups.first, backups.count >= beforeCount {
                return "Backup created: \(latest.filename)"
            }
            return "Backup created."
        } catch {
            return "Could not create backup: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func saveAndBackupNow() -> String? {
        guard projectManager.currentProject != nil else {
            return "Could not save and back up project: \(ProjectIOError.noOpenProject.localizedDescription)"
        }
        do {
            autosaveOpenEditors()
            try projectManager.saveManifest()
            let beforeCount = projectManager.listBackups().count
            try projectManager.createBackup()
            let backups = projectManager.listBackups()
            if let latest = backups.first, backups.count >= beforeCount {
                return "Project saved and backup created: \(latest.filename)"
            }
            return "Project saved and backup created."
        } catch {
            return "Could not save and back up project: \(error.localizedDescription)"
        }
    }

    func handleScenePhase(_ phase: ScenePhase) {
        guard hasOpenProject else {
            goalsManager.handleAppFocusChanged(isFocused: false)
            return
        }
        switch phase {
        case .active:
            if goalsManager.sessionStartTime == nil {
                goalsManager.startSession(goal: nil)
            }
            goalsManager.handleAppFocusChanged(isFocused: true)
        case .inactive:
            goalsManager.handleAppFocusChanged(isFocused: false)
            autosaveOpenEditors()
        case .background:
            goalsManager.handleAppFocusChanged(isFocused: false)
            autosaveOpenEditors()
            try? projectManager.saveManifest()
        @unknown default:
            break
        }
    }

    private static func bootstrapProject(
        using manager: FileSystemProjectManager,
        rootURL: URL?,
        projectName: String,
        recentProjectStore: UserDefaults
    ) throws {
        let fm = FileManager.default
        if rootURL == nil {
            let storedRecent = recentProjectStore.array(forKey: recentProjectsKey) as? [String] ?? []
            for path in storedRecent {
                let url = URL(fileURLWithPath: path, isDirectory: true)
                if fm.fileExists(atPath: url.appendingPathComponent("manifest.json").path) {
                    _ = try manager.openProject(at: url)
                    return
                }
            }

            if let lastPath = recentProjectStore.string(forKey: lastOpenedProjectPathKey) {
                let lastURL = URL(fileURLWithPath: lastPath, isDirectory: true)
                if fm.fileExists(atPath: lastURL.appendingPathComponent("manifest.json").path) {
                    _ = try manager.openProject(at: lastURL)
                    return
                }
                recentProjectStore.removeObject(forKey: lastOpenedProjectPathKey)
            }
        }

        let root: URL
        if let rootURL {
            root = rootURL
        } else {
            let appSupport = try fm.url(
                for: .applicationSupportDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            root = appSupport.appendingPathComponent("Manuscript", isDirectory: true)
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let projectRoot = root.appendingPathComponent(projectName, isDirectory: true)
        if fm.fileExists(atPath: projectRoot.appendingPathComponent("manifest.json").path) {
            _ = try manager.openProject(at: projectRoot)
        } else {
            _ = try manager.createProject(name: projectName, at: root)
        }
    }

    private static func defaultProjectContainerURL(fileManager: FileManager = .default) throws -> URL {
        let appSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return appSupport.appendingPathComponent("Manuscript", isDirectory: true)
    }

    private static func makeDependencies(
        manager: FileSystemProjectManager,
        splitSettingsStore: UserDefaults,
        splitSettingsNamespace: String
    ) -> (
        navigationState: NavigationState,
        editorState: EditorState,
        linearState: LinearModeState,
        modularState: ModularModeState,
        modeController: ModeController,
        splitEditorState: SplitEditorState,
        goalsManager: GoalsManager
    ) {
        let navigationState = NavigationState(projectProvider: { manager.currentProject })
        let editorState = EditorState(sceneLoader: { id in
            (try? manager.loadSceneContent(sceneId: id)) ?? ""
        })
        let linearState = LinearModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
        let modularState = ModularModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
        let modeController = ModeController(
            projectManager: manager,
            navigationState: navigationState,
            editorState: editorState,
            linearState: linearState,
            modularState: modularState
        )
        let splitEditorState = SplitEditorState(
            projectManager: manager,
            primarySceneId: editorState.currentSceneId,
            settingsStore: splitSettingsStore,
            settingsNamespace: splitSettingsNamespace
        )
        let goalsManager = GoalsManager(projectManager: manager)
        return (navigationState, editorState, linearState, modularState, modeController, splitEditorState, goalsManager)
    }

    private static func splitSettingsNamespace(for manager: FileSystemProjectManager) -> String {
        guard let root = manager.projectRootURL else { return "splitEditor.default" }
        let sanitized = root.path.unicodeScalars
            .map { CharacterSet.alphanumerics.contains($0) ? Character($0) : "_" }
        return "splitEditor.\(String(sanitized))"
    }

    private func autosaveOpenEditors() {
        try? editorState.autosaveIfNeeded(projectManager: projectManager)
        splitEditorState.autosaveOpenPanes()
    }

    private func didOpenProject() {
        refreshDerivedStates()
        modeController.switchTo(.linear)
        splitEditorState.closeSplit()

        if let first = linearState.orderedSceneIds.first {
            editorState.navigateToScene(id: first)
            navigationState.navigateTo(sceneId: first)
            splitEditorState.primarySceneId = first
            splitEditorState.secondarySceneId = nil
        } else {
            navigationState.selectedSceneId = nil
            navigationState.selectedChapterId = nil
            navigationState.breadcrumb = []
        }

        persistLastOpenedProject()
        startSearchIndexing()
    }

    private func projectRootForNewProjects() throws -> URL {
        if let currentRoot = projectManager.projectRootURL {
            return currentRoot.deletingLastPathComponent()
        }
        return try Self.defaultProjectContainerURL(fileManager: .default)
    }

    private func destinationProjectURL(forName name: String) throws -> URL {
        let root = try projectRootForNewProjects()
        return root.appendingPathComponent(name, isDirectory: true)
    }

    private func persistLastOpenedProject() {
        guard let rootURL = projectManager.projectRootURL else { return }
        recentProjectStore.set(rootURL.path, forKey: Self.lastOpenedProjectPathKey)
        var stored = recentProjectStore.array(forKey: Self.recentProjectsKey) as? [String] ?? []
        stored.removeAll { $0 == rootURL.path }
        stored.insert(rootURL.path, at: 0)
        if stored.count > Self.maxRecentProjects {
            stored.removeLast(stored.count - Self.maxRecentProjects)
        }
        recentProjectStore.set(stored, forKey: Self.recentProjectsKey)
    }

    private func lastOpenedProjectURL() -> URL? {
        guard let path = recentProjectStore.string(forKey: Self.lastOpenedProjectPathKey) else {
            return nil
        }
        let url = URL(fileURLWithPath: path, isDirectory: true)
        guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
            return nil
        }
        return url
    }

    private func recentProjectURLs() -> [URL] {
        let stored = recentProjectPaths()
        var seen = Set<String>()
        var urls: [URL] = []
        for path in stored {
            guard !seen.contains(path) else { continue }
            let url = URL(fileURLWithPath: path, isDirectory: true)
            guard FileManager.default.fileExists(atPath: url.appendingPathComponent("manifest.json").path) else {
                continue
            }
            urls.append(url)
            seen.insert(path)
        }
        return urls
    }

    private var currentProjectEntry: RecentProjectEntry? {
        guard let root = projectManager.projectRootURL else { return nil }
        return RecentProjectEntry(id: root.path, name: projectDisplayName, url: root)
    }

    private func recentProjectPaths() -> [String] {
        recentProjectStore.array(forKey: Self.recentProjectsKey) as? [String] ?? []
    }

    private func makeSearchEngine() -> IndexedSearchEngine {
        IndexedSearchEngine(
            projectManager: projectManager,
            currentSceneProvider: { [weak self] in
                self?.editorState.currentSceneId
            },
            currentChapterProvider: { [weak self] in
                self?.navigationState.selectedChapterId
            },
            unsavedSceneProvider: { [weak self] in
                guard let self, let sceneId = self.editorState.currentSceneId else { return nil }
                return (sceneId, self.editorState.getCurrentContent())
            }
        )
    }

    private func makeSearchQuery() -> SearchQuery {
        SearchQuery(
            text: searchQueryText,
            isRegex: searchIsRegex,
            isCaseSensitive: searchIsCaseSensitive,
            isWholeWord: searchIsWholeWord,
            scope: searchScope.searchScope
        )
    }

    private func startSearchIndexing() {
        Task { @MainActor [weak self] in
            guard let self, let project = self.projectManager.currentProject else { return }
            await self.searchEngine.buildIndex(for: project)
        }
    }

    private func refreshDerivedStates() {
        linearState.reloadSequence()
        modularState.reload()
    }

    private func reloadOpenEditorScenes() {
        if let primary = splitEditorState.primarySceneId {
            splitEditorState.primaryEditor.navigateToScene(id: primary)
            editorState.navigateToScene(id: primary)
            navigationState.navigateTo(sceneId: primary)
        }
        if splitEditorState.isSplit, let secondary = splitEditorState.secondarySceneId {
            splitEditorState.secondaryEditor.navigateToScene(id: secondary)
        }
    }

    private func resolveChapterForSceneCreation() throws -> UUID {
        guard projectManager.currentProject != nil else {
            throw ProjectIOError.noOpenProject
        }
        let manifest = projectManager.getManifest()
        let validChapterIds = Set(manifest.hierarchy.chapters.map(\.id))
        if let selected = navigationState.selectedChapterId,
           validChapterIds.contains(selected) {
            return selected
        }

        if let selectedScene = navigationState.selectedSceneId,
           let parent = manifest.hierarchy.scenes.first(where: { $0.id == selectedScene })?.parentChapterId,
           validChapterIds.contains(parent) {
            return parent
        }

        if let currentScene = editorState.currentSceneId,
           let parent = manifest.hierarchy.scenes.first(where: { $0.id == currentScene })?.parentChapterId,
           validChapterIds.contains(parent) {
            return parent
        }

        if let firstChapter = manifest.hierarchy.chapters.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }).first {
            return firstChapter.id
        }

        let newChapter = try projectManager.addChapter(to: nil, at: nil, title: nextGeneratedChapterTitle())
        return newChapter.id
    }

    private func resolveSceneForSplitOpen() -> UUID? {
        guard projectManager.currentProject != nil else {
            return nil
        }
        let validSceneIds = Set(projectManager.getManifest().hierarchy.scenes.map(\.id))
        let candidates: [UUID?] = [
            navigationState.selectedSceneId,
            editorState.currentSceneId,
            linearState.orderedSceneIds.first
        ]
        for candidate in candidates {
            if let candidate, validSceneIds.contains(candidate) {
                return candidate
            }
        }
        return nil
    }

    private func sceneExists(_ id: UUID) -> Bool {
        projectManager.getManifest().hierarchy.scenes.contains(where: { $0.id == id })
    }

    private func navigateToSceneInActivePane(_ sceneId: UUID) {
        navigationState.navigateTo(sceneId: sceneId)
        editorState.navigateToScene(id: sceneId)
        if splitEditorState.activePaneIndex == 1, splitEditorState.isSplit {
            splitEditorState.secondarySceneId = sceneId
            splitEditorState.secondaryEditor.navigateToScene(id: sceneId)
        } else {
            splitEditorState.primarySceneId = sceneId
            splitEditorState.primaryEditor.navigateToScene(id: sceneId)
        }
    }

    private func chapterExists(_ id: UUID) -> Bool {
        projectManager.getManifest().hierarchy.chapters.contains(where: { $0.id == id })
    }

    private func normalizeTitle(_ value: String, fallback: String) -> String {
        let collapsed = value
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func nextGeneratedChapterTitle() -> String {
        nextGeneratedTitle(
            existingTitles: projectManager.getManifest().hierarchy.chapters.map(\.title),
            parsePrefix: "chapter",
            displayPrefix: "Chapter"
        )
    }

    private func nextGeneratedSceneTitle() -> String {
        nextGeneratedTitle(
            existingTitles: projectManager.getManifest().hierarchy.scenes.map(\.title),
            parsePrefix: "scene",
            displayPrefix: "Scene"
        )
    }

    private func nextGeneratedTitle(existingTitles: [String], parsePrefix: String, displayPrefix: String) -> String {
        let usedNumbers = Set(
            existingTitles.compactMap { title -> Int? in
                parseGeneratedNumber(from: title, prefix: parsePrefix)
            }
        )

        var candidate = 1
        while usedNumbers.contains(candidate) {
            candidate += 1
        }
        return "\(displayPrefix) \(candidate)"
    }

    private func parseGeneratedNumber(from title: String, prefix: String) -> Int? {
        let normalized = title
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = normalized.lowercased()
        guard lowercased.hasPrefix(prefix) else {
            return nil
        }
        let suffix = normalized.dropFirst(prefix.count).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !suffix.isEmpty, suffix.unicodeScalars.allSatisfy(CharacterSet.decimalDigits.contains) else {
            return nil
        }
        return Int(suffix)
    }
}
