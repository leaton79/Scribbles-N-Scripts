import Foundation
import SwiftUI

@MainActor
struct WorkspaceCommandBindings {
    let workspace: WorkspaceCoordinator

    var canSaveProject: Bool {
        workspace.hasOpenProject && workspace.canSaveProject
    }

    var canCreateProjectContent: Bool {
        workspace.hasOpenProject
    }

    var canCreateBackup: Bool {
        workspace.hasOpenProject
    }

    var canSaveAndBackup: Bool {
        workspace.hasOpenProject
    }

    var canSwitchToLinearMode: Bool {
        workspace.canSwitchToLinearMode
    }

    var canSwitchToModularMode: Bool {
        workspace.canSwitchToModularMode
    }

    var canToggleSplitEditor: Bool {
        workspace.canToggleSplitEditor
    }

    var canNavigateToPreviousScene: Bool {
        workspace.canNavigateToPreviousScene
    }

    var canNavigateToNextScene: Bool {
        workspace.canNavigateToNextScene
    }

    var splitToggleTitle: String {
        workspace.splitEditorState.isSplit ? "Close Split" : "Toggle Split"
    }

    @discardableResult
    func saveProject() -> String? {
        workspace.saveProjectNow()
    }

    @discardableResult
    func createChapter() -> String? {
        workspace.createChapter()
    }

    @discardableResult
    func createScene() -> String? {
        workspace.createScene()
    }

    @discardableResult
    func createBackup() -> String? {
        workspace.createBackupNow()
    }

    @discardableResult
    func saveAndBackup() -> String? {
        workspace.saveAndBackupNow()
    }

    func setModeLinear() {
        workspace.setMode(.linear)
    }

    func setModeModular() {
        workspace.setMode(.modular)
    }

    @discardableResult
    func toggleSplit(defaultWindowWidth: CGFloat = 1200) -> String? {
        workspace.toggleSplitForCommand(defaultWindowWidth: defaultWindowWidth)
    }

    @discardableResult
    func navigateToPreviousScene() -> Bool {
        workspace.navigateToPreviousScene()
    }

    @discardableResult
    func navigateToNextScene() -> Bool {
        workspace.navigateToNextScene()
    }
}
