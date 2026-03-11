import XCTest
@testable import ScribblesNScripts

final class DataModelTests: XCTestCase {
    func testSceneRoundTripsThroughJSON() throws {
        let scene = Scene(
            id: UUID(),
            title: "Opening",
            content: "Hello world",
            synopsis: "Intro",
            status: .firstDraft,
            tags: [UUID()],
            colorLabel: .blue,
            metadata: ["POV": "Alex"],
            sequenceIndex: 0,
            wordCount: 2,
            createdAt: Date(),
            modifiedAt: Date()
        )

        let data = try JSONEncoder().encode(scene)
        let decoded = try JSONDecoder().decode(Scene.self, from: data)

        XCTAssertEqual(decoded.id, scene.id)
        XCTAssertEqual(decoded.title, scene.title)
        XCTAssertEqual(decoded.content, scene.content)
        XCTAssertEqual(decoded.status, scene.status)
        XCTAssertEqual(decoded.wordCount, scene.wordCount)
    }

    func testFullProjectHierarchyRoundTripsThroughCodable() throws {
        let now = Date()
        let scene = Scene(
            id: UUID(),
            title: "Scene 1",
            content: "Text",
            synopsis: "Summary",
            status: .todo,
            tags: [],
            colorLabel: nil,
            metadata: [:],
            sequenceIndex: 0,
            wordCount: 1,
            createdAt: now,
            modifiedAt: now
        )
        let chapter = Chapter(
            id: UUID(),
            title: "Chapter 1",
            synopsis: "",
            scenes: [scene],
            status: .todo,
            sequenceIndex: 0,
            goalWordCount: nil
        )
        let part = Part(
            id: UUID(),
            title: "Part I",
            synopsis: "",
            chapters: [chapter],
            sequenceIndex: 0
        )

        let project = Project(
            id: UUID(),
            name: "Test",
            manuscript: Manuscript(id: UUID(), title: "Test", parts: [part], chapters: [], stagingArea: []),
            settings: ProjectSettings(
                autosaveIntervalSeconds: 30,
                backupIntervalMinutes: 30,
                backupRetentionCount: 20,
                backupLocation: nil,
                customMetadataFields: [],
                customStatusOptions: nil,
                editorFont: "Menlo",
                editorFontSize: 14,
                editorLineHeight: 1.6,
                theme: .system,
                defaultColorLabelNames: [.red: "Red"]
            ),
            tags: [],
            snapshots: [],
            entities: [],
            sources: [],
            notes: [],
            compilePresets: [],
            trash: [],
            createdAt: now,
            modifiedAt: now
        )

        let data = try JSONEncoder().encode(project)
        let decoded = try JSONDecoder().decode(Project.self, from: data)

        XCTAssertEqual(decoded.name, project.name)
        XCTAssertEqual(decoded.manuscript.parts.count, 1)
        XCTAssertEqual(decoded.manuscript.parts.first?.chapters.first?.scenes.count, 1)
    }

    func testContentStatusHasExactlyFiveValues() {
        XCTAssertEqual(ContentStatus.allCases.count, 5)
    }

    func testCustomMetadataFieldOptionsRoundTripThroughCodable() throws {
        let field = CustomMetadataField(id: UUID(), name: "POV", fieldType: .singleSelect, options: ["Alice", "Bob"])

        let data = try JSONEncoder().encode(field)
        let decoded = try JSONDecoder().decode(CustomMetadataField.self, from: data)

        XCTAssertEqual(decoded.name, field.name)
        XCTAssertEqual(decoded.fieldType, .singleSelect)
        XCTAssertEqual(decoded.options, ["Alice", "Bob"])
    }
}
