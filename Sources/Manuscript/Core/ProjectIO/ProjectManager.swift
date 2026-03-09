import Foundation
import Darwin

protocol ProjectManager {
    func createProject(name: String, at url: URL) throws -> Project
    func openProject(at url: URL) throws -> Project
    func closeProject() throws

    func saveManifest() throws
    func getManifest() -> Manifest

    func loadSceneContent(sceneId: UUID) throws -> String
    func saveSceneContent(sceneId: UUID, content: String) throws

    func addScene(to chapterId: UUID, at index: Int?, title: String) throws -> Scene
    func addChapter(to partId: UUID?, at index: Int?, title: String) throws -> Chapter
    func addPart(at index: Int?, title: String) throws -> Part
    func moveScene(sceneId: UUID, toChapterId: UUID, atIndex: Int) throws
    func moveChapter(chapterId: UUID, toPartId: UUID?, atIndex: Int) throws
    func moveToStaging(sceneId: UUID) throws
    func deleteItem(id: UUID, type: TrashedItemType) throws
    func restoreFromTrash(trashedItemId: UUID) throws
    func emptyTrash() throws

    func createBackup() throws
    func listBackups() -> [BackupInfo]
    func restoreFromBackup(backupId: String) throws -> Project

    func updateSceneMetadata(sceneId: UUID, updates: SceneMetadataUpdate) throws
    func updateChapterMetadata(chapterId: UUID, updates: ChapterMetadataUpdate) throws

    func startAutosave(intervalSeconds: Int)
    func stopAutosave()

    var currentProject: Project? { get }
    var isDirty: Bool { get }
    var projectRootURL: URL? { get }
}

struct BackupInfo {
    let filename: String
    let date: Date
    let sizeBytes: Int64
}

struct SceneMetadataUpdate {
    var title: String?
    var synopsis: String?
    var status: ContentStatus?
    var tags: [UUID]?
    var colorLabel: ColorLabel?
    var metadata: [String: String]?
}

struct ChapterMetadataUpdate {
    var title: String?
    var synopsis: String?
    var status: ContentStatus?
    var goalWordCount: Int?
}

final class FileSystemProjectManager: ProjectManager {
    private let fileManager: FileManager
    private var projectURL: URL?
    private var manifest: Manifest?
    private var dirtySceneIds = Set<UUID>()
    private var isManifestDirty = false
    private var autosaveTimer: DispatchSourceTimer?
    private let autosaveQueue = DispatchQueue(label: "manuscript.autosave", qos: .utility)

    internal var manifestWriteInterceptor: ((URL, Data) throws -> Void)?
    internal private(set) var sceneContentLoadCount = 0

    private let supportedFormatVersion = ManifestCoder.formatVersion
    private let lockFilename = ".lock"

    private(set) var currentProject: Project?
    var isDirty: Bool { isManifestDirty || !dirtySceneIds.isEmpty }
    var projectRootURL: URL? { projectURL }

