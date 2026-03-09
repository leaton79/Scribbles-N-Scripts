import XCTest
@testable import Manuscript

@MainActor
final class SnapshotTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testCreateSnapshotCapturesFullState() throws {
        let f = try makeFixture(name: "CreateSnap")
        let snap = try f.snapshots.createSnapshot(name: "v1")

        let listed = f.snapshots.listSnapshots()
        XCTAssertTrue(listed.contains(where: { $0.id == snap.id }))

        let currentWordCount = f.manager.getManifest().hierarchy.scenes.reduce(0) { $0 + $1.wordCount }
        XCTAssertEqual(snap.wordCount, currentWordCount)
    }

    func testDiffDetectsModifiedScene() throws {
        let f = try makeFixture(name: "DiffMod")
        let a = try f.snapshots.createSnapshot(name: "A")
        try f.manager.saveSceneContent(sceneId: f.s1, content: "Hello World")
        try f.manager.saveManifest()
        let b = try f.snapshots.createSnapshot(name: "B")

        let diff = try f.snapshots.diff(snapshotA: a.id, snapshotB: b.id)
        let result = try XCTUnwrap(diff.sceneDiffs.first(where: { $0.sceneId == f.s1 }))
        XCTAssertEqual(result.changeType, .modified)
        XCTAssertTrue((result.lineDiffs ?? []).contains(where: { $0.text.contains("World") }))
    }

    func testDiffDetectsAddedScene() throws {
        let f = try makeFixture(name: "DiffAdd")
        let a = try f.snapshots.createSnapshot(name: "A")
        _ = try f.manager.addScene(to: f.chapterId, at: nil, title: "S3")
        try f.manager.saveManifest()
        let b = try f.snapshots.createSnapshot(name: "B")

        let diff = try f.snapshots.diff(snapshotA: a.id, snapshotB: b.id)
        XCTAssertTrue(diff.sceneDiffs.contains(where: { $0.changeType == .added }))
    }

    func testDiffDetectsRemovedScene() throws {
        let f = try makeFixture(name: "DiffRemove")
        let a = try f.snapshots.createSnapshot(name: "A")
        try f.manager.deleteItem(id: f.s2, type: .scene)
        try f.manager.saveManifest()
        let b = try f.snapshots.createSnapshot(name: "B")

        let diff = try f.snapshots.diff(snapshotA: a.id, snapshotB: b.id)
        XCTAssertTrue(diff.sceneDiffs.contains(where: { $0.sceneId == f.s2 && $0.changeType == .removed }))
    }

    func testRestoreAutoSnapshotsCurrentStateFirst() throws {
        let f = try makeFixture(name: "RestoreAuto")
        let v1 = try f.snapshots.createSnapshot(name: "v1")

        try f.manager.saveSceneContent(sceneId: f.s1, content: "Changed after v1")
        try f.manager.saveManifest()

        try f.snapshots.restore(snapshotId: v1.id)

        let all = f.snapshots.listSnapshots()
        XCTAssertTrue(all.contains(where: { $0.name == "Auto-save before restoring 'v1'" }))

        let restored = try f.manager.loadSceneContent(sceneId: f.s1)
        XCTAssertEqual(restored, "Hello")
    }

    func testRestoreIsReversible() throws {
        let f = try makeFixture(name: "RestoreReverse")
        let v1 = try f.snapshots.createSnapshot(name: "v1")

        try f.manager.saveSceneContent(sceneId: f.s1, content: "Post-v1")
        try f.manager.saveManifest()

        try f.snapshots.restore(snapshotId: v1.id)
        let auto = try XCTUnwrap(f.snapshots.listSnapshots().first(where: { $0.name == "Auto-save before restoring 'v1'" }))
        try f.snapshots.restore(snapshotId: auto.id)

        let roundTrip = try f.manager.loadSceneContent(sceneId: f.s1)
        XCTAssertEqual(roundTrip, "Post-v1")
    }

    func testCreateSnapshotPerformance() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "PerfSnap", at: tempDir)
        let chapter = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)

        for i in 0..<49 {
            let scene = try manager.addScene(to: chapter, at: nil, title: "S\(i)")
            try manager.saveSceneContent(sceneId: scene.id, content: Array(repeating: "word", count: 2000).joined(separator: " "))
        }
        try manager.saveManifest()

        let snapshots = FileSnapshotManager(projectManager: manager)

        let start = Date()
        _ = try snapshots.createSnapshot(name: "perf")
        let elapsed = Date().timeIntervalSince(start)
        XCTAssertLessThanOrEqual(elapsed, 1.0)
    }

    func testCompareWithCurrentIncludesUnsavedChanges() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Unsaved", at: tempDir)
        let sceneId = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        try manager.saveSceneContent(sceneId: sceneId, content: "Base")
        try manager.saveManifest()

        var unsavedValue: String? = nil
        let snapshots = FileSnapshotManager(projectManager: manager, unsavedCurrentContent: { id in
            id == sceneId ? unsavedValue : nil
        })

        let a = try snapshots.createSnapshot(name: "A")
        unsavedValue = "Base plus unsaved"

        let diff = try snapshots.diffWithCurrent(snapshotId: a.id)
        let s1 = try XCTUnwrap(diff.sceneDiffs.first(where: { $0.sceneId == sceneId }))
        XCTAssertEqual(s1.changeType, .modified)
    }

    private func makeFixture(name: String) throws -> (manager: FileSystemProjectManager, snapshots: FileSnapshotManager, chapterId: UUID, s1: UUID, s2: UUID) {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: name, at: tempDir)

        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s1 = try XCTUnwrap(manager.getManifest().hierarchy.scenes.first?.id)
        let s2 = try manager.addScene(to: chapterId, at: nil, title: "S2")

        try manager.saveSceneContent(sceneId: s1, content: "Hello")
        try manager.saveSceneContent(sceneId: s2.id, content: "World")
        try manager.saveManifest()

        let snapshots = FileSnapshotManager(projectManager: manager)
        return (manager, snapshots, chapterId, s1, s2.id)
    }
}
