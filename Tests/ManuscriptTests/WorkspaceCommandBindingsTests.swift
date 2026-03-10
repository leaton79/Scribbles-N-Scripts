import XCTest
@testable import Manuscript

@MainActor
final class WorkspaceCommandBindingsTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testAvailabilityTracksWorkspaceState() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsAvailability")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertTrue(bindings.canCreateProjectContent)
        XCTAssertTrue(bindings.canCreateBackup)
        XCTAssertTrue(bindings.canSaveAndBackup)
        XCTAssertFalse(bindings.canSaveProject)
        XCTAssertFalse(bindings.canNavigateToPreviousScene)
        XCTAssertFalse(bindings.canNavigateToNextScene)
        XCTAssertEqual(bindings.splitToggleTitle, "Toggle Split")

        workspace.editorState.insertText("dirty", at: 0)
        XCTAssertTrue(bindings.canSaveProject)

        try workspace.projectManager.closeProject()
        XCTAssertFalse(bindings.canCreateProjectContent)
        XCTAssertFalse(bindings.canCreateBackup)
        XCTAssertFalse(bindings.canSaveAndBackup)
        XCTAssertFalse(bindings.canSaveProject)
        XCTAssertFalse(bindings.canSwitchToLinearMode)
        XCTAssertFalse(bindings.canSwitchToModularMode)
        XCTAssertFalse(bindings.canToggleSplitEditor)
    }

    func testProjectActionsDelegateToWorkspaceCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsProjectActions")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertNil(bindings.createChapter())
        XCTAssertNil(bindings.createScene())
        XCTAssertNil(bindings.saveProject())

        let backupMessage = bindings.createBackup()
        XCTAssertNotNil(backupMessage)
        XCTAssertTrue(backupMessage?.contains("Backup created") == true)

        let saveAndBackupMessage = bindings.saveAndBackup()
        XCTAssertNotNil(saveAndBackupMessage)
        XCTAssertTrue(saveAndBackupMessage?.contains("Project saved and backup created") == true)
    }

    func testViewActionsDelegateToWorkspaceCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsViewActions")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        let chapterId = try XCTUnwrap(workspace.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try workspace.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        workspace.linearState.reloadSequence()
        let firstSceneId = try XCTUnwrap(workspace.linearState.orderedSceneIds.first)
        workspace.editorState.navigateToScene(id: firstSceneId)

        XCTAssertTrue(bindings.navigateToNextScene())
        XCTAssertTrue(bindings.navigateToPreviousScene())

        XCTAssertNil(bindings.toggleSplit())
        XCTAssertEqual(bindings.splitToggleTitle, "Close Split")

        bindings.setModeModular()
        XCTAssertEqual(workspace.modeController.activeMode, .modular)
        bindings.setModeLinear()
        XCTAssertEqual(workspace.modeController.activeMode, .linear)
    }

    func testSplitToggleTitleAndAvailabilityCycle() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsSplitCycle")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertEqual(bindings.splitToggleTitle, "Toggle Split")
        XCTAssertTrue(bindings.canToggleSplitEditor)

        XCTAssertNil(bindings.toggleSplit())
        XCTAssertTrue(workspace.splitEditorState.isSplit)
        XCTAssertEqual(bindings.splitToggleTitle, "Close Split")
        XCTAssertTrue(bindings.canToggleSplitEditor)

        XCTAssertNil(bindings.toggleSplit())
        XCTAssertFalse(workspace.splitEditorState.isSplit)
        XCTAssertEqual(bindings.splitToggleTitle, "Toggle Split")
        XCTAssertTrue(bindings.canToggleSplitEditor)
    }

    func testNoProjectDelegatedActionsReturnExpectedMessages() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsNoProject")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        try workspace.projectManager.closeProject()

        XCTAssertEqual(bindings.saveProject(), "Could not save project: No project is currently open.")
        XCTAssertEqual(bindings.createChapter(), "Could not create chapter: No project is currently open.")
        XCTAssertEqual(bindings.createScene(), "Could not create scene: No project is currently open.")
        XCTAssertEqual(bindings.createBackup(), "Could not create backup: No project is currently open.")
        XCTAssertEqual(bindings.saveAndBackup(), "Could not save and back up project: No project is currently open.")
        XCTAssertEqual(bindings.toggleSplit(), "No project is currently open.")
        XCTAssertFalse(bindings.navigateToPreviousScene())
        XCTAssertFalse(bindings.navigateToNextScene())
    }

    func testNoProjectModeSwitchCommandsAreSafeNoOps() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsNoProjectModeSwitch")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        try workspace.projectManager.closeProject()

        XCTAssertEqual(workspace.modeController.activeMode, .linear)
        XCTAssertFalse(bindings.canSwitchToLinearMode)
        XCTAssertFalse(bindings.canSwitchToModularMode)

        bindings.setModeModular()
        XCTAssertEqual(workspace.modeController.activeMode, .linear)
        bindings.setModeLinear()
        XCTAssertEqual(workspace.modeController.activeMode, .linear)
    }

    func testNoProjectSplitToggleIsNoOpWhenSplitAlreadyOpen() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsNoProjectOpenSplit")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertNil(bindings.toggleSplit())
        XCTAssertTrue(workspace.splitEditorState.isSplit)
        XCTAssertEqual(bindings.splitToggleTitle, "Close Split")

        try workspace.projectManager.closeProject()
        XCTAssertFalse(bindings.canToggleSplitEditor)
        XCTAssertEqual(bindings.toggleSplit(), "No project is currently open.")
        XCTAssertTrue(workspace.splitEditorState.isSplit)
        XCTAssertEqual(bindings.splitToggleTitle, "Close Split")
    }
}