    // Test hook for module-level metadata fixtures.
    func _assignCurrentProjectForTesting(_ project: Project) {
        currentProject = project
    }

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func createProject(name: String, at url: URL) throws -> Project {
        let rootURL = url.appendingPathComponent(name, isDirectory: true)
        if fileManager.fileExists(atPath: rootURL.path) {
            throw ProjectIOError.projectAlreadyExists(rootURL)
        }
        let previousProjectURL = projectURL
        let previousManifest = manifest
        let previousProject = currentProject
        let previousDirtySceneIds = dirtySceneIds
        let previousManifestDirty = isManifestDirty
        var createdLock = false

        do {
            try fileManager.createDirectory(at: rootURL, withIntermediateDirectories: true)

            let contentURL = rootURL.appendingPathComponent("content", isDirectory: true)
            let metadataURL = rootURL.appendingPathComponent("metadata", isDirectory: true)
            let snapshotsURL = metadataURL.appendingPathComponent("snapshots", isDirectory: true)
            let baselinesURL = snapshotsURL.appendingPathComponent("baselines", isDirectory: true)

            try fileManager.createDirectory(at: contentURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: contentURL.appendingPathComponent("staging", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: metadataURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: baselinesURL, withIntermediateDirectories: true)
            try fileManager.createDirectory(at: rootURL.appendingPathComponent("notes/attachments", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: rootURL.appendingPathComponent("research", isDirectory: true), withIntermediateDirectories: true)
            try fileManager.createDirectory(at: rootURL.appendingPathComponent("backups", isDirectory: true), withIntermediateDirectories: true)

            let now = Date()
            let projectId = UUID()
            let chapterId = UUID()
            let sceneId = UUID()

            let chapterDirName = "ch-\(chapterId.uuidString.lowercased())"
            let sceneFilename = "scene-\(sceneId.uuidString.lowercased()).md"
            let chapterDirURL = contentURL.appendingPathComponent(chapterDirName, isDirectory: true)
            try fileManager.createDirectory(at: chapterDirURL, withIntermediateDirectories: true)

            let sceneFileURL = chapterDirURL.appendingPathComponent(sceneFilename)
            try writeStringAtomically("", to: sceneFileURL)

            let manifest = Manifest(
                schema: ManifestCoder.schemaVersion,
                formatVersion: ManifestCoder.formatVersion,
                project: ManifestProject(id: projectId, name: name, createdAt: now, modifiedAt: now),
                hierarchy: ManifestHierarchy(
                    parts: [],
                    chapters: [
                        ManifestChapter(
                            id: chapterId,
                            title: "Chapter 1",
                            synopsis: "",
                            status: .todo,
                            sequenceIndex: 0,
                            parentPartId: nil,
                            goalWordCount: nil,
                            scenes: [sceneId]
                        )
                    ],
                    scenes: [
                        ManifestScene(
                            id: sceneId,
                            title: "Untitled Scene",
                            synopsis: "",
                            status: .todo,
                            tags: [],
                            colorLabel: nil,
                            metadata: [:],
                            sequenceIndex: 0,
                            parentChapterId: chapterId,
                            wordCount: 0,
                            filePath: "content/\(chapterDirName)/\(sceneFilename)",
                            createdAt: now,
                            modifiedAt: now
                        )
                    ],
                    stagingScenes: []
                ),
                settings: Self.defaultSettings()
            )

            try saveSupportMetadataFiles(at: rootURL)
            try writeManifest(manifest, to: rootURL.appendingPathComponent("manifest.json"))
            try writeStringAtomically(ManifestCoder.formatVersion, to: rootURL.appendingPathComponent(".manuscript-version"))
            try createLockFileIfNeeded(at: rootURL)
            createdLock = true

            stopAutosave()
            self.projectURL = rootURL
            self.manifest = manifest
            self.currentProject = try makeProject(from: manifest, loadSceneContent: false)
            isManifestDirty = false
            dirtySceneIds.removeAll()

            if let previousProjectURL, previousProjectURL != rootURL {
                removeLockFileIfPresent(at: previousProjectURL)
            }
            return currentProject!
        } catch {
            if createdLock {
                removeLockFileIfPresent(at: rootURL)
            }
            self.projectURL = previousProjectURL
            self.manifest = previousManifest
            self.currentProject = previousProject
            self.dirtySceneIds = previousDirtySceneIds
            self.isManifestDirty = previousManifestDirty
            throw error
        }
    }

    func openProject(at url: URL) throws -> Project {
        let rootURL = url
        if projectURL == rootURL, let currentProject {
            let lockURL = rootURL.appendingPathComponent(lockFilename)
            if !fileManager.fileExists(atPath: lockURL.path) || !lockOwnedByCurrentProcess(at: lockURL) {
                // Same-process reopen should self-heal lock drift/corruption.
                if fileManager.fileExists(atPath: lockURL.path) {
                    try? fileManager.removeItem(at: lockURL)
                }
                try createLockFileIfNeeded(at: rootURL)
            }
            return currentProject
        }
        let lockURL = rootURL.appendingPathComponent(lockFilename)
        if fileManager.fileExists(atPath: lockURL.path) {
            if lockRepresentsActiveSession(at: lockURL) {
                throw ProjectIOError.concurrentAccess(lockFile: lockURL)
            }
            try? fileManager.removeItem(at: lockURL)
        }

        let previousProjectURL = projectURL
        let previousManifest = manifest
        let previousProject = currentProject
        let previousDirtySceneIds = dirtySceneIds
        let previousManifestDirty = isManifestDirty
        var createdTargetLock = false

        do {
            try checkVersionCompatibility(projectRoot: rootURL)

            let manifestURL = rootURL.appendingPathComponent("manifest.json")
            var manifest = try ManifestCoder.read(from: manifestURL)
            let changed = try normalizeDuplicateSceneIDs(manifest: &manifest, rootURL: rootURL)
            try validateHierarchy(manifest)

            if changed {
                try writeManifest(manifest, to: manifestURL)
            }

            try createLockFileIfNeeded(at: rootURL)
            createdTargetLock = true

            stopAutosave()
            self.projectURL = rootURL
            self.manifest = manifest
            self.currentProject = try makeProject(from: manifest, loadSceneContent: false)
            isManifestDirty = false
            dirtySceneIds.removeAll()

            if let previousProjectURL, previousProjectURL != rootURL {
                removeLockFileIfPresent(at: previousProjectURL)
            }

            return currentProject!
        } catch {
            if createdTargetLock {
                removeLockFileIfPresent(at: rootURL)
            }
            self.projectURL = previousProjectURL
            self.manifest = previousManifest
            self.currentProject = previousProject
            self.dirtySceneIds = previousDirtySceneIds
            self.isManifestDirty = previousManifestDirty
            throw error
        }
    }

    func closeProject() throws {
        stopAutosave()
        if let rootURL = projectURL {
            removeLockFileIfPresent(at: rootURL)
        }
        currentProject = nil
        manifest = nil
        projectURL = nil
        dirtySceneIds.removeAll()
        isManifestDirty = false
    }

    func saveManifest() throws {
        guard let rootURL = projectURL, var manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }
        guard fileManager.fileExists(atPath: rootURL.path) else {
            throw ProjectIOError.fileMoved(projectURL: rootURL)
        }

        manifest.project.modifiedAt = Date()
        self.manifest = manifest
        let manifestURL = rootURL.appendingPathComponent("manifest.json")
        try writeManifest(manifest, to: manifestURL)
        currentProject = try makeProject(from: manifest, loadSceneContent: false)
        isManifestDirty = false
    }

    func getManifest() -> Manifest {
        guard let manifest else {
            preconditionFailure("Manifest requested before project is open")
        }
        return manifest
    }

    func loadSceneContent(sceneId: UUID) throws -> String {
        guard let rootURL = projectURL, let manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }

        guard let scene = manifest.hierarchy.scenes.first(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        let sceneURL = rootURL.appendingPathComponent(scene.filePath)
        guard fileManager.fileExists(atPath: sceneURL.path) else {
            throw ProjectIOError.missingSceneFile(sceneId: sceneId, title: scene.title, expectedPath: scene.filePath)
        }

        sceneContentLoadCount += 1
        let data = try Data(contentsOf: sceneURL)
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }
        throw ProjectIOError.missingSceneFile(sceneId: sceneId, title: scene.title, expectedPath: scene.filePath)
    }

