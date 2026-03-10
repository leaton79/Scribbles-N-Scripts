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
        XCTAssertFalse(coordinator.canToggleSplitEditor)
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

    func testCanToggleSplitEditorAllowsClosingOutsideLinearModeWhenAlreadySplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ToggleSplitCloseInModular")
        let sceneId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.scenes.first?.id)
        coordinator.splitEditorState.openSplit(sceneId: sceneId)
        coordinator.modeController.switchTo(.modular)

        XCTAssertTrue(coordinator.canToggleSplitEditor)
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

    func testCreateChapterAddsTopLevelChapterAndSelectsIt() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapter")
        let before = coordinator.projectManager.getManifest().hierarchy.chapters.count

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, before + 1)
        let created = try XCTUnwrap(manifest.hierarchy.chapters.max(by: { $0.sequenceIndex < $1.sequenceIndex }))
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, created.id)
    }

    func testCreateSceneUsesSelectedChapterAndSelectsNewScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneSelectedChapter")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        coordinator.navigationState.selectedChapterId = chapterId

        let message = coordinator.createScene(title: "Scene Via Action")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let added = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.title == "Scene Via Action" }))
        XCTAssertEqual(added.parentChapterId, chapterId)
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, added.id)
        XCTAssertEqual(coordinator.editorState.currentSceneId, added.id)
    }

    func testCreateSceneCreatesFallbackChapterWhenHierarchyIsEmpty() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneFallbackChapter")
        let initialChapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        try coordinator.projectManager.deleteItem(id: initialChapterId, type: .chapter)
        coordinator.linearState.reloadSequence()

        let message = coordinator.createScene(title: "Recovered Scene")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, 1)
        let createdScene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.title == "Recovered Scene" }))
        XCTAssertNotNil(createdScene.parentChapterId)
    }

    func testNavigateToNextSceneAdvancesInLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NextSceneCommand")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)

        let moved = coordinator.navigateToNextScene()

        XCTAssertTrue(moved)
        XCTAssertNotEqual(coordinator.editorState.currentSceneId, firstScene)
    }

    func testNavigateToPreviousSceneReturnsFalseAtBeginning() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "PreviousSceneBoundary")
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)

        let moved = coordinator.navigateToPreviousScene()

        XCTAssertFalse(moved)
        XCTAssertEqual(coordinator.editorState.currentSceneId, firstScene)
    }

    func testNavigateCommandsNoOpOutsideLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationModeGate")
        coordinator.setMode(.modular)
        let before = coordinator.editorState.currentSceneId

        let movedNext = coordinator.navigateToNextScene()
        let movedPrevious = coordinator.navigateToPreviousScene()

        XCTAssertFalse(movedNext)
        XCTAssertFalse(movedPrevious)
        XCTAssertEqual(coordinator.editorState.currentSceneId, before)
    }

    func testNavigationAvailabilityReflectsLinearBoundaries() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationAvailability")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)

        coordinator.editorState.navigateToScene(id: firstScene)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertTrue(coordinator.canNavigateToNextScene)

        coordinator.editorState.navigateToScene(id: secondScene.id)
        XCTAssertTrue(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)
    }

    func testNavigationAvailabilityDisabledOutsideLinearMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NavigationAvailabilityMode")
        coordinator.setMode(.modular)

        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)
    }

    func testSelectBreadcrumbChapterNavigatesChapterAndFirstScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BreadcrumbChapter")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)

        let chapterCrumb = BreadcrumbItem(id: chapterId, title: "Chapter", type: .chapter)
        coordinator.select(breadcrumb: chapterCrumb)

        XCTAssertEqual(coordinator.navigationState.selectedChapterId, chapterId)
        XCTAssertNotNil(coordinator.navigationState.selectedSceneId)
    }

    func testSelectBreadcrumbSceneNavigatesEditorAndNavigation() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BreadcrumbScene")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Breadcrumb Target")
        coordinator.linearState.reloadSequence()

        let sceneCrumb = BreadcrumbItem(id: scene.id, title: scene.title, type: .scene)
        coordinator.select(breadcrumb: sceneCrumb)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, scene.id)
        XCTAssertEqual(coordinator.editorState.currentSceneId, scene.id)
    }

    func testSaveProjectNowPersistsManifestChanges() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveProject")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        _ = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Unsaved")

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let root = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let manifestOnDisk = try ManifestCoder.read(from: root.appendingPathComponent("manifest.json"))
        XCTAssertTrue(manifestOnDisk.hierarchy.scenes.contains(where: { $0.title == "Unsaved" }))
    }

    func testSaveProjectNowPersistsDirtyEditorContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveEditorContent")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("manual save content", at: 0)

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "manual save content")
    }

    func testSaveProjectNowPersistsSplitPaneDirtyContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveSplitContent")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: scene.id)
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        let secondarySceneId = try XCTUnwrap(coordinator.splitEditorState.secondarySceneId)
        coordinator.splitEditorState.secondaryEditor.insertText("split pane save", at: 0)

        let saveMessage = coordinator.saveProjectNow()

        XCTAssertNil(saveMessage)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: secondarySceneId)
        XCTAssertEqual(diskContent, "split pane save")
    }

    func testHasUnsavedChangesReflectsEditorDirtyAndSave() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DirtyIndicator")
        XCTAssertFalse(coordinator.hasUnsavedChanges)

        coordinator.editorState.insertText("dirty", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
    }

    func testCanSaveProjectTracksUnsavedState() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CanSaveState")
        XCTAssertFalse(coordinator.canSaveProject)

        coordinator.editorState.insertText("dirty", at: 0)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.canSaveProject)
    }

    func testHasUnsavedChangesReflectsSplitPaneDirtyState() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "DirtySplitIndicator")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "SplitDirtyScene")
        coordinator.linearState.reloadSequence()
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        coordinator.editorState.navigateToScene(id: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)

        coordinator.splitEditorState.secondaryEditor.insertText("dirty split", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
    }

    func testCreateBackupNowAddsBackupArchive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupNow")
        let before = coordinator.projectManager.listBackups().count

        let message = coordinator.createBackupNow()

        XCTAssertNotNil(message)
        let after = coordinator.projectManager.listBackups()
        XCTAssertEqual(after.count, before + 1)
        XCTAssertTrue(message?.contains("Backup created") == true)
    }

    func testCreateBackupNowPersistsDirtyEditorBeforeArchiving() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupFlush")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("backup flush content", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)

        let message = coordinator.createBackupNow()

        XCTAssertNotNil(message)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "backup flush content")
    }

    func testActionsFailGracefullyWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "NoProjectActions")
        try coordinator.projectManager.closeProject()

        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        XCTAssertEqual(coordinator.createChapter(), "Could not create chapter: No project is currently open.")
        XCTAssertEqual(coordinator.createScene(), "Could not create scene: No project is currently open.")
        XCTAssertEqual(coordinator.saveProjectNow(), "Could not save project: No project is currently open.")
        XCTAssertEqual(coordinator.createBackupNow(), "Could not create backup: No project is currently open.")
        XCTAssertEqual(coordinator.toggleSplitForCommand(), "No project is currently open.")
        XCTAssertFalse(coordinator.navigateToNextScene())
        XCTAssertFalse(coordinator.navigateToPreviousScene())
    }

    func testHasOpenProjectReflectsProjectLifecycle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "OpenProjectState")
        XCTAssertTrue(coordinator.hasOpenProject)

        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasOpenProject)
    }
}
