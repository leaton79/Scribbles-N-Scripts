import XCTest
@testable import Manuscript

final class ProjectIOTests: XCTestCase {
    private var tempDir: URL!

    override func setUpWithError() throws {
        tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempDir)
        tempDir = nil
    }

    func testCreateProjectCreatesCorrectDirectoryStructure() throws {
        let manager = FileSystemProjectManager()
        let project = try manager.createProject(name: "Test", at: tempDir)
        let root = tempDir.appendingPathComponent("Test")

        XCTAssertTrue(FileManager.default.fileExists(atPath: root.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("manifest.json").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("content").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("metadata").path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("backups").path))

        let version = try String(contentsOf: root.appendingPathComponent(".manuscript-version"), encoding: .utf8)
        XCTAssertEqual(version.trimmingCharacters(in: .whitespacesAndNewlines), "1.0.0")

        let manifest = manager.getManifest()
        XCTAssertEqual(manifest.hierarchy.chapters.count, 1)
        XCTAssertEqual(manifest.hierarchy.scenes.count, 1)
        XCTAssertEqual(project.name, "Test")
    }

    func testOpenProjectLoadsMetadataButNotContent() throws {
        let writer = FileSystemProjectManager()
        _ = try writer.createProject(name: "Big", at: tempDir)

        let chapterId = try XCTUnwrap(writer.getManifest().hierarchy.chapters.first?.id)
        for i in 0..<49 {
            let scene = try writer.addScene(to: chapterId, at: nil, title: "S\(i)")
            try writer.saveSceneContent(sceneId: scene.id, content: String(repeating: "word ", count: 2000))
        }
        try writer.saveManifest()
        try writer.closeProject()

        let reader = FileSystemProjectManager()
        let start = Date()
        _ = try reader.openProject(at: tempDir.appendingPathComponent("Big"))
        let elapsed = Date().timeIntervalSince(start)

        XCTAssertEqual(reader.getManifest().hierarchy.scenes.count, 50)
        XCTAssertEqual(reader.sceneContentLoadCount, 0)
        XCTAssertLessThanOrEqual(elapsed, 2.0)
    }

    func testMoveSceneUpdatesBothChaptersCorrectly() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Move", at: tempDir)

        let manifest0 = manager.getManifest()
        let chapterA = try XCTUnwrap(manifest0.hierarchy.chapters.first)
        let s1 = try XCTUnwrap(manifest0.hierarchy.scenes.first)
        let s2 = try manager.addScene(to: chapterA.id, at: nil, title: "S2")
        let s3 = try manager.addScene(to: chapterA.id, at: nil, title: "S3")

        let chapterB = try manager.addChapter(to: nil, at: nil, title: "Chapter B")
        let s4 = try manager.addScene(to: chapterB.id, at: nil, title: "S4")
        let s5 = try manager.addScene(to: chapterB.id, at: nil, title: "S5")

        _ = s1
        _ = s3
        _ = s4
        _ = s5

        try manager.moveScene(sceneId: s2.id, toChapterId: chapterB.id, atIndex: 1)

        let manifest = manager.getManifest()
        let finalA = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.id == chapterA.id }))
        let finalB = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.id == chapterB.id }))

        XCTAssertEqual(finalA.scenes.count, 2)
        XCTAssertEqual(finalB.scenes.count, 3)
        XCTAssertEqual(finalB.scenes[1], s2.id)

        let movedScene = try XCTUnwrap(manifest.hierarchy.scenes.first(where: { $0.id == s2.id }))
        XCTAssertEqual(movedScene.sequenceIndex, 1)

        let root = tempDir.appendingPathComponent("Move")
        let oldPath = root.appendingPathComponent("content/ch-\(chapterA.id.uuidString.lowercased())/scene-\(s2.id.uuidString.lowercased()).md")
        let newPath = root.appendingPathComponent("content/ch-\(chapterB.id.uuidString.lowercased())/scene-\(s2.id.uuidString.lowercased()).md")

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldPath.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: newPath.path))
    }

    func testDeleteSceneCreatesTrashEntryAndPreservesFile() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Trash", at: tempDir)

        let manifest = manager.getManifest()
        let chapter = try XCTUnwrap(manifest.hierarchy.chapters.first)
        let scene = try XCTUnwrap(manifest.hierarchy.scenes.first)

        try manager.deleteItem(id: scene.id, type: .scene)

        let updatedManifest = manager.getManifest()
        XCTAssertFalse(updatedManifest.hierarchy.scenes.contains(where: { $0.id == scene.id }))

        let trashItem = try XCTUnwrap(manager.currentProject?.trash.first)
        XCTAssertEqual(trashItem.originalParentId, chapter.id)
        XCTAssertEqual(trashItem.originalIndex, 0)

        let scenePath = tempDir
            .appendingPathComponent("Trash")
            .appendingPathComponent("content/ch-\(chapter.id.uuidString.lowercased())/scene-\(scene.id.uuidString.lowercased()).md")
        XCTAssertTrue(FileManager.default.fileExists(atPath: scenePath.path))
    }

    func testRestoreFromTrashPutsSceneBackInOriginalPosition() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Restore", at: tempDir)

        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        let s2 = try manager.addScene(to: chapterId, at: nil, title: "S2")
        let s3 = try manager.addScene(to: chapterId, at: nil, title: "S3")
        let s4 = try manager.addScene(to: chapterId, at: nil, title: "S4")

        _ = s3
        _ = s4

        try manager.deleteItem(id: s2.id, type: .scene)
        let trashedId = try XCTUnwrap(manager.currentProject?.trash.first?.id)

        try manager.restoreFromTrash(trashedItemId: trashedId)

        let manifest = manager.getManifest()
        let chapter = try XCTUnwrap(manifest.hierarchy.chapters.first(where: { $0.id == chapterId }))
        XCTAssertEqual(chapter.scenes[1], s2.id)
        XCTAssertTrue((manager.currentProject?.trash.isEmpty) == true)
    }

    func testAtomicSaveDoesNotCorruptOnInterruption() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Atomic", at: tempDir)

        let root = tempDir.appendingPathComponent("Atomic")
        let manifestURL = root.appendingPathComponent("manifest.json")
        let before = try Data(contentsOf: manifestURL)

        let chapterId = try XCTUnwrap(manager.getManifest().hierarchy.chapters.first?.id)
        _ = try manager.addScene(to: chapterId, at: nil, title: "Unsaved")

        manager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        }

        XCTAssertThrowsError(try manager.saveManifest())

        let after = try Data(contentsOf: manifestURL)
        XCTAssertEqual(after, before)
    }

    func testAutosaveSkipsWhenNotDirty() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Autosave", at: tempDir)
        let manifestURL = tempDir.appendingPathComponent("Autosave/manifest.json")

        let before = try FileManager.default.attributesOfItem(atPath: manifestURL.path)[.modificationDate] as? Date

        manager.startAutosave(intervalSeconds: 1)
        Thread.sleep(forTimeInterval: 1.3)
        manager.stopAutosave()

        let after = try FileManager.default.attributesOfItem(atPath: manifestURL.path)[.modificationDate] as? Date
        XCTAssertEqual(before, after)
    }

    func testLockFilePreventsConcurrentAccess() throws {
        let first = FileSystemProjectManager()
        _ = try first.createProject(name: "Lock", at: tempDir)

        let second = FileSystemProjectManager()
        XCTAssertThrowsError(try second.openProject(at: tempDir.appendingPathComponent("Lock"))) { error in
            guard case ProjectIOError.concurrentAccess = error else {
                return XCTFail("Expected concurrentAccess error")
            }
        }
    }

    func testCloseProjectRemovesLockFile() throws {
        let manager = FileSystemProjectManager()
        let project = try manager.createProject(name: "CloseLock", at: tempDir)
        let root = tempDir.appendingPathComponent(project.name)
        let lockURL = root.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockURL.path))

        try manager.closeProject()

        XCTAssertFalse(FileManager.default.fileExists(atPath: lockURL.path))
        XCTAssertNil(manager.currentProject)
        XCTAssertNil(manager.projectRootURL)
    }

    func testOpenProjectRejectsMalformedVersionString() throws {
        let manager = FileSystemProjectManager()
        let project = try manager.createProject(name: "BadVersion", at: tempDir)
        let root = tempDir.appendingPathComponent(project.name)
        try "not-semver".write(to: root.appendingPathComponent(".manuscript-version"), atomically: true, encoding: .utf8)
        try manager.closeProject()

        let opener = FileSystemProjectManager()
        XCTAssertThrowsError(try opener.openProject(at: root)) { error in
            guard case let ProjectIOError.incompatibleVersion(projectVersion, supportedVersion) = error else {
                return XCTFail("Expected incompatibleVersion, got \(error)")
            }
            XCTAssertEqual(projectVersion, "not-semver")
            XCTAssertEqual(supportedVersion, "1.0.0")
        }

        XCTAssertNil(opener.currentProject)
        XCTAssertNil(opener.projectRootURL)
        XCTAssertThrowsError(try opener.saveManifest()) { error in
            guard case ProjectIOError.noOpenProject = error else {
                return XCTFail("Expected noOpenProject after failed open")
            }
        }
    }

    func testOpenProjectRejectsHigherMajorVersion() throws {
        let manager = FileSystemProjectManager()
        let project = try manager.createProject(name: "MajorVersion", at: tempDir)
        let root = tempDir.appendingPathComponent(project.name)
        try "2.0.0".write(to: root.appendingPathComponent(".manuscript-version"), atomically: true, encoding: .utf8)
        try manager.closeProject()

        let opener = FileSystemProjectManager()
        XCTAssertThrowsError(try opener.openProject(at: root)) { error in
            guard case let ProjectIOError.incompatibleVersion(projectVersion, supportedVersion) = error else {
                return XCTFail("Expected incompatibleVersion, got \(error)")
            }
            XCTAssertEqual(projectVersion, "2.0.0")
            XCTAssertEqual(supportedVersion, "1.0.0")
        }
    }

    func testOpenProjectRejectsHigherMinorVersionForMigration() throws {
        let manager = FileSystemProjectManager()
        let project = try manager.createProject(name: "MinorVersion", at: tempDir)
        let root = tempDir.appendingPathComponent(project.name)
        try "1.1.0".write(to: root.appendingPathComponent(".manuscript-version"), atomically: true, encoding: .utf8)
        try manager.closeProject()

        let opener = FileSystemProjectManager()
        XCTAssertThrowsError(try opener.openProject(at: root)) { error in
            guard case let ProjectIOError.unsupportedMigration(projectVersion, supportedVersion) = error else {
                return XCTFail("Expected unsupportedMigration, got \(error)")
            }
            XCTAssertEqual(projectVersion, "1.1.0")
            XCTAssertEqual(supportedVersion, "1.0.0")
        }
    }

    func testOpenProjectFailureDuringLateLockCreationLeavesNoOpenState() throws {
        let creator = FileSystemProjectManager()
        let project = try creator.createProject(name: "LateLockFailure", at: tempDir)
        let root = tempDir.appendingPathComponent(project.name)
        let manifestURL = root.appendingPathComponent("manifest.json")

        let chapterId = try XCTUnwrap(creator.getManifest().hierarchy.chapters.first?.id)
        _ = try creator.addScene(to: chapterId, at: nil, title: "Scene 2")
        try creator.saveManifest()
        try creator.closeProject()

        var manifest = try ManifestCoder.read(from: manifestURL)
        let firstId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let secondId = try XCTUnwrap(manifest.hierarchy.scenes.dropFirst().first?.id)
        XCTAssertGreaterThanOrEqual(manifest.hierarchy.scenes.count, 2)
        manifest.hierarchy.scenes[1].id = firstId
        for chapterIndex in manifest.hierarchy.chapters.indices {
            for sceneIndex in manifest.hierarchy.chapters[chapterIndex].scenes.indices where manifest.hierarchy.chapters[chapterIndex].scenes[sceneIndex] == secondId {
                manifest.hierarchy.chapters[chapterIndex].scenes[sceneIndex] = firstId
            }
        }
        let data = try ManifestCoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)

        let opener = FileSystemProjectManager()
        opener.manifestWriteInterceptor = { url, data in
            let lockURL = url.deletingLastPathComponent().appendingPathComponent(".lock")
            try Data("{}".utf8).write(to: lockURL, options: .atomic)
            try data.write(to: url, options: .atomic)
        }

        XCTAssertThrowsError(try opener.openProject(at: root)) { error in
            guard case ProjectIOError.concurrentAccess = error else {
                return XCTFail("Expected concurrentAccess, got \(error)")
            }
        }
        XCTAssertNil(opener.currentProject)
        XCTAssertNil(opener.projectRootURL)
        XCTAssertThrowsError(try opener.saveManifest()) { error in
            guard case ProjectIOError.noOpenProject = error else {
                return XCTFail("Expected noOpenProject after failed open")
            }
        }
    }

    func testCreateProjectFailureDuringLateLockCreationLeavesNoOpenState() throws {
        let manager = FileSystemProjectManager()
        manager.manifestWriteInterceptor = { url, data in
            let lockURL = url.deletingLastPathComponent().appendingPathComponent(".lock")
            try Data("{}".utf8).write(to: lockURL, options: .atomic)
            try data.write(to: url, options: .atomic)
        }

        XCTAssertThrowsError(try manager.createProject(name: "CreateLateLockFailure", at: tempDir)) { error in
            guard case ProjectIOError.concurrentAccess = error else {
                return XCTFail("Expected concurrentAccess, got \(error)")
            }
        }
        XCTAssertNil(manager.currentProject)
        XCTAssertNil(manager.projectRootURL)
        XCTAssertThrowsError(try manager.saveManifest()) { error in
            guard case ProjectIOError.noOpenProject = error else {
                return XCTFail("Expected noOpenProject after failed create")
            }
        }
    }

    func testOpenProjectSwitchesProjectsAndReleasesPreviousLock() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "A", at: tempDir)
        let rootA = tempDir.appendingPathComponent("A")
        let lockA = rootA.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockA.path))

        let creator = FileSystemProjectManager()
        _ = try creator.createProject(name: "B", at: tempDir)
        try creator.closeProject()
        let rootB = tempDir.appendingPathComponent("B")

        _ = try manager.openProject(at: rootB)

        XCTAssertFalse(FileManager.default.fileExists(atPath: lockA.path))
        XCTAssertEqual(manager.projectRootURL, rootB)
    }

    func testOpenLockedProjectDoesNotDropCurrentlyOpenProject() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Current", at: tempDir)
        let currentRoot = tempDir.appendingPathComponent("Current")
        let currentLock = currentRoot.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))

        let holder = FileSystemProjectManager()
        _ = try holder.createProject(name: "LockedTarget", at: tempDir)
        let lockedRoot = tempDir.appendingPathComponent("LockedTarget")

        XCTAssertThrowsError(try manager.openProject(at: lockedRoot)) { error in
            guard case ProjectIOError.concurrentAccess = error else {
                return XCTFail("Expected concurrentAccess, got \(error)")
            }
        }

        XCTAssertEqual(manager.projectRootURL, currentRoot)
        XCTAssertNotNil(manager.currentProject)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))
    }

    func testCreateProjectSwitchesProjectsAndReleasesPreviousLock() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "First", at: tempDir)
        let rootFirst = tempDir.appendingPathComponent("First")
        let lockFirst = rootFirst.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockFirst.path))

        _ = try manager.createProject(name: "Second", at: tempDir)
        let rootSecond = tempDir.appendingPathComponent("Second")
        let lockSecond = rootSecond.appendingPathComponent(".lock")

        XCTAssertFalse(FileManager.default.fileExists(atPath: lockFirst.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: lockSecond.path))
        XCTAssertEqual(manager.projectRootURL, rootSecond)
    }

    func testCreateProjectFailureBeforeSwitchKeepsCurrentProjectOpen() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Current", at: tempDir)
        let currentRoot = tempDir.appendingPathComponent("Current")
        let currentLock = currentRoot.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))

        let conflictingRoot = tempDir.appendingPathComponent("AlreadyExists")
        try Data("occupied".utf8).write(to: conflictingRoot, options: .atomic)

        XCTAssertThrowsError(try manager.createProject(name: "AlreadyExists", at: tempDir))

        XCTAssertEqual(manager.projectRootURL, currentRoot)
        XCTAssertNotNil(manager.currentProject)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))
    }

    func testCreateProjectFailsWhenTargetAlreadyExists() throws {
        let existingRoot = tempDir.appendingPathComponent("Existing")
        try FileManager.default.createDirectory(at: existingRoot, withIntermediateDirectories: true)

        let manager = FileSystemProjectManager()
        XCTAssertThrowsError(try manager.createProject(name: "Existing", at: tempDir)) { error in
            guard case let ProjectIOError.projectAlreadyExists(url) = error else {
                return XCTFail("Expected projectAlreadyExists, got \(error)")
            }
            XCTAssertEqual(url.standardizedFileURL.path, existingRoot.standardizedFileURL.path)
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: existingRoot.appendingPathComponent("manifest.json").path))
    }

    func testCreateProjectExistingTargetKeepsCurrentProjectOpen() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Current", at: tempDir)
        let currentRoot = tempDir.appendingPathComponent("Current")
        let currentLock = currentRoot.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))

        let existingRoot = tempDir.appendingPathComponent("Existing")
        try FileManager.default.createDirectory(at: existingRoot, withIntermediateDirectories: true)

        XCTAssertThrowsError(try manager.createProject(name: "Existing", at: tempDir)) { error in
            guard case ProjectIOError.projectAlreadyExists = error else {
                return XCTFail("Expected projectAlreadyExists, got \(error)")
            }
        }

        XCTAssertEqual(manager.projectRootURL, currentRoot)
        XCTAssertNotNil(manager.currentProject)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))
    }

    func testOpenProjectNormalizationWriteFailureKeepsCurrentProjectOpen() throws {
        let manager = FileSystemProjectManager()
        _ = try manager.createProject(name: "Current", at: tempDir)
        let currentRoot = tempDir.appendingPathComponent("Current")
        let currentLock = currentRoot.appendingPathComponent(".lock")
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))

        let creator = FileSystemProjectManager()
        let targetProject = try creator.createProject(name: "Target", at: tempDir)
        let targetChapterId = try XCTUnwrap(creator.getManifest().hierarchy.chapters.first?.id)
        _ = try creator.addScene(to: targetChapterId, at: nil, title: "Scene 2")
        try creator.saveManifest()
        let targetRoot = tempDir.appendingPathComponent(targetProject.name)
        let targetManifestURL = targetRoot.appendingPathComponent("manifest.json")
        let targetLock = targetRoot.appendingPathComponent(".lock")
        try creator.closeProject()
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetLock.path))

        var manifest = try ManifestCoder.read(from: targetManifestURL)
        let firstId = try XCTUnwrap(manifest.hierarchy.scenes.first?.id)
        let secondId = try XCTUnwrap(manifest.hierarchy.scenes.dropFirst().first?.id)
        manifest.hierarchy.scenes[1].id = firstId
        for chapterIndex in manifest.hierarchy.chapters.indices {
            for sceneIndex in manifest.hierarchy.chapters[chapterIndex].scenes.indices where manifest.hierarchy.chapters[chapterIndex].scenes[sceneIndex] == secondId {
                manifest.hierarchy.chapters[chapterIndex].scenes[sceneIndex] = firstId
            }
        }
        let corruptData = try ManifestCoder.encode(manifest)
        try corruptData.write(to: targetManifestURL, options: .atomic)

        manager.manifestWriteInterceptor = { _, _ in
            throw NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        }

        XCTAssertThrowsError(try manager.openProject(at: targetRoot))
        XCTAssertEqual(manager.projectRootURL, currentRoot)
        XCTAssertNotNil(manager.currentProject)
        XCTAssertTrue(FileManager.default.fileExists(atPath: currentLock.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: targetLock.path))
    }
}