    func saveSceneContent(sceneId: UUID, content: String) throws {
        guard let rootURL = projectURL, var manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }

        guard let sceneIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        let scenePath = manifest.hierarchy.scenes[sceneIndex].filePath
        let sceneURL = rootURL.appendingPathComponent(scenePath)
        try fileManager.createDirectory(at: sceneURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeStringAtomically(content, to: sceneURL)

        manifest.hierarchy.scenes[sceneIndex].wordCount = wordCount(for: content)
        manifest.hierarchy.scenes[sceneIndex].modifiedAt = Date()

        self.manifest = manifest
        isManifestDirty = true
        dirtySceneIds.insert(sceneId)
    }

    func addScene(to chapterId: UUID, at index: Int?, title: String) throws -> Scene {
        guard let rootURL = projectURL, var manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }

        guard let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) else {
            throw ProjectIOError.chapterNotFound(chapterId)
        }

        let sceneId = UUID()
        let now = Date()
        let chapterDir = "ch-\(chapterId.uuidString.lowercased())"
        let filename = "scene-\(sceneId.uuidString.lowercased()).md"
        let scenePath = "content/\(chapterDir)/\(filename)"

        let desiredIndex = max(0, min(index ?? manifest.hierarchy.chapters[chapterIndex].scenes.count, manifest.hierarchy.chapters[chapterIndex].scenes.count))
        manifest.hierarchy.chapters[chapterIndex].scenes.insert(sceneId, at: desiredIndex)

        let scene = ManifestScene(
            id: sceneId,
            title: title,
            synopsis: "",
            status: .todo,
            tags: [],
            colorLabel: nil,
            metadata: [:],
            sequenceIndex: desiredIndex,
            parentChapterId: chapterId,
            wordCount: 0,
            filePath: scenePath,
            createdAt: now,
            modifiedAt: now
        )
        manifest.hierarchy.scenes.append(scene)
        recalculateSceneSequenceIndices(in: &manifest, chapterId: chapterId)

        let sceneURL = rootURL.appendingPathComponent(scenePath)
        try fileManager.createDirectory(at: sceneURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try writeStringAtomically("", to: sceneURL)

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)

        return Scene(
            id: sceneId,
            title: title,
            content: "",
            synopsis: "",
            status: .todo,
            tags: [],
            colorLabel: nil,
            metadata: [:],
            sequenceIndex: desiredIndex,
            wordCount: 0,
            createdAt: now,
            modifiedAt: now
        )
    }

    func addChapter(to partId: UUID?, at index: Int?, title: String) throws -> Chapter {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }

        if let partId, manifest.hierarchy.parts.contains(where: { $0.id == partId }) == false {
            throw ProjectIOError.partNotFound(partId)
        }

        let chapterId = UUID()
        let chapter = ManifestChapter(
            id: chapterId,
            title: title,
            synopsis: "",
            status: .todo,
            sequenceIndex: 0,
            parentPartId: partId,
            goalWordCount: nil,
            scenes: []
        )
        manifest.hierarchy.chapters.append(chapter)

        if let partIndex = manifest.hierarchy.parts.firstIndex(where: { $0.id == partId }) {
            let insertAt = max(0, min(index ?? manifest.hierarchy.parts[partIndex].chapters.count, manifest.hierarchy.parts[partIndex].chapters.count))
            manifest.hierarchy.parts[partIndex].chapters.insert(chapterId, at: insertAt)
            recalculateChapterIndices(in: &manifest, partId: partId)
        } else {
            recalculateChapterIndices(in: &manifest, partId: nil)
        }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)

        return Chapter(
            id: chapterId,
            title: title,
            synopsis: "",
            scenes: [],
            status: .todo,
            sequenceIndex: manifest.hierarchy.chapters.first(where: { $0.id == chapterId })?.sequenceIndex ?? 0,
            goalWordCount: nil
        )
    }

    func addPart(at index: Int?, title: String) throws -> Part {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }

        let partId = UUID()
        let part = ManifestPart(
            id: partId,
            title: title,
            synopsis: "",
            sequenceIndex: 0,
            chapters: []
        )

        let insertAt = max(0, min(index ?? manifest.hierarchy.parts.count, manifest.hierarchy.parts.count))
        manifest.hierarchy.parts.insert(part, at: insertAt)
        for i in manifest.hierarchy.parts.indices {
            manifest.hierarchy.parts[i].sequenceIndex = i
        }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)

        return Part(id: partId, title: title, synopsis: "", chapters: [], sequenceIndex: insertAt)
    }

    func moveScene(sceneId: UUID, toChapterId: UUID, atIndex: Int) throws {
        guard let rootURL = projectURL, var manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }

        guard let destinationChapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == toChapterId }) else {
            throw ProjectIOError.chapterNotFound(toChapterId)
        }
        guard let sceneManifestIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        guard let sourceChapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.scenes.contains(sceneId) }) else {
            throw ProjectIOError.invalidHierarchy(details: "Scene has no parent chapter")
        }

        let sourceChapterId = manifest.hierarchy.chapters[sourceChapterIndex].id
        let oldIndex = manifest.hierarchy.chapters[sourceChapterIndex].scenes.firstIndex(of: sceneId) ?? 0
        let normalizedTarget = max(0, min(atIndex, manifest.hierarchy.chapters[destinationChapterIndex].scenes.count))

        if sourceChapterId == toChapterId && oldIndex == normalizedTarget {
            return
        }

        manifest.hierarchy.chapters[sourceChapterIndex].scenes.removeAll { $0 == sceneId }
        let adjustedTarget: Int
        if sourceChapterId == toChapterId && oldIndex < normalizedTarget {
            adjustedTarget = normalizedTarget - 1
        } else {
            adjustedTarget = normalizedTarget
        }
        manifest.hierarchy.chapters[destinationChapterIndex].scenes.insert(sceneId, at: adjustedTarget)
        manifest.hierarchy.scenes[sceneManifestIndex].parentChapterId = toChapterId

        let oldPath = manifest.hierarchy.scenes[sceneManifestIndex].filePath
        let newChapterFolder = "ch-\(toChapterId.uuidString.lowercased())"
        let filename = "scene-\(sceneId.uuidString.lowercased()).md"
        let newPath = "content/\(newChapterFolder)/\(filename)"
        manifest.hierarchy.scenes[sceneManifestIndex].filePath = newPath

        recalculateSceneSequenceIndices(in: &manifest, chapterId: sourceChapterId)
        recalculateSceneSequenceIndices(in: &manifest, chapterId: toChapterId)

        let oldURL = rootURL.appendingPathComponent(oldPath)
        let newURL = rootURL.appendingPathComponent(newPath)
        if oldURL.path != newURL.path {
            try fileManager.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fileManager.fileExists(atPath: oldURL.path) {
                if fileManager.fileExists(atPath: newURL.path) {
                    try fileManager.removeItem(at: newURL)
                }
                try fileManager.moveItem(at: oldURL, to: newURL)
            }
        }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)
    }

    func moveChapter(chapterId: UUID, toPartId: UUID?, atIndex: Int) throws {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }
        guard let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) else {
            throw ProjectIOError.chapterNotFound(chapterId)
        }

        let currentParent = manifest.hierarchy.chapters[chapterIndex].parentPartId
        if currentParent == toPartId {
            return
        }

        if let currentParent,
           let partIndex = manifest.hierarchy.parts.firstIndex(where: { $0.id == currentParent }) {
            manifest.hierarchy.parts[partIndex].chapters.removeAll { $0 == chapterId }
        }

        if let targetPart = toPartId {
            guard let targetPartIndex = manifest.hierarchy.parts.firstIndex(where: { $0.id == targetPart }) else {
                throw ProjectIOError.partNotFound(targetPart)
            }
            let index = max(0, min(atIndex, manifest.hierarchy.parts[targetPartIndex].chapters.count))
            manifest.hierarchy.parts[targetPartIndex].chapters.insert(chapterId, at: index)
        }

        manifest.hierarchy.chapters[chapterIndex].parentPartId = toPartId
        recalculateChapterIndices(in: &manifest, partId: currentParent)
        recalculateChapterIndices(in: &manifest, partId: toPartId)

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)
    }

    func moveToStaging(sceneId: UUID) throws {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }
        guard let sceneIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        if let parentChapterId = manifest.hierarchy.scenes[sceneIndex].parentChapterId,
           let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == parentChapterId }) {
            manifest.hierarchy.chapters[chapterIndex].scenes.removeAll { $0 == sceneId }
            recalculateSceneSequenceIndices(in: &manifest, chapterId: parentChapterId)
        }

        manifest.hierarchy.scenes[sceneIndex].parentChapterId = nil
        if !manifest.hierarchy.stagingScenes.contains(sceneId) {
            manifest.hierarchy.stagingScenes.append(sceneId)
        }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false)
    }

    func deleteItem(id: UUID, type: TrashedItemType) throws {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }

        switch type {
        case .scene:
            guard let sceneIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == id }) else {
                throw ProjectIOError.sceneNotFound(id)
            }

            let sceneMeta = manifest.hierarchy.scenes[sceneIndex]
            var originalIndex = 0
            if let parentChapterId = sceneMeta.parentChapterId,
               let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == parentChapterId }),
               let idx = manifest.hierarchy.chapters[chapterIndex].scenes.firstIndex(of: id) {
                originalIndex = idx
                manifest.hierarchy.chapters[chapterIndex].scenes.remove(at: idx)
                recalculateSceneSequenceIndices(in: &manifest, chapterId: parentChapterId)
            }
            if let stagingIndex = manifest.hierarchy.stagingScenes.firstIndex(of: id) {
                originalIndex = stagingIndex
                manifest.hierarchy.stagingScenes.remove(at: stagingIndex)
            }

            let trashed = TrashedItem(
                id: UUID(),
                originalType: .scene,
                originalParentId: sceneMeta.parentChapterId,
                originalIndex: originalIndex,
                content: .scene(Scene(
                    id: sceneMeta.id,
                    title: sceneMeta.title,
                    content: "",
                    synopsis: sceneMeta.synopsis,
                    status: sceneMeta.status,
                    tags: sceneMeta.tags,
                    colorLabel: sceneMeta.colorLabel,
                    metadata: sceneMeta.metadata,
                    sequenceIndex: sceneMeta.sequenceIndex,
                    wordCount: sceneMeta.wordCount,
                    createdAt: sceneMeta.createdAt,
                    modifiedAt: sceneMeta.modifiedAt
                )),
                trashedAt: Date()
            )
            manifest.hierarchy.scenes.remove(at: sceneIndex)
            currentProject?.trash.append(trashed)

        case .chapter:
            guard let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == id }) else {
                throw ProjectIOError.chapterNotFound(id)
            }
            let chapterMeta = manifest.hierarchy.chapters[chapterIndex]
            let scenes = chapterMeta.scenes.compactMap { sid -> Scene? in
                guard let s = manifest.hierarchy.scenes.first(where: { $0.id == sid }) else { return nil }
                return Scene(id: s.id, title: s.title, content: "", synopsis: s.synopsis, status: s.status, tags: s.tags, colorLabel: s.colorLabel, metadata: s.metadata, sequenceIndex: s.sequenceIndex, wordCount: s.wordCount, createdAt: s.createdAt, modifiedAt: s.modifiedAt)
            }
            let chapter = Chapter(id: chapterMeta.id, title: chapterMeta.title, synopsis: chapterMeta.synopsis, scenes: scenes, status: chapterMeta.status, sequenceIndex: chapterMeta.sequenceIndex, goalWordCount: chapterMeta.goalWordCount)
            let trash = TrashedItem(id: UUID(), originalType: .chapter, originalParentId: chapterMeta.parentPartId, originalIndex: chapterMeta.sequenceIndex, content: .chapter(chapter), trashedAt: Date())
            currentProject?.trash.append(trash)
            manifest.hierarchy.chapters.remove(at: chapterIndex)

        case .part:
            guard let partIndex = manifest.hierarchy.parts.firstIndex(where: { $0.id == id }) else {
                throw ProjectIOError.partNotFound(id)
            }
            let partMeta = manifest.hierarchy.parts[partIndex]
            let chapters = partMeta.chapters.compactMap { cid -> Chapter? in
                guard let chapterMeta = manifest.hierarchy.chapters.first(where: { $0.id == cid }) else { return nil }
                return Chapter(id: chapterMeta.id, title: chapterMeta.title, synopsis: chapterMeta.synopsis, scenes: [], status: chapterMeta.status, sequenceIndex: chapterMeta.sequenceIndex, goalWordCount: chapterMeta.goalWordCount)
            }
            let part = Part(id: partMeta.id, title: partMeta.title, synopsis: partMeta.synopsis, chapters: chapters, sequenceIndex: partMeta.sequenceIndex)
            let trash = TrashedItem(id: UUID(), originalType: .part, originalParentId: nil, originalIndex: partMeta.sequenceIndex, content: .part(part), trashedAt: Date())
            currentProject?.trash.append(trash)
            manifest.hierarchy.parts.remove(at: partIndex)
        }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false, existingTrash: currentProject?.trash ?? [])
    }

    func restoreFromTrash(trashedItemId: UUID) throws {
        guard var project = currentProject, var manifest = manifest else {
            throw ProjectIOError.noOpenProject
        }

        guard let trashIndex = project.trash.firstIndex(where: { $0.id == trashedItemId }) else {
            throw ProjectIOError.trashItemNotFound(trashedItemId)
        }
        let item = project.trash.remove(at: trashIndex)

        switch item.content {
        case let .scene(scene):
            let chapterId = item.originalParentId
            let insertIndex: Int
            if let chapterId,
               let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) {
                insertIndex = max(0, min(item.originalIndex, manifest.hierarchy.chapters[chapterIndex].scenes.count))
                manifest.hierarchy.chapters[chapterIndex].scenes.insert(scene.id, at: insertIndex)
            } else {
                insertIndex = max(0, min(item.originalIndex, manifest.hierarchy.stagingScenes.count))
                manifest.hierarchy.stagingScenes.insert(scene.id, at: insertIndex)
            }

            manifest.hierarchy.scenes.append(
                ManifestScene(
                    id: scene.id,
                    title: scene.title,
                    synopsis: scene.synopsis,
                    status: scene.status,
                    tags: scene.tags,
                    colorLabel: scene.colorLabel,
                    metadata: scene.metadata,
                    sequenceIndex: insertIndex,
                    parentChapterId: chapterId,
                    wordCount: scene.wordCount,
                    filePath: sceneFilePath(sceneId: scene.id, chapterId: chapterId),
                    createdAt: scene.createdAt,
                    modifiedAt: scene.modifiedAt
                )
            )
            if let chapterId {
                recalculateSceneSequenceIndices(in: &manifest, chapterId: chapterId)
            }

        case let .chapter(chapter):
            manifest.hierarchy.chapters.append(
                ManifestChapter(
                    id: chapter.id,
                    title: chapter.title,
                    synopsis: chapter.synopsis,
                    status: chapter.status,
                    sequenceIndex: item.originalIndex,
                    parentPartId: item.originalParentId,
                    goalWordCount: chapter.goalWordCount,
                    scenes: chapter.scenes.map(\.id)
                )
            )

        case let .part(part):
            manifest.hierarchy.parts.append(
                ManifestPart(
                    id: part.id,
                    title: part.title,
                    synopsis: part.synopsis,
                    sequenceIndex: item.originalIndex,
                    chapters: part.chapters.map(\.id)
                )
            )
        }

        self.manifest = manifest
        currentProject = try makeProject(from: manifest, loadSceneContent: false, existingTrash: project.trash)
        isManifestDirty = true
    }

    func emptyTrash() throws {
        guard let rootURL = projectURL else { throw ProjectIOError.noOpenProject }
        guard var project = currentProject else { throw ProjectIOError.noOpenProject }

        for item in project.trash {
            if case let .scene(scene) = item.content,
               let manifestScene = manifest?.hierarchy.scenes.first(where: { $0.id == scene.id }) {
                let fileURL = rootURL.appendingPathComponent(manifestScene.filePath)
                try? fileManager.removeItem(at: fileURL)
            }
        }

        project.trash.removeAll()
        currentProject = project
        isManifestDirty = true
    }

    func createBackup() throws {
        guard let rootURL = projectURL, let project = currentProject else {
            throw ProjectIOError.noOpenProject
        }
        _ = try BackupManager.createBackup(projectURL: rootURL, retentionCount: project.settings.backupRetentionCount)
    }

    func listBackups() -> [BackupInfo] {
        guard let rootURL = projectURL else { return [] }
        return BackupManager.listBackups(projectURL: rootURL)
    }

    func restoreFromBackup(backupId: String) throws -> Project {
        guard let rootURL = projectURL else { throw ProjectIOError.noOpenProject }
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? fileManager.removeItem(at: tempURL) }

        let restoredURL = try BackupManager.restoreBackup(projectURL: rootURL, backupFilename: backupId, to: tempURL)
        let restoredManifest = try ManifestCoder.read(from: restoredURL.appendingPathComponent("manifest.json"))
        return try makeProject(from: restoredManifest, loadSceneContent: false)
    }

    func updateSceneMetadata(sceneId: UUID, updates: SceneMetadataUpdate) throws {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }
        guard let sceneIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        if let title = updates.title { manifest.hierarchy.scenes[sceneIndex].title = title }
        if let synopsis = updates.synopsis { manifest.hierarchy.scenes[sceneIndex].synopsis = synopsis }
        if let status = updates.status { manifest.hierarchy.scenes[sceneIndex].status = status }
        if let tags = updates.tags { manifest.hierarchy.scenes[sceneIndex].tags = tags }
        if let colorLabel = updates.colorLabel { manifest.hierarchy.scenes[sceneIndex].colorLabel = colorLabel }
        if let metadata = updates.metadata { manifest.hierarchy.scenes[sceneIndex].metadata = metadata }
        manifest.hierarchy.scenes[sceneIndex].modifiedAt = Date()

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false, existingTrash: currentProject?.trash ?? [])
    }

    func updateChapterMetadata(chapterId: UUID, updates: ChapterMetadataUpdate) throws {
        guard var manifest = manifest else { throw ProjectIOError.noOpenProject }
        guard let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) else {
            throw ProjectIOError.chapterNotFound(chapterId)
        }

        if let title = updates.title { manifest.hierarchy.chapters[chapterIndex].title = title }
        if let synopsis = updates.synopsis { manifest.hierarchy.chapters[chapterIndex].synopsis = synopsis }
        if let status = updates.status { manifest.hierarchy.chapters[chapterIndex].status = status }
        if let goalWordCount = updates.goalWordCount { manifest.hierarchy.chapters[chapterIndex].goalWordCount = goalWordCount }

        self.manifest = manifest
        isManifestDirty = true
        currentProject = try makeProject(from: manifest, loadSceneContent: false, existingTrash: currentProject?.trash ?? [])
    }

    func startAutosave(intervalSeconds: Int) {
        stopAutosave()
        let timer = DispatchSource.makeTimerSource(queue: autosaveQueue)
        timer.schedule(deadline: .now() + .seconds(intervalSeconds), repeating: .seconds(intervalSeconds))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            guard self.isDirty else { return }
            try? self.saveManifest()
            self.dirtySceneIds.removeAll()
        }
        autosaveTimer = timer
        timer.resume()
    }

    func stopAutosave() {
        autosaveTimer?.cancel()
        autosaveTimer = nil
    }

    private func writeManifest(_ manifest: Manifest, to url: URL) throws {
        let data = try ManifestCoder.encode(manifest)
        if let interceptor = manifestWriteInterceptor {
            try interceptor(url, data)
        } else {
            try data.write(to: url, options: .atomic)
        }
    }

    private func saveSupportMetadataFiles(at projectURL: URL) throws {
        let metadataURL = projectURL.appendingPathComponent("metadata", isDirectory: true)
        try writeStringAtomically("[]", to: metadataURL.appendingPathComponent("tags.json"))
        try writeStringAtomically("[]", to: metadataURL.appendingPathComponent("entities.json"))
        try writeStringAtomically("[]", to: metadataURL.appendingPathComponent("sources.json"))
        try writeStringAtomically("[]", to: metadataURL.appendingPathComponent("timeline.json"))
        try writeStringAtomically("[]", to: metadataURL.appendingPathComponent("presets.json"))
    }

    private func createLockFileIfNeeded(at rootURL: URL) throws {
        let lockURL = rootURL.appendingPathComponent(lockFilename)
        if fileManager.fileExists(atPath: lockURL.path) {
            if lockRepresentsActiveSession(at: lockURL) {
                throw ProjectIOError.concurrentAccess(lockFile: lockURL)
            }
            try? fileManager.removeItem(at: lockURL)
        }

        let lockPayload = [
            "pid": String(ProcessInfo.processInfo.processIdentifier),
            "openedAt": ISO8601DateFormatter().string(from: Date())
        ]
        let lockData = try JSONSerialization.data(withJSONObject: lockPayload, options: [.sortedKeys])
        try lockData.write(to: lockURL, options: .atomic)
    }

    private func lockRepresentsActiveSession(at lockURL: URL) -> Bool {
        let pidInfo = lockPIDInfo(at: lockURL)
        guard pidInfo.readable else { return true }
        guard let pidValue = pidInfo.pid, pidValue > 0 else { return false }
        let check = kill(pid_t(pidValue), 0)
        if check == 0 { return true }
        return errno != ESRCH
    }

    private func removeLockFileIfPresent(at rootURL: URL) {
        let lockURL = rootURL.appendingPathComponent(lockFilename)
        if fileManager.fileExists(atPath: lockURL.path) {
            if lockOwnedByCurrentProcess(at: lockURL) {
                try? fileManager.removeItem(at: lockURL)
            }
        }
    }

    private func lockPIDInfo(at lockURL: URL) -> (readable: Bool, pid: Int?) {
        guard let data = try? Data(contentsOf: lockURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (false, nil)
        }

        if let pidString = object["pid"] as? String {
            return (true, Int(pidString))
        }
        if let pidNumber = object["pid"] as? NSNumber {
            return (true, pidNumber.intValue)
        }
        return (true, nil)
    }

    private func lockOwnedByCurrentProcess(at lockURL: URL) -> Bool {
        let pidInfo = lockPIDInfo(at: lockURL)
        guard pidInfo.readable, let pid = pidInfo.pid else {
            // Preserve unknown lock owners to avoid deleting another process's lock.
            return false
        }
        return pid == ProcessInfo.processInfo.processIdentifier
    }

    private func checkVersionCompatibility(projectRoot: URL) throws {
        let versionFile = projectRoot.appendingPathComponent(".manuscript-version")
        let projectVersion = (try? String(contentsOf: versionFile, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines))
            ?? ManifestCoder.formatVersion

        guard let supported = parseSemver(supportedFormatVersion), let candidate = parseSemver(projectVersion) else {
            throw ProjectIOError.incompatibleVersion(projectVersion: projectVersion, supportedVersion: supportedFormatVersion)
        }
        if candidate.major > supported.major {
            throw ProjectIOError.incompatibleVersion(projectVersion: projectVersion, supportedVersion: supportedFormatVersion)
        }
        if candidate.major == supported.major, candidate.minor > supported.minor {
            throw ProjectIOError.unsupportedMigration(projectVersion: projectVersion, supportedVersion: supportedFormatVersion)
        }
    }

    private func parseSemver(_ value: String) -> (major: Int, minor: Int, patch: Int)? {
        let parts = value.split(separator: ".")
        guard parts.count == 3 else { return nil }
        let parsed = parts.compactMap { Int($0) }
        guard parsed.count == 3, parsed.allSatisfy({ $0 >= 0 }) else { return nil }
        return (
            parsed[0],
            parsed[1],
            parsed[2]
        )
    }

    private func validateHierarchy(_ manifest: Manifest) throws {
        let chapterIds = Set(manifest.hierarchy.chapters.map(\.id))
        let sceneIds = Set(manifest.hierarchy.scenes.map(\.id))

        for chapter in manifest.hierarchy.chapters {
            for sceneId in chapter.scenes where !sceneIds.contains(sceneId) {
                throw ProjectIOError.invalidHierarchy(details: "Chapter \(chapter.id) references missing scene \(sceneId)")
            }
        }

        for scene in manifest.hierarchy.scenes {
            if let chapterId = scene.parentChapterId, !chapterIds.contains(chapterId) {
                throw ProjectIOError.invalidHierarchy(details: "Scene \(scene.id) references missing chapter \(chapterId)")
            }
        }
    }

    private func normalizeDuplicateSceneIDs(manifest: inout Manifest, rootURL: URL) throws -> Bool {
        var changed = false
        var seen = Set<UUID>()

        for sceneIndex in manifest.hierarchy.scenes.indices {
            let oldId = manifest.hierarchy.scenes[sceneIndex].id
            guard seen.contains(oldId) else {
                seen.insert(oldId)
                continue
            }

            changed = true
            let newId = UUID()
            manifest.hierarchy.scenes[sceneIndex].id = newId

            for chapterIndex in manifest.hierarchy.chapters.indices {
                for idx in manifest.hierarchy.chapters[chapterIndex].scenes.indices where manifest.hierarchy.chapters[chapterIndex].scenes[idx] == oldId {
                    manifest.hierarchy.chapters[chapterIndex].scenes[idx] = newId
                }
            }
            for idx in manifest.hierarchy.stagingScenes.indices where manifest.hierarchy.stagingScenes[idx] == oldId {
                manifest.hierarchy.stagingScenes[idx] = newId
            }

            let oldPath = manifest.hierarchy.scenes[sceneIndex].filePath
            let chapterId = manifest.hierarchy.scenes[sceneIndex].parentChapterId
            let newPath = sceneFilePath(sceneId: newId, chapterId: chapterId)
            let oldURL = rootURL.appendingPathComponent(oldPath)
            let newURL = rootURL.appendingPathComponent(newPath)
            if fileManager.fileExists(atPath: oldURL.path) {
                try fileManager.createDirectory(at: newURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                if fileManager.fileExists(atPath: newURL.path) {
                    try fileManager.removeItem(at: newURL)
                }
                try fileManager.moveItem(at: oldURL, to: newURL)
            }
            manifest.hierarchy.scenes[sceneIndex].filePath = newPath
        }

        return changed
    }

    private func recalculateSceneSequenceIndices(in manifest: inout Manifest, chapterId: UUID) {
        guard let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) else { return }
        for (index, sceneId) in manifest.hierarchy.chapters[chapterIndex].scenes.enumerated() {
            if let sceneIndex = manifest.hierarchy.scenes.firstIndex(where: { $0.id == sceneId }) {
                manifest.hierarchy.scenes[sceneIndex].sequenceIndex = index
                manifest.hierarchy.scenes[sceneIndex].parentChapterId = chapterId
            }
        }
    }

    private func recalculateChapterIndices(in manifest: inout Manifest, partId: UUID?) {
        if let partId {
            guard let partIndex = manifest.hierarchy.parts.firstIndex(where: { $0.id == partId }) else { return }
            for (idx, chapterId) in manifest.hierarchy.parts[partIndex].chapters.enumerated() {
                if let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapterId }) {
                    manifest.hierarchy.chapters[chapterIndex].sequenceIndex = idx
                    manifest.hierarchy.chapters[chapterIndex].parentPartId = partId
                }
            }
            return
        }

        let topLevelChapters = manifest.hierarchy.chapters
            .filter { $0.parentPartId == nil }
            .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })

        for (idx, chapter) in topLevelChapters.enumerated() {
            if let chapterIndex = manifest.hierarchy.chapters.firstIndex(where: { $0.id == chapter.id }) {
                manifest.hierarchy.chapters[chapterIndex].sequenceIndex = idx
            }
        }
    }

    private func sceneFilePath(sceneId: UUID, chapterId: UUID?) -> String {
        let filename = "scene-\(sceneId.uuidString.lowercased()).md"
        if let chapterId {
            return "content/ch-\(chapterId.uuidString.lowercased())/\(filename)"
        }
        return "content/staging/\(filename)"
    }

    private func makeProject(from manifest: Manifest, loadSceneContent: Bool, existingTrash: [TrashedItem] = []) throws -> Project {
        guard let rootURL = projectURL ?? URL(string: "file:///") else {
            throw ProjectIOError.noOpenProject
        }

        var sceneById = [UUID: Scene]()
        for sceneMeta in manifest.hierarchy.scenes {
            let content: String
            if loadSceneContent {
                let data = try Data(contentsOf: rootURL.appendingPathComponent(sceneMeta.filePath))
                content = String(data: data, encoding: .utf8) ?? ""
            } else {
                content = ""
            }

            sceneById[sceneMeta.id] = Scene(
                id: sceneMeta.id,
                title: sceneMeta.title,
                content: content,
                synopsis: sceneMeta.synopsis,
                status: sceneMeta.status,
                tags: sceneMeta.tags,
                colorLabel: sceneMeta.colorLabel,
                metadata: sceneMeta.metadata,
                sequenceIndex: sceneMeta.sequenceIndex,
                wordCount: sceneMeta.wordCount,
                createdAt: sceneMeta.createdAt,
                modifiedAt: sceneMeta.modifiedAt
            )
        }

        var chaptersById = [UUID: Chapter]()
        for chapterMeta in manifest.hierarchy.chapters {
            let scenes = chapterMeta.scenes.compactMap { sceneById[$0] }
            chaptersById[chapterMeta.id] = Chapter(
                id: chapterMeta.id,
                title: chapterMeta.title,
                synopsis: chapterMeta.synopsis,
                scenes: scenes,
                status: chapterMeta.status,
                sequenceIndex: chapterMeta.sequenceIndex,
                goalWordCount: chapterMeta.goalWordCount
            )
        }

        let parts = manifest.hierarchy.parts
            .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
            .map { partMeta in
                Part(
                    id: partMeta.id,
                    title: partMeta.title,
                    synopsis: partMeta.synopsis,
                    chapters: partMeta.chapters.compactMap { chaptersById[$0] },
                    sequenceIndex: partMeta.sequenceIndex
                )
            }

        let topLevelChapters = manifest.hierarchy.chapters
            .filter { $0.parentPartId == nil }
            .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
            .compactMap { chaptersById[$0.id] }

        let stagingScenes = manifest.hierarchy.stagingScenes.compactMap { sceneById[$0] }

        return Project(
            id: manifest.project.id,
            name: manifest.project.name,
            manuscript: Manuscript(
                id: manifest.project.id,
                title: manifest.project.name,
                parts: parts,
                chapters: topLevelChapters,
                stagingArea: stagingScenes
            ),
            settings: manifest.settings,
            tags: [],
            snapshots: [],
            entities: [],
            sources: [],
            notes: [],
            compilePresets: [],
            trash: existingTrash,
            createdAt: manifest.project.createdAt,
            modifiedAt: manifest.project.modifiedAt
        )
    }

    private static func defaultSettings() -> ProjectSettings {
        let defaultLabelNames = Dictionary(uniqueKeysWithValues: ColorLabel.allCases.map { ($0, $0.rawValue.capitalized) })
        return ProjectSettings(
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
            defaultColorLabelNames: defaultLabelNames
        )
    }

    private func writeStringAtomically(_ value: String, to url: URL) throws {
        guard let data = value.data(using: .utf8) else {
            throw ProjectIOError.invalidHierarchy(details: "Failed to encode UTF-8 for \(url.lastPathComponent)")
        }
        try data.write(to: url, options: .atomic)
    }

    private func wordCount(for content: String) -> Int {
        content.split { $0.isWhitespace || $0.isNewline }.count
    }
}
