import XCTest
@testable import Manuscript

@MainActor
final class ModeSwitchTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testSwitchPreservesSceneSelection() throws {
        let f = try makeFixture(name: "Preserve")
        f.linear.goToScene(id: f.s5)

        f.controller.switchTo(.modular)

        XCTAssertEqual(f.controller.activeMode, .modular)
        XCTAssertTrue(f.modular.selectedSceneIds.contains(f.s5))
    }

    func testSwitchTriggersAutosaveOfDirtyContent() throws {
        let f = try makeFixture(name: "Autosave")
        f.linear.goToScene(id: f.s5)
        f.editor.insertText(" edited", at: f.editor.cursorPosition)

        f.controller.switchTo(.modular)

        let persisted = try f.manager.loadSceneContent(sceneId: f.s5)
        XCTAssertTrue(persisted.contains("edited"))
    }

    func testSwitchPerformanceWithinBudget() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Perf", at: tempDir)
        let ch1 = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        for i in 0..<199 {
            _ = try manager.addScene(to: ch1, at: nil, title: "S\(i)")
        }

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(sceneLoader: { id in (try? manager.loadSceneContent(sceneId: id)) ?? "" })
        let linear = LinearModeState(projectManager: manager, navigationState: nav, editorState: editor)
        let modular = ModularModeState(projectManager: manager, navigationState: nav, editorState: editor)
        let controller = ModeController(projectManager: manager, navigationState: nav, editorState: editor, linearState: linear, modularState: modular)

        let start = Date()
        controller.switchMode()
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertLessThanOrEqual(elapsed, 0.2)
    }

    func testReorderInModularReflectedInLinear() throws {
        let f = try makeFixture(name: "Reorder")

        let manifest = f.manager.getManifest()
        let chapter1 = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.title == "Chapter 1" }))
        let s1 = chapter1.scenes[0]
        let s3 = chapter1.scenes[2]

        try f.modular.dragCard(sceneId: s3, toChapterId: chapter1.id, atIndex: 0)
        f.linear.reloadSequence()
        f.controller.switchTo(.linear)

        let reordered = f.linear.orderedSceneIds.prefix(3)
        XCTAssertEqual(Array(reordered), [s3, s1, chapter1.scenes[1]])
    }

    func testStagingSceneSwitchToLinearShowsToast() throws {
        let f = try makeFixture(name: "Staging")

        let stagingScene = try f.manager.addScene(to: f.chapter1, at: nil, title: "Stage Me")
        try f.manager.moveToStaging(sceneId: stagingScene.id)
        f.linear.reloadSequence()
        f.modular.reload()

        f.controller.switchTo(.modular)
        f.modular.selectCard(sceneId: stagingScene.id)
        f.controller.switchTo(.linear)

        XCTAssertEqual(f.editor.currentSceneId, f.linear.orderedSceneIds.first)
        XCTAssertEqual(f.controller.toastMessage, "Staging scenes are not visible in linear mode.")
    }

    private func makeFixture(name: String) throws -> (manager: FileSystemProjectManager, nav: NavigationState, editor: EditorState, linear: LinearModeState, modular: ModularModeState, controller: ModeController, chapter1: UUID, s5: UUID) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let chapter1 = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: chapter1, at: nil, title: "S2")
        let s3 = try manager.addScene(to: chapter1, at: nil, title: "S3")

        let chapter2 = try manager.addChapter(to: nil, at: nil, title: "Chapter 2")
        let s4 = try manager.addScene(to: chapter2.id, at: nil, title: "S4")
        let s5 = try manager.addScene(to: chapter2.id, at: nil, title: "S5")

        try manager.updateChapterMetadata(chapterId: chapter1, updates: ChapterMetadataUpdate(title: "Chapter 1", synopsis: nil, status: nil, goalWordCount: nil))

        try manager.saveSceneContent(sceneId: s1, content: "S1 content")
        try manager.saveSceneContent(sceneId: s2.id, content: "S2 content")
        try manager.saveSceneContent(sceneId: s3.id, content: "S3 content")
        try manager.saveSceneContent(sceneId: s4.id, content: "S4 content")
        try manager.saveSceneContent(sceneId: s5.id, content: "S5 content")

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(sceneLoader: { id in (try? manager.loadSceneContent(sceneId: id)) ?? "" })
        let linear = LinearModeState(projectManager: manager, navigationState: nav, editorState: editor)
        let modular = ModularModeState(projectManager: manager, navigationState: nav, editorState: editor)
        let controller = ModeController(projectManager: manager, navigationState: nav, editorState: editor, linearState: linear, modularState: modular)

        return (manager, nav, editor, linear, modular, controller, chapter1, s5.id)
    }
}
