import XCTest
@testable import Manuscript

@MainActor
final class TagMetadataTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testCreateTagAndAssignToScene() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "TagAssign", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)

        let tagManager = TagManager(projectManager: manager)
        let action = try tagManager.createTag(name: "Action", color: nil)
        try tagManager.addTag(action.id, to: sceneId)

        XCTAssertTrue(tagManager.allTags.contains(where: { $0.name == "Action" }))
        XCTAssertEqual(tagManager.scenesWithTag(action.id), [sceneId])

        let scene = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneId }))
        XCTAssertEqual(scene.tags, [action.id])
    }

    func testDeleteTagRemovesFromAllScenes() throws {
        let fixture = try makeThreeSceneFixture(name: "TagDelete")
        let manager = fixture.manager
        let sceneIds = fixture.sceneIds
        let tagManager = TagManager(projectManager: manager)
        let action = try tagManager.createTag(name: "Action", color: nil)

        for sceneId in sceneIds {
            try tagManager.addTag(action.id, to: sceneId)
        }
        try tagManager.deleteTag(id: action.id)

        XCTAssertFalse(tagManager.allTags.contains(where: { $0.id == action.id }))
        for sceneId in sceneIds {
            let scene = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneId }))
            XCTAssertFalse(scene.tags.contains(action.id))
        }
    }

    func testMergeTagReplacesAllReferences() throws {
        let fixture = try makeThreeSceneFixture(name: "TagMerge")
        let manager = fixture.manager
        let sceneIds = fixture.sceneIds
        let tagManager = TagManager(projectManager: manager)

        let fight = try tagManager.createTag(name: "Fight", color: nil)
        let action = try tagManager.createTag(name: "Action", color: nil)

        try tagManager.addTag(fight.id, to: sceneIds[0])
        try tagManager.addTag(fight.id, to: sceneIds[1])
        try tagManager.addTag(action.id, to: sceneIds[2])

        try tagManager.mergeTag(sourceId: fight.id, targetId: action.id)

        XCTAssertFalse(tagManager.allTags.contains(where: { $0.id == fight.id }))

        let scenes = manager.getManifest().hierarchy.scenes
        let s1 = try XCTUnwrap(scenes.first(where: { $0.id == sceneIds[0] }))
        let s2 = try XCTUnwrap(scenes.first(where: { $0.id == sceneIds[1] }))
        let s3 = try XCTUnwrap(scenes.first(where: { $0.id == sceneIds[2] }))

        XCTAssertEqual(s1.tags, [action.id])
        XCTAssertEqual(s2.tags, [action.id])
        XCTAssertEqual(s3.tags, [action.id])
        XCTAssertEqual(Set(s3.tags).count, 1)
    }

    func testAutocompleteFiltersCorrectly() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Autocomplete", at: tempDir)
        let tagManager = TagManager(projectManager: manager)

        _ = try tagManager.createTag(name: "Action", color: nil)
        _ = try tagManager.createTag(name: "Adventure", color: nil)
        _ = try tagManager.createTag(name: "Romance", color: nil)

        let results = tagManager.autocomplete(prefix: "A").map(\.name)
        XCTAssertEqual(results, ["Action", "Adventure"])
    }

    func testFilterAndComposition() throws {
        let fixture = try makeThreeSceneFixture(name: "FilterCompose")
        let manager = fixture.manager
        let sceneIds = fixture.sceneIds
        let chapterId = fixture.chapterId
        let tagManager = TagManager(projectManager: manager)

        let action = try tagManager.createTag(name: "Action", color: nil)
        let romance = try tagManager.createTag(name: "Romance", color: nil)

        try manager.updateSceneMetadata(
            sceneId: sceneIds[0],
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: .firstDraft, tags: [action.id], colorLabel: nil, metadata: nil)
        )
        try manager.updateSceneMetadata(
            sceneId: sceneIds[1],
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: .firstDraft, tags: [romance.id], colorLabel: nil, metadata: nil)
        )
        try manager.updateSceneMetadata(
            sceneId: sceneIds[2],
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: .revised, tags: [action.id], colorLabel: nil, metadata: nil)
        )

        _ = chapterId
        let project = try XCTUnwrap(manager.currentProject)
        let filters = FilterSet(tags: [action.id], statuses: [.firstDraft], colorLabels: nil, metadataFilters: nil)
        let matching = FilterEngine.matchingSceneIds(in: project, filters: filters)
        XCTAssertEqual(matching, [sceneIds[0]])
    }

    func testCustomSingleSelectFieldConstrainsValues() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "SingleSelect", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let metadataManager = MetadataManager(projectManager: manager)

        let field = CustomMetadataField(id: UUID(), name: "POV", fieldType: .singleSelect)
        try metadataManager.addField(field)
        metadataManager.configureSingleSelectOptions(fieldId: field.id, options: ["Alice", "Bob"])

        XCTAssertThrowsError(try metadataManager.setSceneMetadata(sceneId: sceneId, field: "POV", value: "Charlie"))
    }

    func testColorLabelAppearsInSidebarAndCards() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "ColorLabel", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)

        try manager.updateSceneMetadata(
            sceneId: sceneId,
            updates: SceneMetadataUpdate(title: "S1", synopsis: nil, status: nil, tags: nil, colorLabel: .red, metadata: nil)
        )

        let project = try XCTUnwrap(manager.currentProject)
        let sidebarNodes = SidebarHierarchyBuilder.build(project: project)
        let sidebarSceneNode = try XCTUnwrap(flatten(nodes: sidebarNodes).first(where: { $0.id == sceneId }))
        XCTAssertEqual(sidebarSceneNode.colorLabel, .red)

        let nav = NavigationState(projectProvider: { manager.currentProject })
        let editor = EditorState(sceneLoader: { id in (try? manager.loadSceneContent(sceneId: id)) ?? "" })
        let modular = ModularModeState(projectManager: manager, navigationState: nav, editorState: editor)
        let card = try XCTUnwrap(modular.groups.flatMap(\.cards).first(where: { $0.sceneId == sceneId }))
        XCTAssertEqual(card.colorLabel, .red)
    }

    private func makeThreeSceneFixture(name: String) throws -> (manager: FileSystemProjectManager, chapterId: UUID, sceneIds: [UUID]) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: chapterId, at: nil, title: "S2")
        let s3 = try manager.addScene(to: chapterId, at: nil, title: "S3")
        return (manager, chapterId, [s1, s2.id, s3.id])
    }

    private func flatten(nodes: [SidebarNode]) -> [SidebarNode] {
        nodes + nodes.flatMap { flatten(nodes: $0.children) }
    }
}
