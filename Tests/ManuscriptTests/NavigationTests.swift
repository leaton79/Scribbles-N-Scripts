import XCTest
@testable import ScribblesNScripts

@MainActor
final class NavigationTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testSidebarDisplaysCorrectHierarchyAndWordCounts() throws {
        let fixture = try makePartedProjectFixture(name: "Hierarchy")
        let nodes = SidebarHierarchyBuilder.build(project: fixture.project)

        XCTAssertEqual(nodes.count, 2)
        XCTAssertEqual(nodes[0].title, "Part1")
        XCTAssertEqual(nodes[0].children.count, 2)
        XCTAssertEqual(nodes[0].children[0].children.count, 2)

        let part1WordCount = nodes[0].wordCount
        let expectedPart1 = fixture.sceneWordCounts["S1", default: 0] + fixture.sceneWordCounts["S2", default: 0] + fixture.sceneWordCounts["S3", default: 0]
        XCTAssertEqual(part1WordCount, expectedPart1)
    }

    func testDragSceneBetweenChaptersAndUndoRestoresOriginalState() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Drag", at: tempDir)

        let ch1Id = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: ch1Id, at: nil, title: "S2")
        let ch2 = try manager.addChapter(to: nil, at: nil, title: "Ch2")
        let s3 = try manager.addScene(to: ch2.id, at: nil, title: "S3")
        _ = s1
        _ = s3

        let nav = NavigationState(projectProvider: { manager.currentProject })
        try nav.performSceneMove(sceneId: s2.id, toChapterId: ch2.id, atIndex: 1, manager: manager)

        let movedManifest = manager.getManifest()
        let movedCh1 = try XCTUnwrap(movedManifest.hierarchy.chapters.first(where: { $0.id == ch1Id }))
        let movedCh2 = try XCTUnwrap(movedManifest.hierarchy.chapters.first(where: { $0.id == ch2.id }))
        XCTAssertEqual(movedCh1.scenes.count, 1)
        XCTAssertEqual(movedCh2.scenes.count, 2)
        XCTAssertEqual(movedCh2.scenes.last, s2.id)

        try nav.undoLastOperation(manager: manager)
        let restored = manager.getManifest()
        let restoredCh1 = try XCTUnwrap(restored.hierarchy.chapters.first(where: { $0.id == ch1Id }))
        let restoredCh2 = try XCTUnwrap(restored.hierarchy.chapters.first(where: { $0.id == ch2.id }))
        XCTAssertEqual(restoredCh1.scenes, [s1, s2.id])
        XCTAssertEqual(restoredCh2.scenes, [s3.id])
    }

    func testQuickJumpFindsTitleFirstThenContent() {
        let s1 = Scene(id: UUID(), title: "Dragon Attack", content: "", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 0, wordCount: 2, createdAt: Date(), modifiedAt: Date())
        let s2 = Scene(id: UUID(), title: "Night Scene", content: "dragon in the mist", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 1, wordCount: 4, createdAt: Date(), modifiedAt: Date())
        let chapter = Chapter(id: UUID(), title: "Ch", synopsis: "", scenes: [s1, s2], status: .todo, sequenceIndex: 0, goalWordCount: nil)
        let project = Project(
            id: UUID(),
            name: "Novel",
            manuscript: Manuscript(id: UUID(), title: "Novel", parts: [], chapters: [chapter], stagingArea: []),
            settings: ProjectSettings(autosaveIntervalSeconds: 30, backupIntervalMinutes: 30, backupRetentionCount: 20, backupLocation: nil, customMetadataFields: [], customStatusOptions: nil, editorFont: "Menlo", editorFontSize: 14, editorLineHeight: 1.6, theme: .system, defaultColorLabelNames: [.red: "Red"]),
            tags: [], snapshots: [], entities: [], sources: [], notes: [], compilePresets: [], trash: [], createdAt: Date(), modifiedAt: Date()
        )

        let index = QuickJumpIndex()
        index.rebuild(project: project, contentProvider: { id in
            if id == s1.id { return s1.content }
            if id == s2.id { return s2.content }
            return nil
        })

        let results = index.search(query: "dragon")
        XCTAssertGreaterThanOrEqual(results.count, 2)
        XCTAssertEqual(results[0].id, s1.id)
        XCTAssertEqual(results[1].id, s2.id)
        XCTAssertTrue(results[0].titleMatch)
        XCTAssertFalse(results[1].titleMatch)
    }

    func testFilterHidesNonMatchingScenes() {
        let scenes = [
            Scene(id: UUID(), title: "A", content: "", synopsis: "", status: .firstDraft, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 0, wordCount: 10, createdAt: Date(), modifiedAt: Date()),
            Scene(id: UUID(), title: "B", content: "", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 1, wordCount: 10, createdAt: Date(), modifiedAt: Date()),
            Scene(id: UUID(), title: "C", content: "", synopsis: "", status: .firstDraft, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 2, wordCount: 10, createdAt: Date(), modifiedAt: Date())
        ]
        let chapter = Chapter(id: UUID(), title: "Ch", synopsis: "", scenes: scenes, status: .todo, sequenceIndex: 0, goalWordCount: nil)
        let project = Project(id: UUID(), name: "P", manuscript: Manuscript(id: UUID(), title: "P", parts: [], chapters: [chapter], stagingArea: []), settings: ProjectSettings(autosaveIntervalSeconds: 30, backupIntervalMinutes: 30, backupRetentionCount: 20, backupLocation: nil, customMetadataFields: [], customStatusOptions: nil, editorFont: "Menlo", editorFontSize: 14, editorLineHeight: 1.6, theme: .system, defaultColorLabelNames: [.red: "Red"]), tags: [], snapshots: [], entities: [], sources: [], notes: [], compilePresets: [], trash: [], createdAt: Date(), modifiedAt: Date())

        let filters = FilterSet(tags: nil, statuses: [.firstDraft], colorLabels: nil, metadataFilters: nil)
        let nodes = SidebarHierarchyBuilder.build(project: project, filters: filters)

        XCTAssertEqual(nodes.first?.children.count, 2)
        XCTAssertEqual(nodes.first?.matchingCount, 2)
        XCTAssertTrue(filters.isActive)
    }

    func testBreadcrumbIsClickable() {
        let scene = Scene(id: UUID(), title: "S5", content: "", synopsis: "", status: .todo, tags: [], colorLabel: nil, metadata: [:], sequenceIndex: 0, wordCount: 1, createdAt: Date(), modifiedAt: Date())
        let chapter = Chapter(id: UUID(), title: "Ch2", synopsis: "", scenes: [scene], status: .todo, sequenceIndex: 0, goalWordCount: nil)
        let part = Part(id: UUID(), title: "Part1", synopsis: "", chapters: [chapter], sequenceIndex: 0)
        let project = Project(id: UUID(), name: "My Novel", manuscript: Manuscript(id: UUID(), title: "My Novel", parts: [part], chapters: [], stagingArea: []), settings: ProjectSettings(autosaveIntervalSeconds: 30, backupIntervalMinutes: 30, backupRetentionCount: 20, backupLocation: nil, customMetadataFields: [], customStatusOptions: nil, editorFont: "Menlo", editorFontSize: 14, editorLineHeight: 1.6, theme: .system, defaultColorLabelNames: [.red: "Red"]), tags: [], snapshots: [], entities: [], sources: [], notes: [], compilePresets: [], trash: [], createdAt: Date(), modifiedAt: Date())

        let nav = NavigationState(projectProvider: { project })
        nav.navigateTo(sceneId: scene.id)

        XCTAssertEqual(nav.breadcrumb.map(\.title), ["My Novel", "Part1", "Ch2", "S5"])

        nav.navigateTo(chapterId: chapter.id)
        XCTAssertEqual(nav.selectedChapterId, chapter.id)
        XCTAssertEqual(nav.selectedSceneId, scene.id)
    }

    func testContextMenuDeleteSendsToTrashAndRestoreBringsBack() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Ctx", at: tempDir)

        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.deleteItem(id: sceneId, type: .scene)

        XCTAssertFalse(manager.getManifest().hierarchy.scenes.contains(where: { $0.id == sceneId }))
        let trashId = try XCTUnwrap(manager.currentProject?.trash.first?.id)

        try manager.restoreFromTrash(trashedItemId: trashId)
        XCTAssertTrue(manager.getManifest().hierarchy.scenes.contains(where: { $0.id == sceneId }))
    }

    func testUndoLastOperationWithEmptyStackIsSafeNoOp() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "UndoNoOp", at: tempDir)
        let nav = NavigationState(projectProvider: { manager.currentProject })
        let before = manager.getManifest()

        try nav.undoLastOperation(manager: manager)

        let after = manager.getManifest()
        XCTAssertEqual(after.hierarchy.parts.count, before.hierarchy.parts.count)
        XCTAssertEqual(after.hierarchy.chapters.count, before.hierarchy.chapters.count)
        XCTAssertEqual(after.hierarchy.scenes.count, before.hierarchy.scenes.count)
        XCTAssertEqual(after.hierarchy.parts.map(\.id), before.hierarchy.parts.map(\.id))
        XCTAssertEqual(after.hierarchy.chapters.map(\.id), before.hierarchy.chapters.map(\.id))
        XCTAssertEqual(after.hierarchy.scenes.map(\.id), before.hierarchy.scenes.map(\.id))
    }

    func testUndoLastOperationRevertsOnlyMostRecentSceneMove() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "UndoLIFO", at: tempDir)

        let baseManifest = manager.getManifest()
        let ch1Id = try XCTUnwrap(baseManifest.hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(baseManifest.hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: ch1Id, at: nil, title: "S2")
        let s3 = try manager.addScene(to: ch1Id, at: nil, title: "S3")

        let ch2 = try manager.addChapter(to: nil, at: nil, title: "Ch2")
        let d1 = try manager.addScene(to: ch2.id, at: nil, title: "D1")
        _ = d1

        let nav = NavigationState(projectProvider: { manager.currentProject })
        try nav.performSceneMove(sceneId: s2.id, toChapterId: ch2.id, atIndex: 1, manager: manager)
        try nav.performSceneMove(sceneId: s3.id, toChapterId: ch2.id, atIndex: 2, manager: manager)

        try nav.undoLastOperation(manager: manager)

        let afterUndo = manager.getManifest()
        let ch1After = try XCTUnwrap(afterUndo.hierarchy.chapters.first(where: { $0.id == ch1Id }))
        let ch2After = try XCTUnwrap(afterUndo.hierarchy.chapters.first(where: { $0.id == ch2.id }))

        XCTAssertEqual(ch1After.scenes, [s1, s3.id])
        XCTAssertEqual(ch2After.scenes, [d1.id, s2.id])
    }

    func testUndoLastOperationRevertsOnlyMostRecentChapterMove() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "UndoChapterLIFO", at: tempDir)

        let part1 = try manager.addPart(at: nil, title: "Part1")
        let part2 = try manager.addPart(at: nil, title: "Part2")
        let chapterA = try manager.addChapter(to: part1.id, at: nil, title: "A")
        let chapterB = try manager.addChapter(to: part1.id, at: nil, title: "B")

        let nav = NavigationState(projectProvider: { manager.currentProject })
        try nav.performChapterMove(chapterId: chapterA.id, toPartId: part2.id, atIndex: 0, manager: manager)
        try nav.performChapterMove(chapterId: chapterB.id, toPartId: part2.id, atIndex: 1, manager: manager)

        try nav.undoLastOperation(manager: manager)

        let afterUndo = manager.getManifest()
        let part1After = try XCTUnwrap(afterUndo.hierarchy.parts.first(where: { $0.id == part1.id }))
        let part2After = try XCTUnwrap(afterUndo.hierarchy.parts.first(where: { $0.id == part2.id }))

        XCTAssertEqual(part1After.chapters, [chapterB.id])
        XCTAssertEqual(part2After.chapters, [chapterA.id])
    }

    func testUndoLastOperationRevertsOnlyMostRecentChapterMoveAcrossPartBoundary() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "UndoChapterBoundary", at: tempDir)

        let defaultTopLevelChapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let part = try manager.addPart(at: nil, title: "PartA")
        let chapterA = try manager.addChapter(to: part.id, at: nil, title: "A")
        let chapterB = try manager.addChapter(to: part.id, at: nil, title: "B")

        let nav = NavigationState(projectProvider: { manager.currentProject })
        try nav.performChapterMove(chapterId: chapterA.id, toPartId: nil, atIndex: 1, manager: manager)
        try nav.performChapterMove(chapterId: chapterB.id, toPartId: nil, atIndex: 2, manager: manager)

        try nav.undoLastOperation(manager: manager)

        let afterUndo = manager.getManifest()
        let chapterAAfter = try XCTUnwrap(afterUndo.hierarchy.chapters.first(where: { $0.id == chapterA.id }))
        let chapterBAfter = try XCTUnwrap(afterUndo.hierarchy.chapters.first(where: { $0.id == chapterB.id }))
        XCTAssertNil(chapterAAfter.parentPartId)
        XCTAssertEqual(chapterBAfter.parentPartId, part.id)

        let partAfter = try XCTUnwrap(afterUndo.hierarchy.parts.first(where: { $0.id == part.id }))
        XCTAssertEqual(partAfter.chapters, [chapterB.id])

        let topLevelIds = Set(afterUndo.hierarchy.chapters.filter { $0.parentPartId == nil }.map(\.id))
        XCTAssertEqual(topLevelIds, Set([defaultTopLevelChapterId, chapterA.id]))
    }

    private func makePartedProjectFixture(name: String) throws -> (project: Project, sceneWordCounts: [String: Int]) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let part1 = try manager.addPart(at: nil, title: "Part1")
        let part2 = try manager.addPart(at: nil, title: "Part2")

        let ch1 = try manager.addChapter(to: part1.id, at: nil, title: "Ch1")
        let ch2 = try manager.addChapter(to: part1.id, at: nil, title: "Ch2")
        let ch3 = try manager.addChapter(to: part2.id, at: nil, title: "Ch3")

        let s1 = try manager.addScene(to: ch1.id, at: nil, title: "S1")
        let s2 = try manager.addScene(to: ch1.id, at: nil, title: "S2")
        let s3 = try manager.addScene(to: ch2.id, at: nil, title: "S3")
        let s4 = try manager.addScene(to: ch3.id, at: nil, title: "S4")

        try manager.saveSceneContent(sceneId: s1.id, content: "one two")
        try manager.saveSceneContent(sceneId: s2.id, content: "one")
        try manager.saveSceneContent(sceneId: s3.id, content: "one two three")
        try manager.saveSceneContent(sceneId: s4.id, content: "one two three four")
        try manager.saveManifest()
        try manager.closeProject()

        let reader = FileSystemProjectManager()
        let project = try reader.openProject(at: tempDir.appendingPathComponent(name))
        return (project, ["S1": 2, "S2": 1, "S3": 3, "S4": 4])
    }
}
