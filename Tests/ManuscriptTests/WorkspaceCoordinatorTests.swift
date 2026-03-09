import SwiftUI
import XCTest
@testable import Manuscript

@MainActor
final class WorkspaceCoordinatorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testHandleScenePhaseActiveStartsSessionAndTimer() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Lifecycle")

        coordinator.handleScenePhase(.active)

        XCTAssertNotNil(coordinator.goalsManager.sessionStartTime)
        XCTAssertTrue(coordinator.goalsManager.isTimerRunning)
    }

    func testHandleScenePhaseInactiveAutosavesDirtyEditor() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "Autosave")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("Hello ", at: 0)

        coordinator.handleScenePhase(.inactive)

        let content = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(content, "Hello ")
        XCTAssertFalse(coordinator.goalsManager.isTimerRunning)
    }

    func testSidebarSelectionTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitSelect")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId

        coordinator.select(
            node: SidebarNode(
                id: existingSceneId,
                title: "First",
                level: .scene,
                wordCount: 0,
                colorLabel: nil,
                goalProgressText: nil,
                children: [],
                matchingCount: nil
            )
        )

        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testBackgroundPhasePersistsDirtyManifestToDisk() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackgroundSave")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let beforeCount = coordinator.projectManager.getManifest().hierarchy.scenes.count

        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Unsaved Scene")
        coordinator.handleScenePhase(.background)

        let root = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let diskManifest = try ManifestCoder.read(from: root.appendingPathComponent("manifest.json"))
        XCTAssertEqual(diskManifest.hierarchy.scenes.count, beforeCount + 1)
    }

    func testBootstrapReopensExistingProjectData() throws {
        let projectName = "Reopen"
        var first: WorkspaceCoordinator? = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: projectName)
        let chapterId = try XCTUnwrap(first?.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try first?.projectManager.addScene(to: chapterId, at: nil, title: "Persisted Scene")
        try first?.projectManager.saveManifest()
        try first?.projectManager.closeProject()
        first = nil

        let second = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: projectName)
        let titles = second.projectManager.getManifest().hierarchy.scenes.map(\.title)
        XCTAssertTrue(titles.contains("Persisted Scene"))
    }

    func testLiveTypingUpdatesSessionWordStatsThroughCoordinatorBinding() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "LiveGoals")
        coordinator.goalsManager.startSession(goal: nil)
        let startingWords = coordinator.editorState.wordCount

        coordinator.editorState.insertText(" hello", at: coordinator.editorState.getCurrentContent().count)

        XCTAssertEqual(coordinator.editorState.wordCount, startingWords + 1)
        XCTAssertEqual(coordinator.goalsManager.sessionWordsWritten, 1)
        XCTAssertEqual(coordinator.goalsManager.sessionGrossWords, 1)
    }

    func testOpenSplitFromCurrentContextUsesCurrentSceneWhenNoSidebarSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitFromCurrent")
        coordinator.navigationState.selectedSceneId = nil

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, coordinator.editorState.currentSceneId)
    }

    func testOpenSplitFromCurrentContextReturnsNarrowWindowNotice() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitNarrow")

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 480)

        XCTAssertEqual(notice, "Window too narrow for side-by-side split. Using stacked layout.")
        XCTAssertEqual(coordinator.splitEditorState.orientation, .horizontal)
    }

    func testHandleModeChangeClosesOpenSplitWhenEnteringModular() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CloseOnMode")
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 900)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        coordinator.handleModeChange(.modular)

        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testOpenSplitFromCurrentContextSkipsStaleSelectionAndUsesValidFallback() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "StaleSelection")
        let validSceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, validSceneId)
    }

    func testOpenSplitFromCurrentContextReturnsNilWhenNoValidScenesExist() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NoScenes")
        let existingSceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        try coordinator.projectManager.deleteItem(id: existingSceneId, type: .scene)
        coordinator.linearState.reloadSequence()
        coordinator.navigationState.selectedSceneId = nil
        coordinator.editorState.currentSceneId = existingSceneId

        let notice = coordinator.openSplitFromCurrentContext(windowWidth: 900)

        XCTAssertNil(notice)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testToggleSplitOpensThenClosesSplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleSplit")

        let openNotice = coordinator.toggleSplit(windowWidth: 900)
        XCTAssertNil(openNotice)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        let closeNotice = coordinator.toggleSplit(windowWidth: 900)
        XCTAssertNil(closeNotice)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testToggleSplitReturnsNoticeWhenFallbackApplied() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleNarrow")

        let notice = coordinator.toggleSplit(windowWidth: 480)

        XCTAssertEqual(notice, "Window too narrow for side-by-side split. Using stacked layout.")
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertEqual(coordinator.splitEditorState.orientation, .horizontal)
    }

    func testSplitSettingsAreScopedPerProjectPath() throws {
        let suiteName = "WorkspaceCoordinatorTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let projectA = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectA",
            splitSettingsStore: defaults
        )
        projectA.splitEditorState.orientation = .horizontal
        projectA.splitEditorState.splitRatio = 0.33

        let projectB = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectB",
            splitSettingsStore: defaults
        )
        XCTAssertEqual(projectB.splitEditorState.orientation, .vertical)
        XCTAssertEqual(projectB.splitEditorState.splitRatio, 0.5, accuracy: 0.0001)

        try projectA.projectManager.closeProject()
        try projectB.projectManager.closeProject()

        let reopenedProjectA = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "ProjectA",
            splitSettingsStore: defaults
        )
        XCTAssertEqual(reopenedProjectA.splitEditorState.orientation, .horizontal)
        XCTAssertEqual(reopenedProjectA.splitEditorState.splitRatio, 0.33, accuracy: 0.0001)
    }
}
