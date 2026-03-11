import XCTest
@testable import ScribblesNScripts

@MainActor
final class SearchTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testInlineSearchHighlightsAllMatches() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "InlineSearch", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "the cat sat on the mat near the cat")

        let currentScene: UUID? = sceneId
        let engine = IndexedSearchEngine(
            projectManager: manager,
            currentSceneProvider: { currentScene },
            currentChapterProvider: { nil }
        )

        let query = SearchQuery(text: "the", scope: .currentScene)
        let results = engine.search(query: query)

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.first?.matchText.lowercased(), "the")
        XCTAssertEqual(results.first?.matchRange.lowerBound, 0)
    }

    func testProjectWideSearchReturnsGroupedResults() throws {
        let fixture = try makeThreeSceneFixture(name: "ProjectWide")
        let manager = fixture.manager
        let s1 = fixture.sceneIds[0]
        let s3 = fixture.sceneIds[2]

        try manager.saveSceneContent(sceneId: s1, content: "dragon in cave. another dragon appears.")
        try manager.saveSceneContent(sceneId: fixture.sceneIds[1], content: "no match here")
        try manager.saveSceneContent(sceneId: s3, content: "dragon by the river")

        let engine = IndexedSearchEngine(projectManager: manager)
        let results = engine.search(query: SearchQuery(text: "dragon", scope: .entireProject))

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.filter { $0.sceneId == s1 }.count, 2)
        XCTAssertEqual(results.filter { $0.sceneId == s3 }.count, 1)
        XCTAssertTrue(results.allSatisfy { !$0.contextSnippet.isEmpty })
    }

    func testRegexSearchWorks() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Regex", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "Phone: 555-1234 and 555-5678")

        let engine = IndexedSearchEngine(projectManager: manager)
        let query = SearchQuery(text: "\\d{3}-\\d{4}", isRegex: true, scope: .entireProject)
        let matches = engine.search(query: query).map(\.matchText)

        XCTAssertEqual(matches, ["555-1234", "555-5678"])
    }

    func testInvalidRegexShowsError() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "InvalidRegex", at: tempDir)
        let engine = IndexedSearchEngine(projectManager: manager)

        let results = engine.search(query: SearchQuery(text: "[unclosed", isRegex: true, scope: .entireProject))
        XCTAssertTrue(results.isEmpty)
        XCTAssertNotNil(engine.lastErrorMessage)
    }

    func testReplaceAllIsSingleUndoOperation() throws {
        let fixture = try makeThreeSceneFixture(name: "ReplaceUndo")
        let manager = fixture.manager
        let sceneIds = fixture.sceneIds

        try manager.saveSceneContent(sceneId: sceneIds[0], content: "color color")
        try manager.saveSceneContent(sceneId: sceneIds[1], content: "color and color")
        try manager.saveSceneContent(sceneId: sceneIds[2], content: "only one color")

        let engine = IndexedSearchEngine(projectManager: manager)
        let report = try engine.replaceAll(query: SearchQuery(text: "color", scope: .entireProject), replacement: "colour")

        XCTAssertEqual(report.replacementCount, 5)
        XCTAssertEqual(report.scenesAffected, 3)

        try engine.undoLastReplaceAll()

        XCTAssertEqual(try manager.loadSceneContent(sceneId: sceneIds[0]), "color color")
        XCTAssertEqual(try manager.loadSceneContent(sceneId: sceneIds[1]), "color and color")
        XCTAssertEqual(try manager.loadSceneContent(sceneId: sceneIds[2]), "only one color")
    }

    func testReplaceWithRegexCaptureGroups() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "RegexReplace", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "John-Smith")

        let engine = IndexedSearchEngine(projectManager: manager)
        _ = try engine.replaceAll(
            query: SearchQuery(text: "(\\w+)-(\\w+)", isRegex: true, scope: .entireProject),
            replacement: "$2, $1"
        )

        XCTAssertEqual(try manager.loadSceneContent(sceneId: sceneId), "Smith, John")
    }

    func testReplaceAllProgressReportsSceneCompletion() throws {
        let fixture = try makeThreeSceneFixture(name: "ReplaceProgress")
        let manager = fixture.manager
        try manager.saveSceneContent(sceneId: fixture.sceneIds[0], content: "color")
        try manager.saveSceneContent(sceneId: fixture.sceneIds[1], content: "color color")
        try manager.saveSceneContent(sceneId: fixture.sceneIds[2], content: "nomatch")

        let engine = IndexedSearchEngine(projectManager: manager)
        var snapshots: [SearchReplaceProgress] = []

        let report = try engine.replaceAll(
            query: SearchQuery(text: "color", scope: .entireProject),
            replacement: "colour",
            inSceneIDs: fixture.sceneIds
        ) { progress in
            snapshots.append(progress)
        }

        XCTAssertEqual(report.replacementCount, 3)
        XCTAssertEqual(snapshots.first?.completedScenes, 0)
        XCTAssertEqual(snapshots.last?.completedScenes, 3)
        XCTAssertEqual(snapshots.last?.replacementsCompleted, 3)
    }

    func testSearchIndexIncrementalUpdate() async throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Incremental", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "old token")

        let project = try XCTUnwrap(manager.currentProject)
        let engine = IndexedSearchEngine(projectManager: manager)
        await engine.buildIndex(for: project)

        engine.updateIndex(sceneId: sceneId, content: "new token")

        let newResults = engine.search(query: SearchQuery(text: "new", scope: .entireProject))
        let oldResults = engine.search(query: SearchQuery(text: "old", scope: .entireProject))

        XCTAssertEqual(newResults.count, 1)
        XCTAssertTrue(oldResults.isEmpty)
    }

    func testFindByFormattingItalic() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Formatting", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "She was *absolutely* certain about the _plan_.")

        let engine = IndexedSearchEngine(projectManager: manager)
        let query = SearchQuery(text: "", scope: .markdownFormatting(.italic))
        let results = engine.search(query: query).map(\.matchText)

        XCTAssertEqual(results, ["absolutely", "plan"])
    }

    func testSelectedChaptersScopeSearchesOnlyChosenChapterIds() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "SelectedChapters", at: tempDir)
        let firstChapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let secondChapter = try manager.addChapter(to: nil, at: nil, title: "Second")
        let firstSceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let secondScene = try manager.addScene(to: secondChapter.id, at: nil, title: "Second Scene")

        try manager.saveSceneContent(sceneId: firstSceneId, content: "token in first")
        try manager.saveSceneContent(sceneId: secondScene.id, content: "token in second")

        let engine = IndexedSearchEngine(projectManager: manager)
        let results = engine.search(query: SearchQuery(text: "token", scope: .selectedChapters(ids: [secondChapter.id])))

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.sceneId, secondScene.id)
        XCTAssertNotEqual(results.first?.sceneId, firstSceneId)
        XCTAssertNotEqual(firstChapterId, secondChapter.id)
    }

    func testFindByFormattingSupportsAdditionalElements() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "FormattingExtra", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(
            sceneId: sceneId,
            content: """
            ~~cut~~
            `inline`
            ```swift
            let x = 1
            ```
            > quote
            [link](https://example.com)
            [^foot]
            """
        )

        let engine = IndexedSearchEngine(projectManager: manager)
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.strikethrough))).map(\.matchText), ["cut"])
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.inlineCode))).map(\.matchText), ["inline"])
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.codeBlock))).map(\.matchText), ["let x = 1\n"])
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.blockQuote))).map(\.matchText), ["quote"])
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.link))).map(\.matchText), ["link"])
        XCTAssertEqual(engine.search(query: SearchQuery(text: "", scope: .markdownFormatting(.footnote))).map(\.matchText), ["foot"])
    }

    private func makeThreeSceneFixture(name: String) throws -> (manager: FileSystemProjectManager, sceneIds: [UUID]) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)
        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)

        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: chapterId, at: nil, title: "S2")
        let s3 = try manager.addScene(to: chapterId, at: nil, title: "S3")
        return (manager, [s1, s2.id, s3.id])
    }
}
