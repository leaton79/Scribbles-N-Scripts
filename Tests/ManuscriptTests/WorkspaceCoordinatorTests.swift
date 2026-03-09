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
}
