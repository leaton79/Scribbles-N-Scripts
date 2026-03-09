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

    init() {
        let manager = FileSystemProjectManager()
        self.projectManager = manager

        do {
            try Self.bootstrapProject(using: manager)
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

            self.navigationState = navigationState
            self.editorState = editorState
            self.linearState = linearState
            self.modularState = modularState
            self.modeController = modeController
            self.splitEditorState = splitEditorState
            self.goalsManager = goalsManager

            if editorState.currentSceneId == nil, let first = linearState.orderedSceneIds.first {
                linearState.goToScene(id: first)
                splitEditorState.primarySceneId = first
            }
        } catch {
            self.loadError = error.localizedDescription
            self.navigationState = NavigationState()
            self.editorState = EditorState()
            self.linearState = LinearModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
            self.modularState = ModularModeState(projectManager: manager, navigationState: navigationState, editorState: editorState)
            self.modeController = ModeController(
                projectManager: manager,
                navigationState: navigationState,
                editorState: editorState,
                linearState: linearState,
                modularState: modularState
            )
            self.splitEditorState = SplitEditorState(projectManager: manager)
            self.goalsManager = GoalsManager(projectManager: manager)
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

    private static func bootstrapProject(using manager: FileSystemProjectManager) throws {
        let fm = FileManager.default
        let appSupport = try fm.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let root = appSupport.appendingPathComponent("Manuscript", isDirectory: true)
        try fm.createDirectory(at: root, withIntermediateDirectories: true)

        let defaultProjectName = "Sandbox"
        let projectRoot = root.appendingPathComponent(defaultProjectName, isDirectory: true)
        if fm.fileExists(atPath: projectRoot.appendingPathComponent("manifest.json").path) {
            _ = try manager.openProject(at: projectRoot)
        } else {
            _ = try manager.createProject(name: defaultProjectName, at: root)
        }
    }

    private func autosaveOpenEditors() {
        try? editorState.autosaveIfNeeded(projectManager: projectManager)
        splitEditorState.autosaveOpenPanes()
    }
}
