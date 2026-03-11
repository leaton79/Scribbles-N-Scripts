import XCTest
@testable import ScribblesNScripts

@MainActor
final class ModularModeTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testCardsDisplayCorrectMetadata() throws {
        let fixture = try makeFixture(name: "CardMeta")
        let state = fixture.state

        let card = try XCTUnwrap(state.groups.flatMap(\.cards).first(where: { $0.title == "Test" }))
        XCTAssertEqual(card.previewText, "Summary")
        XCTAssertEqual(card.wordCount, 500)
        XCTAssertEqual(card.status, .firstDraft)
        XCTAssertEqual(card.colorLabel, .red)
        XCTAssertEqual(card.tags.map(\.name), ["Action"])
    }

    func testDragCardBetweenChaptersAndUndo() throws {
        let fixture = try makeFixture(name: "DragCard")
        let manager = fixture.manager
        let state = fixture.state

        let manifest = manager.getManifest()
        let ch1 = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.title == "Ch1" }))
        let ch2 = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.title == "Ch2" }))
        let s1 = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.title == "S1" }))

        try state.dragCard(sceneId: s1.id, toChapterId: ch2.id, atIndex: 1)

        let moved = manager.getManifest()
        let movedCh1 = try XCTUnwrap(moved.hierarchy.chapters.first(where: { $0.id == ch1.id }))
        let movedCh2 = try XCTUnwrap(moved.hierarchy.chapters.first(where: { $0.id == ch2.id }))
        let expectedCh1AfterMove = ch1.scenes.filter { $0 != s1.id }
        XCTAssertEqual(movedCh1.scenes, expectedCh1AfterMove)
        XCTAssertEqual(movedCh2.scenes, [ch2.scenes[0], s1.id])

        try state.undoLastOperation()

        let restored = manager.getManifest()
        let restoredCh1 = try XCTUnwrap(restored.hierarchy.chapters.first(where: { $0.id == ch1.id }))
        let restoredCh2 = try XCTUnwrap(restored.hierarchy.chapters.first(where: { $0.id == ch2.id }))
        XCTAssertEqual(restoredCh1.scenes, ch1.scenes)
        XCTAssertEqual(restoredCh2.scenes, ch2.scenes)
    }

    func testFilterByStatusHidesNonMatchingCards() throws {
        let fixture = try makeFixture(name: "Filter")
        let nav = fixture.nav
        let state = fixture.state

        nav.activeFilters = FilterSet(tags: nil, statuses: [.todo], colorLabels: nil, metadataFilters: nil)
        state.reload()

        let visible = state.groups.flatMap(\.cards)
        XCTAssertEqual(visible.count, 3)
        XCTAssertTrue(state.groups.filter { ($0.matchingCount ?? 0) == 0 }.count >= 1)
    }

    func testDoubleClickOpenCardLoadsEditor() throws {
        let fixture = try makeFixture(name: "OpenCard")
        let state = fixture.state

        let target = try XCTUnwrap(state.groups.flatMap(\.cards).first(where: { $0.title == "S3" }))
        state.openCard(sceneId: target.sceneId)

        XCTAssertEqual(fixture.editor.currentSceneId, target.sceneId)
        XCTAssertTrue(fixture.editor.getCurrentContent().contains("S3 content"))
    }

    func testGroupByStatusDragChangesStatus() throws {
        let fixture = try makeFixture(name: "StatusDrag")
        let state = fixture.state

        state.grouping = .byStatus
        state.reload()

        let todoCard = try XCTUnwrap(state.groups.first(where: { $0.title == ContentStatus.todo.rawValue })?.cards.first)
        try state.dragCard(sceneId: todoCard.sceneId, toStatus: .revised)

        let sceneStatus = fixture.manager.getManifest().hierarchy.scenes.first(where: { $0.id == todoCard.sceneId })?.status
        XCTAssertEqual(sceneStatus, .revised)
    }

    func testMultiSelectBulkOperations() throws {
        let fixture = try makeFixture(name: "Bulk")
        let state = fixture.state

        let cards = state.groups.flatMap(\.cards)
        let s1 = try XCTUnwrap(cards.first(where: { $0.title == "S1" }))
        let s3 = try XCTUnwrap(cards.first(where: { $0.title == "S3" }))
        let s2 = try XCTUnwrap(cards.first(where: { $0.title == "S2" }))

        state.selectCard(sceneId: s1.sceneId, multiSelect: true)
        state.selectCard(sceneId: s3.sceneId, multiSelect: true)
        try state.bulkSetStatus(sceneIds: state.selectedSceneIds, status: .final_)

        let manifest = fixture.manager.getManifest()
        let status1 = manifest.hierarchy.scenes.first(where: { $0.id == s1.sceneId })?.status
        let status3 = manifest.hierarchy.scenes.first(where: { $0.id == s3.sceneId })?.status
        let status2 = manifest.hierarchy.scenes.first(where: { $0.id == s2.sceneId })?.status

        XCTAssertEqual(status1, .final_)
        XCTAssertEqual(status3, .final_)
        XCTAssertNotEqual(status2, .final_)
    }

    func testLazyRenderingForLargeProjects() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Lazy", at: tempDir)

        let ch1 = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        for i in 0..<299 {
            _ = try manager.addScene(to: ch1, at: nil, title: "S\(i)")
        }

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(sceneLoader: { id in (try? manager.loadSceneContent(sceneId: id)) ?? "" })
        let state = ModularModeState(projectManager: manager, navigationState: nav, editorState: editor)

        let visible = state.visibleCards(viewportRange: 100..<130)
        XCTAssertLessThan(visible.count, 50)
        XCTAssertLessThan(state.renderedCardCount, 50)
    }

    func testOutlinerSectionsReflectGroupedSceneData() throws {
        let fixture = try makeFixture(name: "Outliner")
        let state = fixture.state

        state.presentationMode = .outliner
        state.reload()

        let chapterSection = try XCTUnwrap(state.outlineSections.first(where: { $0.title == "Ch1" }))
        let row = try XCTUnwrap(chapterSection.rows.first(where: { $0.title == "Test" }))

        XCTAssertEqual(row.synopsis, "Summary")
        XCTAssertEqual(row.chapterTitle, "Ch1")
        XCTAssertEqual(row.status, .firstDraft)
        XCTAssertEqual(row.wordCount, 500)
        XCTAssertEqual(row.tagNames, ["Action"])
    }

    func testGroupingChangesReloadOutlineSections() throws {
        let fixture = try makeFixture(name: "OutlinerGrouping")
        let state = fixture.state

        state.presentationMode = .outliner
        state.grouping = .byStatus

        XCTAssertTrue(state.outlineSections.contains(where: { $0.title == ContentStatus.todo.rawValue }))
        XCTAssertTrue(state.outlineSections.contains(where: { $0.title == ContentStatus.firstDraft.rawValue }))
    }

    private func makeFixture(name: String) throws -> (manager: FileSystemProjectManager, nav: NavigationState, editor: EditorState, state: ModularModeState) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let tags = [Tag(id: UUID(), name: "Action", color: nil)]

        let ch1 = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: ch1, at: nil, title: "S2")
        let ch2 = try manager.addChapter(to: nil, at: nil, title: "Ch2")
        let s3 = try manager.addScene(to: ch2.id, at: nil, title: "S3")

        try manager.updateChapterMetadata(chapterId: ch1, updates: ChapterMetadataUpdate(title: "Ch1", synopsis: nil, status: nil, goalWordCount: nil))

        try manager.updateSceneMetadata(sceneId: s1, updates: SceneMetadataUpdate(title: "S1", synopsis: "", status: .todo, tags: [tags[0].id], colorLabel: nil, metadata: nil))
        try manager.updateSceneMetadata(sceneId: s2.id, updates: SceneMetadataUpdate(title: "S2", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: nil))
        try manager.updateSceneMetadata(sceneId: s3.id, updates: SceneMetadataUpdate(title: "S3", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: nil))

        let special = try manager.addScene(to: ch1, at: 0, title: "Test")
        try manager.updateSceneMetadata(sceneId: special.id, updates: SceneMetadataUpdate(title: "Test", synopsis: "Summary", status: .firstDraft, tags: [tags[0].id], colorLabel: .red, metadata: nil))

        try manager.saveSceneContent(sceneId: s1, content: "S1 content")
        try manager.saveSceneContent(sceneId: s2.id, content: "S2 content")
        try manager.saveSceneContent(sceneId: s3.id, content: "S3 content")
        let longContent = Array(repeating: "word", count: 500).joined(separator: " ")
        try manager.saveSceneContent(sceneId: special.id, content: longContent)
        try manager.saveManifest()

        // Inject tags into in-memory project for resolved card tags.
        if var project = manager.currentProject {
            project.tags = tags
            manager._assignCurrentProjectForTesting(project)
        }

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(sceneLoader: { id in (try? manager.loadSceneContent(sceneId: id)) ?? "" })
        let state = ModularModeState(projectManager: manager, navigationState: nav, editorState: editor)

        return (manager, nav, editor, state)
    }
}
