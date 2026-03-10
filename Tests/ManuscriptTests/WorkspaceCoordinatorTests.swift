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

    func testSidebarSelectionTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitSelectPrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

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

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testBreadcrumbSelectionTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitBreadcrumbSelect")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: existingSceneId, title: "First", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testBreadcrumbSelectionTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitBreadcrumbSelectPrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let existingSceneId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: existingSceneId, title: "First", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, existingSceneId)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testCreateSceneTargetsSecondaryPaneWhenActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitCreateScene")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "Split Created")

        XCTAssertNil(message)
        let updatedManifest = coordinator.projectManager.getManifest()
        let createdScene = try XCTUnwrap(updatedManifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(createdScene.title, "Split Created")
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, createdScene.id)
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
    }

    func testCreateSceneTargetsPrimaryPaneWhenPrimaryIsActive() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitCreateScenePrimary")
        let manifest = coordinator.projectManager.getManifest()
        let chapterId = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let otherScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Other")

        coordinator.splitEditorState.openSplit(sceneId: otherScene.id)
        coordinator.splitEditorState.setActivePane(0)
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "Split Created Primary")

        XCTAssertNil(message)
        let updatedManifest = coordinator.projectManager.getManifest()
        let createdScene = try XCTUnwrap(updatedManifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(createdScene.title, "Split Created Primary")
        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, createdScene.id)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
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

    func testCreateWriteSaveCloseAndReopenLastProjectWorkflow() throws {
        let suiteName = "WorkspaceCoordinatorTests.Recent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "WorkflowSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "WorkflowMain"))
        let workflowRoot = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)

        coordinator.editorState.insertText("workflow text", at: 0)
        XCTAssertNil(coordinator.saveProjectNow())

        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasOpenProject)

        XCTAssertNil(coordinator.reopenLastProject())
        XCTAssertEqual(coordinator.projectManager.projectRootURL, workflowRoot)
        let reopenedContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(reopenedContent, "workflow text")
    }

    func testOpenProjectSwitchesToSelectedProjectAndUpdatesRecentEntry() throws {
        let suiteName = "WorkspaceCoordinatorTests.OpenRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let seed = FileSystemProjectManager()
        _ = try seed.createProject(name: "TargetOpen", at: tempDir)
        try seed.closeProject()

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "CurrentProject",
            recentProjectStore: defaults
        )
        let targetURL = tempDir.appendingPathComponent("TargetOpen", isDirectory: true)

        XCTAssertNil(coordinator.openProject(at: targetURL))
        XCTAssertEqual(coordinator.projectManager.projectRootURL, targetURL)
        XCTAssertEqual(coordinator.projectDisplayName, "TargetOpen")

        try coordinator.projectManager.closeProject()
        XCTAssertNil(coordinator.reopenLastProject())
        XCTAssertEqual(coordinator.projectManager.projectRootURL, targetURL)
    }

    func testRecentProjectsTrackMostRecentFirstAndDeduplicate() throws {
        let suiteName = "WorkspaceCoordinatorTests.RecentList.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "RecentSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentA"))
        let recentA = tempDir.appendingPathComponent("RecentA", isDirectory: true)
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentB"))
        XCTAssertNil(coordinator.openProject(at: recentA))

        let names = coordinator.recentProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "RecentA")
        XCTAssertEqual(names[1], "RecentB")
        XCTAssertEqual(names.filter { $0 == "RecentA" }.count, 1)
    }

    func testSwitchableProjectsPrioritizeCurrentThenRecentsWithoutDuplication() throws {
        let suiteName = "WorkspaceCoordinatorTests.SwitchableProjects.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "SwitchSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "SwitchA"))
        XCTAssertNil(coordinator.createAndOpenProject(named: "SwitchB"))
        let switchAURL = tempDir.appendingPathComponent("SwitchA", isDirectory: true)
        XCTAssertNil(coordinator.openProject(at: switchAURL))

        let names = coordinator.switchableProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "SwitchA")
        XCTAssertEqual(names[1], "SwitchB")
        XCTAssertEqual(names.filter { $0 == "SwitchA" }.count, 1)
    }

    func testShowInlineSearchUsesCurrentSceneIncludingUnsavedContent() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchInline")
        coordinator.editorState.insertText("dragon", at: 0)
        coordinator.searchQueryText = "dragon"

        coordinator.showInlineSearchPanel()

        XCTAssertTrue(coordinator.isSearchPanelVisible)
        XCTAssertEqual(coordinator.searchScope, .currentScene)
        XCTAssertEqual(coordinator.searchResults.count, 1)
        XCTAssertEqual(coordinator.searchResults.first?.matchText.lowercased(), "dragon")
    }

    func testProjectSearchReplaceAllUpdatesScenes() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceAll")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "color color")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "color")
        coordinator.editorState.navigateToScene(id: firstSceneId)

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "color"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.count, 3)

        coordinator.searchReplacementText = "colour"
        let message = coordinator.replaceAllSearchResults()

        XCTAssertEqual(message, "Replaced 3 matches across 2 scenes.")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: firstSceneId), "colour colour")
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: secondScene.id), "colour")
    }

    func testReplaceNextSearchResultUpdatesCurrentMatchOnly() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchReplaceNext")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "color color color")
        coordinator.searchQueryText = "color"
        coordinator.searchReplacementText = "colour"

        coordinator.showInlineSearchPanel()
        coordinator.selectSearchResult(at: 0)

        let message = coordinator.replaceNextSearchResult()
        XCTAssertEqual(message, "Replaced next match.")
        XCTAssertEqual(coordinator.editorState.getCurrentContent(), "colour color color")
        XCTAssertEqual(coordinator.searchResults.count, 2)
    }

    func testSearchResultNavigationWrapsAndUpdatesCursorSelection() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchNavigation")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "cat sat cat")
        coordinator.searchQueryText = "cat"

        coordinator.showInlineSearchPanel()
        XCTAssertEqual(coordinator.searchResultPositionText, "1 of 2")

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "2 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 8..<11)
        XCTAssertEqual(coordinator.editorState.cursorPosition, 11)

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "1 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 0..<3)
        XCTAssertEqual(coordinator.editorState.cursorPosition, 3)

        coordinator.navigateToPreviousSearchResult()
        XCTAssertEqual(coordinator.searchResultPositionText, "2 of 2")
        XCTAssertEqual(coordinator.editorState.selection, 8..<11)
    }

    func testSelectingProjectSearchResultNavigatesToMatchingScene() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchSelectResult")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        try coordinator.projectManager.saveSceneContent(sceneId: firstSceneId, content: "apple")
        try coordinator.projectManager.saveSceneContent(sceneId: secondScene.id, content: "banana")

        coordinator.showProjectSearchPanel()
        coordinator.searchQueryText = "banana"
        coordinator.runSearch()
        XCTAssertEqual(coordinator.searchResults.count, 1)

        coordinator.selectSearchResult(at: 0)
        XCTAssertEqual(coordinator.editorState.currentSceneId, secondScene.id)
        XCTAssertEqual(coordinator.navigationState.selectedSceneId, secondScene.id)
        XCTAssertEqual(coordinator.editorState.selection, 0..<6)
    }

    func testSearchHighlightsTrackMatchesAndClearOnHide() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlights")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: "the cat sat on the mat")
        coordinator.searchQueryText = "the"

        coordinator.showInlineSearchPanel()
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 2)
        XCTAssertEqual(coordinator.editorState.activeSearchHighlightRange, 0..<3)

        coordinator.navigateToNextSearchResult()
        XCTAssertEqual(coordinator.editorState.activeSearchHighlightRange, 15..<18)

        coordinator.hideSearchPanel()
        XCTAssertTrue(coordinator.editorState.searchHighlightRanges.isEmpty)
        XCTAssertNil(coordinator.editorState.activeSearchHighlightRange)
    }

    func testSearchHighlightCapAndShowAllToggle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SearchHighlightCap")
        let content = Array(repeating: "hit", count: 120).joined(separator: " ")
        coordinator.editorState.replaceText(in: 0..<coordinator.editorState.getCurrentContent().count, with: content)
        coordinator.searchQueryText = "hit"

        coordinator.showInlineSearchPanel()

        XCTAssertEqual(coordinator.searchResults.count, 120)
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 100)
        XCTAssertEqual(coordinator.hiddenSearchHighlightCount, 20)

        coordinator.toggleShowAllSearchHighlights()
        XCTAssertEqual(coordinator.editorState.searchHighlightRanges.count, 120)
        XCTAssertEqual(coordinator.hiddenSearchHighlightCount, 0)
    }

    func testClearRecentProjectsRemovesRecentAndLastEntries() throws {
        let suiteName = "WorkspaceCoordinatorTests.ClearRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "RecentClearSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "RecentClearA"))
        XCTAssertTrue(coordinator.canReopenLastProject)
        XCTAssertTrue(coordinator.canClearRecentProjects)
        XCTAssertFalse(coordinator.recentProjects.isEmpty)

        coordinator.clearRecentProjects()

        XCTAssertFalse(coordinator.canReopenLastProject)
        XCTAssertFalse(coordinator.canClearRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.isEmpty)
    }

    func testCleanupMissingRecentProjectsRemovesStaleEntries() throws {
        let suiteName = "WorkspaceCoordinatorTests.CleanupMissingRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let validManager = FileSystemProjectManager()
        _ = try validManager.createProject(name: "CleanupValid", at: tempDir)
        let validURL = try XCTUnwrap(validManager.projectRootURL)
        try validManager.closeProject()

        let missingURL = tempDir.appendingPathComponent("CleanupMissing", isDirectory: true)
        defaults.set([missingURL.path, validURL.path], forKey: "workspace.recentProjects")
        defaults.set(missingURL.path, forKey: "workspace.lastOpenedProjectPath")

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "CleanupSeed",
            recentProjectStore: defaults
        )
        XCTAssertTrue(coordinator.hasStaleRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.contains(where: { $0.name == "CleanupValid" }))

        coordinator.cleanupMissingRecentProjects()

        XCTAssertFalse(coordinator.hasStaleRecentProjects)
        XCTAssertTrue(coordinator.recentProjects.contains(where: { $0.name == "CleanupValid" }))
    }

    func testRecentProjectsSnapshotRestoreSupportsUndo() throws {
        let suiteName = "WorkspaceCoordinatorTests.RecentUndo.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let coordinator = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "UndoSeed",
            recentProjectStore: defaults
        )
        XCTAssertNil(coordinator.createAndOpenProject(named: "UndoA"))
        XCTAssertNil(coordinator.createAndOpenProject(named: "UndoB"))
        let before = coordinator.snapshotRecentProjects()
        XCTAssertFalse(before.paths.isEmpty)

        coordinator.clearRecentProjects()
        XCTAssertTrue(coordinator.recentProjects.isEmpty)

        coordinator.restoreRecentProjects(from: before)
        let restoredNames = coordinator.recentProjects.map(\.name)
        XCTAssertTrue(restoredNames.contains("UndoA"))
        XCTAssertTrue(restoredNames.contains("UndoB"))
    }

    func testSaveProjectAsCreatesCopyAndSwitchesContext() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAsSource")
        let sourceURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("save as baseline", at: 0)

        let message = coordinator.saveProjectAs(named: "SaveAsCopy")

        XCTAssertNil(message)
        let copyURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        XCTAssertNotEqual(copyURL, sourceURL)
        XCTAssertEqual(copyURL.lastPathComponent, "SaveAsCopy")
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: sceneId), "save as baseline")
    }

    func testSaveProjectAsReturnsConflictMessageWhenDestinationExists() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAsConflictSource")
        let conflictURL = tempDir.appendingPathComponent("SaveAsConflictTarget", isDirectory: true)
        try FileManager.default.createDirectory(at: conflictURL, withIntermediateDirectories: true)

        let message = coordinator.saveProjectAs(named: "SaveAsConflictTarget")

        XCTAssertEqual(message, "Could not save project as: A project named \"SaveAsConflictTarget\" already exists.")
    }

    func testRenameProjectMovesDirectoryAndKeepsProjectOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RenameSource")
        let sourceURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.editorState.insertText("rename baseline", at: 0)

        let message = coordinator.renameCurrentProject(to: "RenamedProject")

        XCTAssertNil(message)
        let renamedURL = try XCTUnwrap(coordinator.projectManager.projectRootURL)
        XCTAssertEqual(renamedURL.lastPathComponent, "RenamedProject")
        XCTAssertFalse(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertEqual(try coordinator.projectManager.loadSceneContent(sceneId: sceneId), "rename baseline")
    }

    func testRenameProjectReturnsConflictMessageWhenDestinationExists() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "RenameConflictSource")
        let conflictURL = tempDir.appendingPathComponent("RenameConflictTarget", isDirectory: true)
        try FileManager.default.createDirectory(at: conflictURL, withIntermediateDirectories: true)

        let message = coordinator.renameCurrentProject(to: "RenameConflictTarget")

        XCTAssertEqual(message, "Could not rename project: A project named \"RenameConflictTarget\" already exists.")
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

    func testCreateChapterFallsBackToGeneratedTitleWhenInputIsWhitespace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterWhitespaceTitle")
        let beforeCount = coordinator.projectManager.getManifest().hierarchy.chapters.count

        let message = coordinator.createChapter(title: "   \n\t ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, beforeCount + 1)
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter \(beforeCount + 1)" }))
    }

    func testCreateChapterTrimsSurroundingWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterTrimmedTitle")

        let message = coordinator.createChapter(title: "  Trimmed Chapter  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Trimmed Chapter" }))
    }

    func testCreateChapterCollapsesInternalWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterCollapsedWhitespace")

        let message = coordinator.createChapter(title: "  Chapter\t\tName \n  Final  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter Name Final" }))
    }

    func testCreateChapterNormalizesNonBreakingSpacesInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterNBSPTitle")

        let message = coordinator.createChapter(title: "Chapter\u{00A0}\u{00A0}Name")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter Name" }))
    }

    func testCreateChapterGeneratedTitleFillsNumericGaps() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterGaps")
        _ = coordinator.createChapter(title: "Chapter 3")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 2" }))
    }

    func testCreateChapterGeneratedTitleParsesLegacySpacingAndCase() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterLegacySpacing")
        _ = coordinator.createChapter(title: "chapter   2")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 3" }))
    }

    func testCreateChapterGeneratedTitleParsesLegacyNonBreakingSpace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateChapterLegacyNBSP")
        _ = coordinator.createChapter(title: "Chapter\u{00A0}2")

        let message = coordinator.createChapter()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.chapters.contains(where: { $0.title == "Chapter 3" }))
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

    func testCreateSceneFallsBackToGeneratedTitleWhenInputIsWhitespace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneWhitespaceTitle")
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene(title: "   \n\t ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let created = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(created.title, "Scene 1")
    }

    func testCreateSceneUsesGeneratedTitleWhenNoTitleProvided() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneGeneratedTitle")
        let existingSceneIds = Set(coordinator.projectManager.getManifest().hierarchy.scenes.map(\.id))

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        let created = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { !existingSceneIds.contains($0.id) }))
        XCTAssertEqual(created.title, "Scene 1")
    }

    func testCreateSceneGeneratedTitleFillsNumericGaps() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneGaps")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "Scene 3")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 2" }))
    }

    func testCreateSceneGeneratedTitleParsesLegacySpacingAndCase() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneLegacySpacing")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "scene   2")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 3" }))
    }

    func testCreateSceneGeneratedTitleParsesLegacyNonBreakingSpace() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneLegacyNBSP")
        _ = coordinator.createScene(title: "Scene 1")
        _ = coordinator.createScene(title: "Scene\u{00A0}2")

        let message = coordinator.createScene()

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene 3" }))
    }

    func testCreateSceneTrimsSurroundingWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneTrimmedTitle")

        let message = coordinator.createScene(title: "  Trimmed Title  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Trimmed Title" }))
    }

    func testCreateSceneCollapsesInternalWhitespaceInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneCollapsedWhitespace")

        let message = coordinator.createScene(title: "  Scene\t\tTitle \n  Final  ")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene Title Final" }))
    }

    func testCreateSceneNormalizesNonBreakingSpacesInTitle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CreateSceneNBSPTitle")

        let message = coordinator.createScene(title: "Scene\u{00A0}\u{00A0}Title")

        XCTAssertNil(message)
        let manifest = coordinator.projectManager.getManifest()
        XCTAssertTrue(manifest.hierarchy.scenes.contains(where: { $0.title == "Scene Title" }))
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

    func testCommandAvailabilityMatrixAcrossBoundaryStates() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandAvailabilityMatrix")

        // Baseline: one-scene linear project.
        XCTAssertTrue(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Two-scene linear project at first scene.
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        let firstScene = try XCTUnwrap(coordinator.linearState.orderedSceneIds.first)
        coordinator.editorState.navigateToScene(id: firstScene)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertTrue(coordinator.canNavigateToNextScene)

        // Two-scene linear project at second scene.
        coordinator.editorState.navigateToScene(id: secondScene.id)
        XCTAssertTrue(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Modular mode with no split open disables toggle and navigation.
        coordinator.setMode(.modular)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertFalse(coordinator.canNavigateToPreviousScene)
        XCTAssertFalse(coordinator.canNavigateToNextScene)

        // Split open remains closable outside linear mode.
        coordinator.modeController.switchTo(.linear)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        coordinator.modeController.switchTo(.modular)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertTrue(coordinator.canToggleSplitEditor)

        // Stale selected/current scene IDs still allow split via valid sequence fallback.
        coordinator.splitEditorState.closeSplit()
        coordinator.modeController.switchTo(.linear)
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        XCTAssertTrue(coordinator.canToggleSplitEditor)

        // No project means all command availability is disabled.
        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.canToggleSplitEditor)
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

    func testSaveProjectNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.saveProjectNow()

        XCTAssertEqual(message, "Could not save project: Simulated manifest write failure")
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

    func testSaveAvailabilityMatrixAcrossEditorSplitAndNoProjectTransitions() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAvailabilityMatrix")
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // Primary editor dirty state enables save.
        coordinator.editorState.insertText("dirty primary", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // Split secondary dirty state enables save.
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Second")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: secondScene.id)
        coordinator.navigationState.navigateTo(sceneId: secondScene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        coordinator.splitEditorState.secondaryEditor.insertText("dirty secondary", at: 0)
        XCTAssertTrue(coordinator.hasUnsavedChanges)
        XCTAssertTrue(coordinator.canSaveProject)

        _ = coordinator.saveProjectNow()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertFalse(coordinator.canSaveProject)

        // No project disables save availability regardless of prior state.
        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasUnsavedChanges)
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

    func testCreateBackupNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BackupFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.createBackupNow()

        XCTAssertEqual(message, "Could not create backup: Simulated manifest write failure")
    }

    func testSaveAndBackupNowPersistsDirtyEditorAndCreatesBackup() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackup")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        let before = coordinator.projectManager.listBackups().count
        coordinator.editorState.insertText("save and backup content", at: 0)

        let message = coordinator.saveAndBackupNow()

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("Project saved and backup created") == true)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertEqual(coordinator.projectManager.listBackups().count, before + 1)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: sceneId)
        XCTAssertEqual(diskContent, "save and backup content")
    }

    func testSaveAndBackupNowPersistsSplitPaneDirtyContentAndCreatesBackup() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackupSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let scene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Split Backup Scene")
        coordinator.linearState.reloadSequence()
        coordinator.editorState.navigateToScene(id: scene.id)
        coordinator.navigationState.navigateTo(sceneId: scene.id)
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        let secondarySceneId = try XCTUnwrap(coordinator.splitEditorState.secondarySceneId)
        coordinator.splitEditorState.secondaryEditor.insertText("split save+backup", at: 0)
        let before = coordinator.projectManager.listBackups().count

        let message = coordinator.saveAndBackupNow()

        XCTAssertNotNil(message)
        XCTAssertTrue(message?.contains("Project saved and backup created") == true)
        XCTAssertFalse(coordinator.hasUnsavedChanges)
        XCTAssertEqual(coordinator.projectManager.listBackups().count, before + 1)
        let diskContent = try coordinator.projectManager.loadSceneContent(sceneId: secondarySceneId)
        XCTAssertEqual(diskContent, "split save+backup")
    }

    func testSaveAndBackupNowReturnsErrorMessageWhenManifestWriteFails() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SaveAndBackupFailureMessage")
        coordinator.projectManager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: "WorkspaceCoordinatorTests", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Simulated manifest write failure"
            ])
        }

        let message = coordinator.saveAndBackupNow()

        XCTAssertEqual(message, "Could not save and back up project: Simulated manifest write failure")
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
        XCTAssertEqual(coordinator.saveAndBackupNow(), "Could not save and back up project: No project is currently open.")
        XCTAssertEqual(coordinator.toggleSplitForCommand(), "No project is currently open.")
        XCTAssertFalse(coordinator.navigateToNextScene())
        XCTAssertFalse(coordinator.navigateToPreviousScene())
    }

    func testSplitToggleAvailabilityStaysDisabledAfterCloseEvenIfSplitRemainsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SplitAvailabilityAfterClose")
        XCTAssertNil(coordinator.toggleSplit(windowWidth: 1200))
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        try coordinator.projectManager.closeProject()

        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertFalse(coordinator.canToggleSplitEditor)
        XCTAssertEqual(coordinator.toggleSplitForCommand(), "No project is currently open.")
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
    }

    func testHasOpenProjectReflectsProjectLifecycle() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "OpenProjectState")
        XCTAssertTrue(coordinator.hasOpenProject)

        try coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.hasOpenProject)
    }

    func testModeSwitchAvailabilityReflectsActiveMode() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchAvailability")
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testModeSwitchAvailabilityMatrixAcrossNoOpAndSplitTransitions() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchMatrix")

        // Baseline linear state.
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Same-mode no-op preserves availability.
        coordinator.setMode(.linear)
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Split-open linear still allows switching to modular.
        _ = coordinator.openSplitFromCurrentContext(windowWidth: 1200)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // Switching to modular flips availability and closes split.
        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)

        // Same-mode no-op in modular preserves availability.
        coordinator.setMode(.modular)
        XCTAssertTrue(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)

        // Switching back to linear flips availability again.
        coordinator.setMode(.linear)
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertTrue(coordinator.canSwitchToModularMode)

        // No-project state disables both switches.
        try? coordinator.projectManager.closeProject()
        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testModeSwitchAvailabilityDisabledWithoutOpenProject() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ModeSwitchNoProject")
        try coordinator.projectManager.closeProject()

        XCTAssertFalse(coordinator.canSwitchToLinearMode)
        XCTAssertFalse(coordinator.canSwitchToModularMode)
    }

    func testSetModeToModularClosesOpenSplit() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SetModeClosesSplit")
        let openMessage = coordinator.toggleSplit(windowWidth: 1200)
        XCTAssertNil(openMessage)
        XCTAssertTrue(coordinator.splitEditorState.isSplit)

        coordinator.setMode(.modular)

        XCTAssertEqual(coordinator.modeController.activeMode, .modular)
        XCTAssertFalse(coordinator.splitEditorState.isSplit)
    }

    func testSetModeNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SetModeNoProject")
        try coordinator.projectManager.closeProject()

        coordinator.setMode(.modular)

        XCTAssertEqual(coordinator.modeController.activeMode, .linear)
    }

    func testHandleScenePhaseActiveDoesNotStartSessionWithoutOpenProject() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "ScenePhaseNoProject")
        try coordinator.projectManager.closeProject()

        coordinator.handleScenePhase(.active)

        XCTAssertNil(coordinator.goalsManager.sessionStartTime)
        XCTAssertFalse(coordinator.goalsManager.isTimerRunning)
    }

    func testSelectNodeNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectNodeNoProject")
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        let beforeSelectedScene = coordinator.navigationState.selectedSceneId
        let beforeCurrentScene = coordinator.editorState.currentSceneId
        try coordinator.projectManager.closeProject()

        let node = SidebarNode(
            id: UUID(),
            title: "Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: node)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, beforeSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, beforeCurrentScene)
    }

    func testSelectBreadcrumbNoOpWhenNoProjectIsOpen() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectBreadcrumbNoProject")
        coordinator.navigationState.selectedSceneId = UUID()
        coordinator.editorState.currentSceneId = UUID()
        let beforeSelectedScene = coordinator.navigationState.selectedSceneId
        let beforeCurrentScene = coordinator.editorState.currentSceneId
        try coordinator.projectManager.closeProject()

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Scene", type: .scene))

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, beforeSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, beforeCurrentScene)
    }

    func testSelectNodeIgnoresStaleSceneAndChapterIds() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleNode")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.navigationState.navigateTo(sceneId: sceneId)
        let originalSelectedScene = coordinator.navigationState.selectedSceneId
        let originalCurrentScene = coordinator.editorState.currentSceneId
        let originalSelectedChapter = coordinator.navigationState.selectedChapterId

        let staleSceneNode = SidebarNode(
            id: UUID(),
            title: "Stale Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleSceneNode)

        let staleChapterNode = SidebarNode(
            id: UUID(),
            title: "Stale Chapter",
            level: .chapter,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleChapterNode)

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, originalSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, originalCurrentScene)
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, originalSelectedChapter)
    }

    func testSelectNodeIgnoresStaleSceneWithoutChangingSplitPaneTargets() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleNodeSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondaryScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.splitEditorState.openSplit(sceneId: secondaryScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        let staleSceneNode = SidebarNode(
            id: UUID(),
            title: "Stale Scene",
            level: .scene,
            wordCount: 0,
            colorLabel: nil,
            goalProgressText: nil,
            children: [],
            matchingCount: nil
        )
        coordinator.select(node: staleSceneNode)

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }

    func testSelectBreadcrumbIgnoresStaleSceneAndChapterIds() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleBreadcrumb")
        let sceneId = try XCTUnwrap(coordinator.editorState.currentSceneId)
        coordinator.navigationState.navigateTo(sceneId: sceneId)
        let originalSelectedScene = coordinator.navigationState.selectedSceneId
        let originalCurrentScene = coordinator.editorState.currentSceneId
        let originalSelectedChapter = coordinator.navigationState.selectedChapterId

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Scene", type: .scene))
        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Chapter", type: .chapter))

        XCTAssertEqual(coordinator.navigationState.selectedSceneId, originalSelectedScene)
        XCTAssertEqual(coordinator.editorState.currentSceneId, originalCurrentScene)
        XCTAssertEqual(coordinator.navigationState.selectedChapterId, originalSelectedChapter)
    }

    func testSelectBreadcrumbIgnoresStaleSceneWithoutChangingSplitPaneTargets() throws {
        let coordinator = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "SelectStaleBreadcrumbSplit")
        let chapterId = try XCTUnwrap(coordinator.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondaryScene = try coordinator.projectManager.addScene(to: chapterId, at: nil, title: "Secondary")
        coordinator.splitEditorState.openSplit(sceneId: secondaryScene.id)
        coordinator.splitEditorState.setActivePane(1)
        let primaryBefore = coordinator.splitEditorState.primarySceneId
        let secondaryBefore = coordinator.splitEditorState.secondarySceneId

        coordinator.select(breadcrumb: BreadcrumbItem(id: UUID(), title: "Stale Scene", type: .scene))

        XCTAssertEqual(coordinator.splitEditorState.primarySceneId, primaryBefore)
        XCTAssertEqual(coordinator.splitEditorState.secondarySceneId, secondaryBefore)
    }
}
