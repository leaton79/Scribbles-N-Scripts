import XCTest
@testable import Manuscript

@MainActor
final class SplitEditorTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testOpenSplitShowsTwoIndependentPanes() throws {
        let fixture = try makeFixture(name: "OpenSplit")
        let state = fixture.state

        state.openSplit(sceneId: fixture.s7)

        XCTAssertTrue(state.isSplit)
        XCTAssertEqual(state.primarySceneId, fixture.s3)
        XCTAssertEqual(state.secondarySceneId, fixture.s7)
        XCTAssertEqual(state.primaryEditor.currentSceneId, fixture.s3)
        XCTAssertEqual(state.secondaryEditor.currentSceneId, fixture.s7)
    }

    func testEditingInOnePaneDoesNotAffectOther() throws {
        let fixture = try makeFixture(name: "IndependentEdit")
        let manager = fixture.manager
        let state = fixture.state
        state.openSplit(sceneId: fixture.s7)

        state.insertText("Hello", inPane: 1, at: 0)
        try state.secondaryEditor.autosaveIfNeeded(projectManager: manager)

        let primaryContent = try manager.loadSceneContent(sceneId: fixture.s3)
        let secondaryContent = try manager.loadSceneContent(sceneId: fixture.s7)
        XCTAssertEqual(primaryContent, "S3 content")
        XCTAssertEqual(secondaryContent, "HelloS7 content")
    }

    func testActivePaneReceivesKeyboardShortcuts() throws {
        let fixture = try makeFixture(name: "PaneFocus")
        let state = fixture.state
        state.openSplit(sceneId: fixture.s7)
        state.setActivePane(1)

        state.handleFindShortcut()

        XCTAssertTrue(state.isSecondarySearchBarVisible)
        XCTAssertFalse(state.isPrimarySearchBarVisible)
    }

    func testSameSceneInBothPanesSyncsEdits() throws {
        let fixture = try makeFixture(name: "SameScene")
        let state = fixture.state
        state.openSplit(sceneId: fixture.s3)

        state.insertText("Hello ", inPane: 0, at: 0)

        XCTAssertEqual(state.primaryEditor.getCurrentContent(), state.secondaryEditor.getCurrentContent())
    }

    func testCloseSplitPreservesContent() throws {
        let fixture = try makeFixture(name: "CloseSplit")
        let manager = fixture.manager
        let state = fixture.state
        state.openSplit(sceneId: fixture.s7)
        state.setActivePane(1)

        state.insertText("A", inPane: 0, at: 0)
        state.insertText("B", inPane: 1, at: 0)
        state.closeSplit()

        XCTAssertFalse(state.isSplit)
        XCTAssertNil(state.secondarySceneId)
        XCTAssertEqual(state.primarySceneId, fixture.s7)
        XCTAssertEqual(try manager.loadSceneContent(sceneId: fixture.s3), "AS3 content")
        XCTAssertEqual(try manager.loadSceneContent(sceneId: fixture.s7), "BS7 content")
    }

    func testResizeRespectsMinimumWidth() throws {
        let fixture = try makeFixture(name: "Resize")
        let state = fixture.state
        state.openSplit(sceneId: fixture.s7)
        state.orientation = .vertical

        state.updateSplitRatio(dividerPosition: 100, totalLength: 800, minimumPaneLength: 250)

        XCTAssertEqual(state.splitRatio, 0.3125, accuracy: 0.0001)
    }

    func testOpenSplitFallsBackToHorizontalWhenWindowTooNarrow() throws {
        let fixture = try makeFixture(name: "NarrowWindow")
        let state = fixture.state

        let applied = state.openSplit(sceneId: fixture.s7, preferredOrientation: .vertical, windowWidth: 480)

        XCTAssertEqual(applied, .horizontal)
        XCTAssertEqual(state.orientation, .horizontal)
        XCTAssertTrue(state.isSplit)
    }

    func testOpenSplitKeepsVerticalWhenWindowIsWideEnough() throws {
        let fixture = try makeFixture(name: "WideWindow")
        let state = fixture.state

        let applied = state.openSplit(sceneId: fixture.s7, preferredOrientation: .vertical, windowWidth: 900)

        XCTAssertEqual(applied, .vertical)
        XCTAssertEqual(state.orientation, .vertical)
        XCTAssertTrue(state.isSplit)
    }

    private func makeFixture(name: String) throws -> (manager: FileSystemProjectManager, state: SplitEditorState, s3: UUID, s7: UUID) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)
        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)

        let s3 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s7 = try manager.addScene(to: chapterId, at: nil, title: "S7").id

        try manager.saveSceneContent(sceneId: s3, content: "S3 content")
        try manager.saveSceneContent(sceneId: s7, content: "S7 content")

        let state = SplitEditorState(projectManager: manager, primarySceneId: s3)
        return (manager, state, s3, s7)
    }
}
