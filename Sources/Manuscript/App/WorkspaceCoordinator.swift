import Foundation
import SwiftUI

@MainActor
final class WorkspaceCoordinator: ObservableObject {
    let projectManager: FileSystemProjectManager
    let navigationState: NavigationState
    let editorState: EditorState
    let linearState: LinearModeState
    let modularState: ModularModeState
    let modeController: ModeController
    let splitEditorState: SplitEditorState
    let goalsManager: GoalsManager

    @Published var loadError: String?

    var projectDisplayName: String {
        projectManager.currentProject?.name ?? "Scribbles N Scripts"
    }

    init(
        projectManager manager: FileSystemProjectManager = FileSystemProjectManager(),
        bootstrapRootURL: URL? = nil,
        bootstrapProjectName: String = "Sandbox",
        splitSettingsStore: UserDefaults = .standard
    ) {
        self.projectManager = manager

        do {
            try Self.bootstrapProject(
                using: manager,
                rootURL: bootstrapRootURL,
                projectName: bootstrapProjectName
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

            if dependencies.editorState.currentSceneId == nil, let first = dependencies.linearState.orderedSceneIds.first {
                dependencies.linearState.goToScene(id: first)
                dependencies.splitEditorState.primarySceneId = first
            }
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
        switch node.level {
        case .scene:
            navigationState.navigateTo(sceneId: node.id)
            editorState.navigateToScene(id: node.id)
            if splitEditorState.activePaneIndex == 1, splitEditorState.isSplit {
                splitEditorState.secondarySceneId = node.id
                splitEditorState.secondaryEditor.navigateToScene(id: node.id)
            } else {
                splitEditorState.primarySceneId = node.id
                splitEditorState.primaryEditor.navigateToScene(id: node.id)
            }
        case .chapter:
            navigationState.navigateTo(chapterId: node.id)
        case .part, .manuscript:
            break
        }
    }

    func select(breadcrumb: BreadcrumbItem) {
        switch breadcrumb.type {
        case .scene:
            navigationState.navigateTo(sceneId: breadcrumb.id)
            editorState.navigateToScene(id: breadcrumb.id)
            if splitEditorState.activePaneIndex == 1, splitEditorState.isSplit {
                splitEditorState.secondarySceneId = breadcrumb.id
                splitEditorState.secondaryEditor.navigateToScene(id: breadcrumb.id)
            } else {
                splitEditorState.primarySceneId = breadcrumb.id
                splitEditorState.primaryEditor.navigateToScene(id: breadcrumb.id)
            }
        case .chapter:
            navigationState.navigateTo(chapterId: breadcrumb.id)
        case .part, .manuscript:
            break
        }
    }

    func openSplitFromCurrentContext(windowWidth: CGFloat, preferredOrientation: SplitOrientation = .vertical) -> String? {
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
        modeController.switchTo(mode)
        handleModeChange(mode)
    }

    @discardableResult
    func createChapter(title: String? = nil) -> String? {
        let base = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle: String
        if let base, !base.isEmpty {
            resolvedTitle = base
        } else {
            let chapterCount = projectManager.getManifest().hierarchy.chapters.count
            resolvedTitle = "Chapter \(chapterCount + 1)"
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
    func createScene(title: String = "Untitled Scene") -> String? {
        do {
            let chapterId = try resolveChapterForSceneCreation()
            let scene = try projectManager.addScene(to: chapterId, at: nil, title: title)
            refreshDerivedStates()
            navigationState.navigateTo(sceneId: scene.id)
            editorState.navigateToScene(id: scene.id)
            if splitEditorState.isSplit, splitEditorState.activePaneIndex == 1 {
                splitEditorState.secondarySceneId = scene.id
                splitEditorState.secondaryEditor.navigateToScene(id: scene.id)
            } else {
                splitEditorState.primarySceneId = scene.id
                splitEditorState.primaryEditor.navigateToScene(id: scene.id)
            }
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
        guard modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToNextScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func navigateToPreviousScene() -> Bool {
        guard modeController.activeMode == .linear else { return false }
        let before = editorState.currentSceneId
        linearState.goToPreviousScene()
        return editorState.currentSceneId != before
    }

    @discardableResult
    func saveProjectNow() -> String? {
        do {
            try projectManager.saveManifest()
            return nil
        } catch {
            return "Could not save project: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func createBackupNow() -> String? {
        let beforeCount = projectManager.listBackups().count
        do {
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

    func handleScenePhase(_ phase: ScenePhase) {
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

    private static func bootstrapProject(using manager: FileSystemProjectManager, rootURL: URL?, projectName: String) throws {
        let fm = FileManager.default
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

    private func refreshDerivedStates() {
        linearState.reloadSequence()
        modularState.reload()
    }

    private func resolveChapterForSceneCreation() throws -> UUID {
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

        let newChapter = try projectManager.addChapter(to: nil, at: nil, title: "Chapter 1")
        return newChapter.id
    }

    private func resolveSceneForSplitOpen() -> UUID? {
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
}
