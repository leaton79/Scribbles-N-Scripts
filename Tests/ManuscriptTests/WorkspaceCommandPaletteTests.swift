import XCTest
@testable import ScribblesNScripts

@MainActor
final class WorkspaceCommandPaletteTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testPaletteIncludesCoreActionsAndNavigationTargets() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "PaletteCore")
        let secondChapter = try workspace.projectManager.addChapter(to: nil, at: nil, title: "Second Chapter")
        let secondScene = try workspace.projectManager.addScene(to: secondChapter.id, at: nil, title: "Second Scene")
        XCTAssertEqual(workspace.saveAppearancePreset(name: "Draft Focus"), "Saved appearance preset “Draft Focus”.")
        let commands = WorkspaceCommandBindings(workspace: workspace)

        let items = WorkspaceCommandPalette.items(workspace: workspace, commands: commands)

        XCTAssertTrue(items.contains(where: { $0.title == "New Project" && $0.action == .createProject }))
        XCTAssertTrue(items.contains(where: { $0.title == "Switch Project" && $0.shortcut == "⇧⌘K" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Project Settings" && $0.action == .showProjectSettings }))
        XCTAssertTrue(items.contains(where: { $0.title == "Import / Export" && $0.action == .showImportExport }))
        XCTAssertTrue(items.contains(where: { $0.title == "Appearance Preset: Draft Focus" }))
        XCTAssertTrue(items.contains(where: { $0.title == "Timeline" && $0.action == .showTimeline }))
        XCTAssertTrue(items.contains(where: { $0.title == "Entities" && $0.action == .showEntities }))
        XCTAssertTrue(items.contains(where: { $0.title == "Sources" && $0.action == .showSources }))
        XCTAssertTrue(items.contains(where: { $0.title == "Notes" && $0.action == .showNotes }))
        XCTAssertTrue(items.contains(where: { $0.title == "Scratchpad" && $0.action == .showScratchpad }))
        XCTAssertTrue(items.contains(where: { $0.title == "New Scene Below" && $0.action == .createSceneBelow }))
        XCTAssertTrue(items.contains(where: { $0.title == "Duplicate Scene" && $0.action == .duplicateSelectedScene }))
        XCTAssertTrue(items.contains(where: { $0.title == "Open in Split" && $0.action == .openSelectionInSplit }))
        XCTAssertTrue(items.contains(where: { $0.title == "Reveal in Sidebar" && $0.action == .revealSelectionInSidebar }))
        XCTAssertTrue(items.contains(where: { $0.title == "Show Corkboard" && $0.action == .showCorkboard }))
        XCTAssertTrue(items.contains(where: { $0.title == "Show Outliner" && $0.action == .showOutliner }))
        XCTAssertTrue(items.contains(where: { $0.title == "Group Modular by Chapter" && $0.action == .modularGroupingChapter }))
        XCTAssertTrue(items.contains(where: { $0.title == "Group Modular Flat" && $0.action == .modularGroupingFlat }))
        XCTAssertTrue(items.contains(where: { $0.title == "Group Modular by Status" && $0.action == .modularGroupingStatus }))
        XCTAssertTrue(items.contains(where: { $0.title == "Collapse All Modular Groups" && $0.action == .collapseAllModularGroups }))
        XCTAssertTrue(items.contains(where: { $0.title == "Expand All Modular Groups" && $0.action == .expandAllModularGroups }))
        XCTAssertTrue(items.contains(where: { $0.title == "Move Scene Up" && $0.action == .moveSelectedSceneUp }))
        XCTAssertTrue(items.contains(where: { $0.title == "Move Scene Down" && $0.action == .moveSelectedSceneDown }))
        XCTAssertTrue(items.contains(where: { $0.title == "Move to Chapter" && $0.action == .moveSelectedSceneToChapter }))
        XCTAssertTrue(items.contains(where: { $0.title == "Send to Staging" && $0.action == .sendSelectedSceneToStaging }))
        XCTAssertTrue(items.contains(where: { $0.title == "Go to Chapter: Second Chapter" && $0.action == .navigateToChapter(secondChapter.id) }))
        XCTAssertTrue(items.contains(where: { $0.title == "Go to Scene: Second Scene" && $0.action == .navigateToScene(secondScene.id) }))
    }

    func testPaletteFilteringMatchesActionsProjectsAndNavigation() throws {
        let suiteName = "WorkspaceCommandPaletteTests.Recent.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let workspace = WorkspaceCoordinator(
            bootstrapRootURL: tempDir,
            bootstrapProjectName: "PaletteFilterSeed",
            recentProjectStore: defaults
        )
        let commands = WorkspaceCommandBindings(workspace: workspace)
        XCTAssertNil(workspace.createAndOpenProject(named: "PaletteAlpha"))
        XCTAssertNil(workspace.createAndOpenProject(named: "PaletteBeta"))
        let alphaURL = tempDir.appendingPathComponent("PaletteAlpha", isDirectory: true)
        XCTAssertNil(workspace.openProject(at: alphaURL))

        let chapter = try workspace.projectManager.addChapter(to: nil, at: nil, title: "Filter Chapter")
        _ = try workspace.projectManager.addScene(to: chapter.id, at: nil, title: "Filter Scene")

        let backupItems = WorkspaceCommandPalette.filteredItems(workspace: workspace, commands: commands, query: "backup")
        XCTAssertTrue(backupItems.contains(where: { $0.title == "Create Backup" }))

        let projectItems = WorkspaceCommandPalette.filteredItems(workspace: workspace, commands: commands, query: "PaletteBeta")
        XCTAssertTrue(projectItems.contains(where: {
            if case let .openRecentProject(url) = $0.action {
                return url.lastPathComponent == "PaletteBeta"
            }
            return false
        }))

        let navigationItems = WorkspaceCommandPalette.filteredItems(workspace: workspace, commands: commands, query: "filter scene")
        XCTAssertEqual(navigationItems.first?.title, "Go to Scene: Filter Scene")
    }

    func testPaletteNavigationHelpersUpdateWorkspaceSelection() throws {
        let workspace = WorkspaceCoordinator(bootstrapRootURL: tempDir, bootstrapProjectName: "PaletteNavigate")
        let chapter = try workspace.projectManager.addChapter(to: nil, at: nil, title: "Dest Chapter")
        let scene = try workspace.projectManager.addScene(to: chapter.id, at: nil, title: "Dest Scene")

        workspace.navigateToChapter(chapter.id)
        XCTAssertEqual(workspace.navigationState.selectedChapterId, chapter.id)

        workspace.navigateToScene(scene.id)
        XCTAssertEqual(workspace.navigationState.selectedSceneId, scene.id)
        XCTAssertEqual(workspace.editorState.currentSceneId, scene.id)
    }
}
