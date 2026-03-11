import XCTest
@testable import ScribblesNScripts

@MainActor
final class LinearModeTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testLinearModeDisplaysScenesInSequenceOrder() throws {
        let fixture = try makeLinearFixture(name: "Seq")
        let linear = fixture.linear

        let titles = linear.sceneOrderWithTitles().map(\.1)
        XCTAssertEqual(titles, ["S1", "S2", "S3", "S4"])

        let chapterBoundary = try XCTUnwrap(linear.boundaries.first(where: { $0.precedingSceneId == fixture.s2 && $0.followingSceneId == fixture.s3 }))
        XCTAssertTrue(chapterBoundary.chapterBreak)
        XCTAssertEqual(chapterBoundary.chapterTitle, "Chapter 2")
    }

    func testNextSceneNavigationLoadsContentAndUpdatesSidebar() throws {
        let fixture = try makeLinearFixture(name: "Next")
        let linear = fixture.linear

        linear.goToScene(id: fixture.s2)
        fixture.editor.insertText(" edited", at: fixture.editor.cursorPosition)
        linear.goToNextScene()

        XCTAssertEqual(fixture.editor.currentSceneId, fixture.s3)
        XCTAssertEqual(fixture.nav.selectedSceneId, fixture.s3)
        XCTAssertTrue(fixture.editor.getCurrentContent().contains("S3 content"))

        let saved = try fixture.manager.loadSceneContent(sceneId: fixture.s2)
        XCTAssertTrue(saved.contains("edited"))
    }

    func testNewSceneInlineInsertsAtCorrectPosition() throws {
        let fixture = try makeLinearFixture(name: "Insert")
        let linear = fixture.linear

        linear.goToScene(id: fixture.s1)
        try linear.createNewSceneBelowCurrent(title: "New Scene")

        let manifest = fixture.manager.getManifest()
        let chapter1 = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.title == "Chapter 1" }))
        let sceneTitles = chapter1.scenes.compactMap { sid in
            manifest.hierarchy.scenes.first(where: { $0.id == sid })?.title
        }

        XCTAssertEqual(sceneTitles, ["S1", "New Scene", "S2"])
        XCTAssertEqual(fixture.editor.currentSceneId, chapter1.scenes[1])
        XCTAssertEqual(fixture.editor.getCurrentContent(), "")
    }

    func testPreviousSceneAtManuscriptStartIsNoOp() throws {
        let fixture = try makeLinearFixture(name: "Prev")
        let linear = fixture.linear

        linear.goToScene(id: fixture.s1)
        linear.goToPreviousScene()

        XCTAssertEqual(fixture.editor.currentSceneId, fixture.s1)
        XCTAssertTrue(linear.beginningIndicatorVisible)
    }

    func testAdjacentScenesArePreloaded() throws {
        let fixture = try makeLinearFixture(name: "Preload")
        let linear = fixture.linear

        linear.goToScene(id: fixture.s3)

        XCTAssertTrue(linear.preloadedSceneIds.contains(fixture.s2))
        XCTAssertTrue(linear.preloadedSceneIds.contains(fixture.s4))
    }

    private func makeLinearFixture(name: String) throws -> (manager: FileSystemProjectManager, nav: NavigationState, editor: EditorState, linear: LinearModeState, s1: UUID, s2: UUID, s3: UUID, s4: UUID) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let chapter1 = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: chapter1, at: nil, title: "S2")

        try manager.updateChapterMetadata(chapterId: chapter1, updates: ChapterMetadataUpdate(title: "Chapter 1", synopsis: nil, status: nil, goalWordCount: nil))

        let chapter2 = try manager.addChapter(to: nil, at: nil, title: "Chapter 2")
        let s3 = try manager.addScene(to: chapter2.id, at: nil, title: "S3")
        let s4 = try manager.addScene(to: chapter2.id, at: nil, title: "S4")

        try manager.updateSceneMetadata(sceneId: s1, updates: SceneMetadataUpdate(title: "S1", synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: nil))

        try manager.saveSceneContent(sceneId: s1, content: "S1 content")
        try manager.saveSceneContent(sceneId: s2.id, content: "S2 content")
        try manager.saveSceneContent(sceneId: s3.id, content: "S3 content")
        try manager.saveSceneContent(sceneId: s4.id, content: "S4 content")
        try manager.saveManifest()

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(initialContent: "", parser: SimpleMarkdownParser(), sceneLoader: { id in
            (try? manager.loadSceneContent(sceneId: id)) ?? ""
        })
        let linear = LinearModeState(projectManager: manager, navigationState: nav, editorState: editor)

        return (manager, nav, editor, linear, s1, s2.id, s3.id, s4.id)
    }
}
