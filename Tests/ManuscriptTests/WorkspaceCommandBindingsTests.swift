import XCTest
@testable import ScribblesNScripts

@MainActor
final class WorkspaceCommandBindingsTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        UserDefaults.standard.removeObject(forKey: "workspace.searchHighlightCap")
        UserDefaults.standard.removeObject(forKey: "workspace.searchHighlightSafetyThreshold")
        UserDefaults.standard.removeObject(forKey: "workspace.replaceSceneSelectionMode")
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
        XCTAssertTrue(bindings.canToggleInspector)
        XCTAssertFalse(bindings.canSaveProject)
        XCTAssertFalse(bindings.canNavigateToPreviousScene)
        XCTAssertFalse(bindings.canNavigateToNextScene)
        XCTAssertEqual(bindings.splitToggleTitle, "Toggle Split")
        XCTAssertEqual(bindings.inspectorToggleTitle, "Hide Inspector")

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
        XCTAssertFalse(bindings.canToggleInspector)
    }

    func testInspectorToggleDelegatesToWorkspaceCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsInspector")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertTrue(workspace.isInspectorVisible)
        bindings.toggleInspector()
        XCTAssertFalse(workspace.isInspectorVisible)
        XCTAssertEqual(bindings.inspectorToggleTitle, "Show Inspector")
    }

    func testProjectActionsDelegateToWorkspaceCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "CommandBindingsProjectActions")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertNil(bindings.createChapter())
        XCTAssertNil(bindings.createScene())
        XCTAssertNil(bindings.createSceneBelow())
        XCTAssertNil(bindings.duplicateSelectedScene())
        XCTAssertNil(bindings.saveProject())

        let backupMessage = bindings.createBackup()
        XCTAssertNotNil(backupMessage)
        XCTAssertTrue(backupMessage?.contains("Backup created") == true)

        let saveAndBackupMessage = bindings.saveAndBackup()
        XCTAssertNotNil(saveAndBackupMessage)
        XCTAssertTrue(saveAndBackupMessage?.contains("Project saved and backup created") == true)
    }

    func testOpenSelectionInSplitDelegatesToCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsOpenSplit")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        let manifest = workspace.projectManager.getManifest()
        let chapterID = try XCTUnwrap(manifest.hierarchy.chapters.first?.id)
        let secondScene = try workspace.projectManager.addScene(to: chapterID, at: nil, title: "Second")
        workspace.navigationState.navigateTo(sceneId: secondScene.id)

        XCTAssertNil(bindings.openSelectionInSplit())
        XCTAssertTrue(workspace.splitEditorState.isSplit)
        XCTAssertEqual(workspace.splitEditorState.secondarySceneId, secondScene.id)
    }

    func testSceneReorderAndRevealDelegatesToCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSceneReorder")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        let chapterID = try XCTUnwrap(workspace.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try workspace.projectManager.addScene(to: chapterID, at: nil, title: "Second")
        workspace.navigateToScene(secondScene.id)

        XCTAssertNil(bindings.moveSelectedSceneUp())
        let sceneOrder = try XCTUnwrap(
            workspace.projectManager.getManifest().hierarchy.chapters.first(where: { $0.id == chapterID })?.scenes
        )
        XCTAssertEqual(sceneOrder.first, secondScene.id)

        XCTAssertNil(bindings.revealSelectionInSidebar())
        XCTAssertEqual(workspace.navigationState.selectedSceneId, secondScene.id)
        XCTAssertTrue(bindings.canRevealSelectionInSidebar)
    }

    func testModularPresentationBindingsUpdateState() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsModularPresentation")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        workspace.setMode(.modular)
        XCTAssertTrue(bindings.canUseModularPresentationControls)

        bindings.showOutlinerMode()
        XCTAssertEqual(workspace.modularState.presentationMode, .outliner)

        bindings.groupModularByStatus()
        XCTAssertEqual(workspace.modularState.grouping, .byStatus)

        bindings.showCorkboardMode()
        bindings.setCorkboardDensityCompact()
        XCTAssertEqual(workspace.modularState.presentationMode, .corkboard)
        XCTAssertEqual(workspace.modularState.corkboardDensity, .compact)

        bindings.collapseAllModularGroups()
        XCTAssertEqual(workspace.modularState.collapsedGroupIDs.count, workspace.modularState.groups.count)

        bindings.expandAllModularGroups()
        XCTAssertTrue(workspace.modularState.collapsedGroupIDs.isEmpty)
    }

    func testMoveToChapterAndSendToStagingDelegateToCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsMoveChapter")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        let chapterA = try XCTUnwrap(workspace.projectManager.getManifest().hierarchy.chapters.first?.id)
        let chapterB = try workspace.projectManager.addChapter(to: nil, at: nil, title: "Chapter B")
        let secondScene = try workspace.projectManager.addScene(to: chapterA, at: nil, title: "Second")
        workspace.navigateToScene(secondScene.id)

        XCTAssertNil(bindings.sendSelectedSceneToStaging())
        XCTAssertTrue(workspace.projectManager.currentProject?.manuscript.stagingArea.contains(where: { $0.id == secondScene.id }) == true)
        XCTAssertNil(bindings.moveSelectedScene(toChapter: chapterB.id))
        XCTAssertTrue(workspace.projectManager.currentProject?.manuscript.chapters.first(where: { $0.id == chapterB.id })?.scenes.contains(where: { $0.id == secondScene.id }) == true)
    }

    func testProjectOpenCreateAndReopenDelegation() throws {
        let suiteName = "WorkspaceCommandBindingsTests.Recent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertNil(bindings.createProject(named: "BindingsNew"))
        XCTAssertEqual(workspace.projectDisplayName, "BindingsNew")

        let target = FileSystemProjectManager()
        _ = try target.createProject(name: "BindingsTarget", at: tempDir)
        try target.closeProject()
        let targetURL = tempDir.appendingPathComponent("BindingsTarget", isDirectory: true)

        XCTAssertNil(bindings.openProject(at: targetURL))
        XCTAssertEqual(workspace.projectDisplayName, "BindingsTarget")
        XCTAssertTrue(bindings.canReopenLastProject)

        try workspace.projectManager.closeProject()
        XCTAssertNil(bindings.reopenLastProject())
        XCTAssertEqual(workspace.projectDisplayName, "BindingsTarget")
    }

    func testSaveAsAndRenameDelegationAndAvailability() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSaveAsRename")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertTrue(bindings.canSaveProjectAs)
        XCTAssertTrue(bindings.canRenameProject)

        XCTAssertNil(bindings.saveProjectAs(named: "BindingsCopy"))
        XCTAssertEqual(workspace.projectDisplayName, "BindingsCopy")

        XCTAssertNil(bindings.renameProject(to: "BindingsRenamed"))
        XCTAssertEqual(workspace.projectDisplayName, "BindingsRenamed")

        try workspace.projectManager.closeProject()
        XCTAssertFalse(bindings.canSaveProjectAs)
        XCTAssertFalse(bindings.canRenameProject)
        XCTAssertEqual(bindings.saveProjectAs(named: "NoProject"), "Could not save project as: No project is currently open.")
        XCTAssertEqual(bindings.renameProject(to: "NoProject"), "Could not rename project: No project is currently open.")
    }

    func testRecentProjectsExposeMostRecentAndAllowOpen() throws {
        let suiteName = "WorkspaceCommandBindingsTests.RecentList.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsRecentSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertNil(bindings.createProject(named: "BindingsRecentA"))
        let recentA = tempDir.appendingPathComponent("BindingsRecentA", isDirectory: true)
        XCTAssertNil(bindings.createProject(named: "BindingsRecentB"))
        XCTAssertNil(bindings.openProject(at: recentA))

        let names = bindings.recentProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "BindingsRecentA")
        XCTAssertEqual(names[1], "BindingsRecentB")
    }

    func testSwitchableProjectsExposeCurrentThenRecents() throws {
        let suiteName = "WorkspaceCommandBindingsTests.Switchable.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsSwitchSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertNil(bindings.createProject(named: "BindingsSwitchA"))
        XCTAssertNil(bindings.createProject(named: "BindingsSwitchB"))
        let switchAURL = tempDir.appendingPathComponent("BindingsSwitchA", isDirectory: true)
        XCTAssertNil(bindings.openProject(at: switchAURL))

        let names = bindings.switchableProjects.map(\.name)
        XCTAssertGreaterThanOrEqual(names.count, 2)
        XCTAssertEqual(names[0], "BindingsSwitchA")
        XCTAssertEqual(names[1], "BindingsSwitchB")
    }

    func testSearchBindingsShowPanelsAndRunReplaceAll() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSearch")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertTrue(bindings.canSearchProject)
        bindings.showInlineSearch()
        XCTAssertTrue(workspace.isSearchPanelVisible)
        XCTAssertEqual(workspace.searchScope, .currentScene)

        workspace.searchQueryText = "alpha"
        workspace.editorState.insertText("alpha alpha", at: 0)
        bindings.runSearch()
        XCTAssertEqual(workspace.searchResults.count, 2)

        workspace.searchReplacementText = "beta"
        let replaceMessage = bindings.replaceAllSearchResults()
        XCTAssertEqual(replaceMessage, "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(workspace.editorState.getCurrentContent(), "beta beta")

        bindings.hideSearch()
        XCTAssertFalse(workspace.isSearchPanelVisible)
    }

    func testSearchBindingsReplaceNext() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsReplaceNext")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "alpha alpha")
        workspace.searchQueryText = "alpha"
        workspace.searchReplacementText = "beta"

        bindings.showInlineSearch()
        let message = bindings.replaceNextSearchResult()

        XCTAssertEqual(message, "Replaced next match.")
        XCTAssertEqual(workspace.editorState.getCurrentContent(), "beta alpha")
    }

    func testSearchBindingsNavigateResults() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSearchNavigation")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "one one one")
        workspace.searchQueryText = "one"

        bindings.showInlineSearch()
        XCTAssertEqual(bindings.searchResultPositionText, "1 of 3")

        bindings.navigateToNextSearchResult()
        XCTAssertEqual(bindings.searchResultPositionText, "2 of 3")

        bindings.navigateToPreviousSearchResult()
        XCTAssertEqual(bindings.searchResultPositionText, "1 of 3")

        bindings.selectSearchResult(at: 2)
        XCTAssertEqual(bindings.currentSearchResultIndex, 2)
        XCTAssertEqual(bindings.searchResultPositionText, "3 of 3")
    }

    func testSearchBindingsSupportPreviewMatchNavigationAndChapterPresets() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSearchPreviewPresets")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        let secondChapter = try workspace.projectManager.addChapter(to: nil, at: nil, title: "Second")

        workspace.searchScope = .selectedChapters
        workspace.selectedSearchChapterIDs = [secondChapter.id]
        XCTAssertEqual(bindings.saveSelectedSearchChapterPreset(), "Saved chapter scope preset: Second.")
        let presetID = try XCTUnwrap(workspace.searchChapterPresets.first?.id)

        workspace.clearSearchChapterSelection()
        bindings.applySearchChapterPreset(presetID)
        XCTAssertEqual(workspace.selectedSearchChapterIDs, Set([secondChapter.id]))

        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "alpha one alpha two")
        bindings.showInlineSearch()
        workspace.searchQueryText = "alpha"
        bindings.runSearch()
        let previewTarget = try XCTUnwrap(workspace.replacePreviewItems().first?.matchTargets.last)

        bindings.selectReplacePreviewMatch(sceneID: try XCTUnwrap(workspace.editorState.currentSceneId), resultIndex: previewTarget.resultIndex)
        XCTAssertEqual(bindings.currentSearchResultIndex, previewTarget.resultIndex)

        bindings.deleteSearchChapterPreset(presetID)
        XCTAssertTrue(workspace.searchChapterPresets.isEmpty)
    }

    func testSearchHighlightToggleAvailabilityAndAction() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSearchHighlightToggle")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        workspace.editorState.replaceText(
            in: 0..<workspace.editorState.getCurrentContent().count,
            with: Array(repeating: "hit", count: 120).joined(separator: " ")
        )
        workspace.searchQueryText = "hit"

        bindings.showInlineSearch()
        XCTAssertTrue(bindings.canToggleSearchHighlightDisplayMode)
        XCTAssertEqual(bindings.searchHighlightToggleTitle, "Show All Highlights")

        bindings.toggleSearchHighlightDisplayMode()
        XCTAssertTrue(workspace.searchShowAllHighlights)
        XCTAssertEqual(bindings.searchHighlightToggleTitle, "Use Capped Highlights")
        XCTAssertTrue(bindings.canToggleSearchHighlightDisplayMode)

        workspace.editorState.replaceText(
            in: 0..<workspace.editorState.getCurrentContent().count,
            with: Array(repeating: "hit", count: workspace.searchHighlightSafetyThreshold + 1).joined(separator: " ")
        )
        bindings.runSearch()

        XCTAssertFalse(workspace.searchShowAllHighlights)
        XCTAssertFalse(bindings.canToggleSearchHighlightDisplayMode)
        XCTAssertEqual(bindings.searchHighlightToggleTitle, "Show All Highlights")
    }

    func testResetSearchHighlightSettingsCommand() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsSearchHighlightReset")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertFalse(bindings.canResetSearchHighlightSettings)
        workspace.updateSearchHighlightCap(180)
        workspace.updateSearchHighlightSafetyThreshold(3_500)
        XCTAssertTrue(bindings.canResetSearchHighlightSettings)

        bindings.resetSearchHighlightSettings()

        XCTAssertEqual(workspace.searchHighlightCap, 100)
        XCTAssertEqual(workspace.searchHighlightSafetyThreshold, 2_000)
        XCTAssertFalse(bindings.canResetSearchHighlightSettings)
    }

    func testReplacePreviewBulkSelectionCommands() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsReplacePreviewBulk")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertFalse(bindings.canBulkSelectReplaceScenes)
        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "one one")
        workspace.searchQueryText = "one"
        bindings.showInlineSearch()
        XCTAssertTrue(bindings.canBulkSelectReplaceScenes)

        bindings.excludeAllReplaceScenes()
        XCTAssertEqual(workspace.selectedReplaceSceneCount, 0)
        bindings.includeAllReplaceScenes()
        XCTAssertGreaterThan(workspace.selectedReplaceSceneCount, 0)
    }

    func testUndoLastReplaceBatchDelegatesToWorkspaceCoordinator() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsReplaceUndo")
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        let chapterId = try XCTUnwrap(workspace.projectManager.getManifest().hierarchy.chapters.first?.id)
        let secondScene = try workspace.projectManager.addScene(to: chapterId, at: nil, title: "Second")

        let firstSceneId = try XCTUnwrap(workspace.editorState.currentSceneId)
        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "color color")
        try workspace.projectManager.saveSceneContent(sceneId: secondScene.id, content: "color")

        workspace.showProjectSearchPanel()
        workspace.searchQueryText = "color"
        workspace.searchReplacementText = "colour"
        workspace.runSearch()
        workspace.setSceneIncludedForReplace(secondScene.id, included: false)

        XCTAssertFalse(bindings.canUndoLastReplaceBatch)
        XCTAssertEqual(bindings.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertTrue(bindings.canUndoLastReplaceBatch)

        XCTAssertEqual(bindings.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertFalse(bindings.canUndoLastReplaceBatch)
        XCTAssertEqual(try workspace.projectManager.loadSceneContent(sceneId: firstSceneId), "color color")
    }

    func testUndoLastReplaceMenuTitleReflectsAvailableDepth() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsReplaceUndoTitle")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertEqual(bindings.replaceUndoMenuTitle, "Undo Last Replace Batch")

        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "alpha alpha")
        workspace.searchQueryText = "alpha"
        workspace.searchReplacementText = "beta"
        bindings.showInlineSearch()
        XCTAssertEqual(bindings.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(bindings.replaceUndoMenuTitle, "Undo Last Replace Batch")

        workspace.searchQueryText = "beta"
        workspace.searchReplacementText = "gamma"
        bindings.runSearch()
        XCTAssertEqual(bindings.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(bindings.replaceUndoMenuTitle, "Undo Last Replace Batch (2 available)")
    }

    func testRedoLastReplaceMenuTitleReflectsAvailableDepth() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "BindingsReplaceRedoTitle")
        let bindings = WorkspaceCommandBindings(workspace: workspace)

        XCTAssertEqual(bindings.replaceRedoMenuTitle, "Redo Last Replace Batch")

        workspace.editorState.replaceText(in: 0..<workspace.editorState.getCurrentContent().count, with: "alpha alpha")
        workspace.searchQueryText = "alpha"
        workspace.searchReplacementText = "beta"
        bindings.showInlineSearch()
        XCTAssertEqual(bindings.replaceAllSearchResults(), "Replaced 2 matches across 1 scenes.")
        XCTAssertEqual(bindings.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertEqual(bindings.replaceRedoMenuTitle, "Redo Last Replace Batch")

        XCTAssertEqual(bindings.redoLastReplaceBatch(), "Redid last replace batch.")
        XCTAssertEqual(bindings.undoLastReplaceBatch(), "Undid last replace batch.")
        XCTAssertEqual(bindings.replaceRedoMenuTitle, "Redo Last Replace Batch")
    }

    func testClearRecentProjectsDelegatesAndUpdatesAvailability() throws {
        let suiteName = "WorkspaceCommandBindingsTests.ClearRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsRecentClearSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertNil(bindings.createProject(named: "BindingsRecentClearA"))
        XCTAssertTrue(bindings.canClearRecentProjects)
        XCTAssertTrue(bindings.canReopenLastProject)

        bindings.clearRecentProjects()

        XCTAssertFalse(bindings.canClearRecentProjects)
        XCTAssertFalse(bindings.canReopenLastProject)
        XCTAssertTrue(bindings.recentProjects.isEmpty)
    }

    func testCleanupMissingRecentProjectsDelegatesToCoordinator() throws {
        let suiteName = "WorkspaceCommandBindingsTests.CleanupMissingRecent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let validManager = FileSystemProjectManager()
        _ = try validManager.createProject(name: "BindingsCleanupValid", at: tempDir)
        let validURL = try XCTUnwrap(validManager.projectRootURL)
        try validManager.closeProject()

        let missingURL = tempDir.appendingPathComponent("BindingsCleanupMissing", isDirectory: true)
        defaults.set([missingURL.path, validURL.path], forKey: "workspace.recentProjects")
        defaults.set(missingURL.path, forKey: "workspace.lastOpenedProjectPath")

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsCleanupSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertTrue(bindings.hasStaleRecentProjects)
        XCTAssertTrue(bindings.recentProjects.contains(where: { $0.name == "BindingsCleanupValid" }))

        bindings.cleanupMissingRecentProjects()

        XCTAssertFalse(bindings.hasStaleRecentProjects)
        XCTAssertTrue(bindings.recentProjects.contains(where: { $0.name == "BindingsCleanupValid" }))
    }

    func testSnapshotAndRestoreRecentProjectsSupportUndoFlow() throws {
        let suiteName = "WorkspaceCommandBindingsTests.RecentUndo.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "BindingsUndoSeed",
            recentProjectStore: defaults
        )
        let bindings = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertNil(bindings.createProject(named: "BindingsUndoA"))
        XCTAssertNil(bindings.createProject(named: "BindingsUndoB"))

        let snapshot = bindings.snapshotRecentProjects()
        bindings.clearRecentProjects()
        XCTAssertTrue(bindings.recentProjects.isEmpty)

        bindings.restoreRecentProjects(from: snapshot)
        let names = bindings.recentProjects.map(\.name)
        XCTAssertTrue(names.contains("BindingsUndoA"))
        XCTAssertTrue(names.contains("BindingsUndoB"))
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
