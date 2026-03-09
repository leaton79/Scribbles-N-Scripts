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

    init(
        projectManager manager: FileSystemProjectManager = FileSystemProjectManager(),
        bootstrapRootURL: URL? = nil,
        bootstrapProjectName: String = "Sandbox"
    ) {
        self.projectManager = manager

        do {
            try Self.bootstrapProject(
                using: manager,
                rootURL: bootstrapRootURL,
                projectName: bootstrapProjectName
            )
            let dependencies = Self.makeDependencies(manager: manager)
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
            let dependencies = Self.makeDependencies(manager: manager)
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

    func handleModeChange(_ mode: ViewMode) {
        if mode == .modular, splitEditorState.isSplit {
            splitEditorState.closeSplit()
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

    private static func makeDependencies(manager: FileSystemProjectManager) -> (
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
        let splitEditorState = SplitEditorState(projectManager: manager, primarySceneId: editorState.currentSceneId)
        let goalsManager = GoalsManager(projectManager: manager)
        return (navigationState, editorState, linearState, modularState, modeController, splitEditorState, goalsManager)
    }

    private func autosaveOpenEditors() {
        try? editorState.autosaveIfNeeded(projectManager: projectManager)
        splitEditorState.autosaveOpenPanes()
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
