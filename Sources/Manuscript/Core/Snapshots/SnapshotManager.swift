import Foundation

@MainActor
protocol SnapshotManager {
    func createSnapshot(name: String) throws -> Snapshot
    func listSnapshots() -> [Snapshot]
    func deleteSnapshot(id: UUID) throws

    func diff(snapshotA: UUID, snapshotB: UUID) throws -> ManuscriptDiff
    func diffWithCurrent(snapshotId: UUID) throws -> ManuscriptDiff

    func restore(snapshotId: UUID) throws
}

struct ManuscriptDiff {
    let snapshotA: SnapshotSummary
    let snapshotB: SnapshotSummary
    var sceneDiffs: [SceneComparisonResult]
    var hierarchyChanges: HierarchyDiff
    var wordCountDelta: Int
}

struct SnapshotSummary {
    let id: UUID
    let name: String
    let date: Date
    let wordCount: Int
}

struct SceneComparisonResult {
    let sceneId: UUID
    let sceneTitle: String
    var changeType: DiffChangeType
    var lineDiffs: [LineDiff]?
}

struct LineDiff {
    let lineNumber: Int
    let type: LineDiffType
    let text: String
}

enum LineDiffType {
    case added
    case removed
    case unchanged
    case modified
}

@MainActor
final class FileSnapshotManager: SnapshotManager {
    private let projectManager: ProjectManager
    private let unsavedCurrentContent: ((UUID) -> String?)?

    init(projectManager: ProjectManager, unsavedCurrentContent: ((UUID) -> String?)? = nil) {
        self.projectManager = projectManager
        self.unsavedCurrentContent = unsavedCurrentContent
    }

    func createSnapshot(name: String) throws -> Snapshot {
        guard let root = projectManager.projectRootURL else { throw ProjectIOError.noOpenProject }
        let snapshotsURL = snapshotRootURL(root)
        try FileManager.default.createDirectory(at: snapshotsURL, withIntermediateDirectories: true)

        let manifest = projectManager.getManifest()
        let contents = try collectAllSceneContents(from: manifest)
        let totalWords = contents.values.reduce(0) { $0 + WordCounter.count($1) }

        let existing = listSnapshots()
        let isBaseline = existing.isEmpty
        let id = UUID()
        let snapshot = Snapshot(id: id, name: name, createdAt: Date(), wordCount: totalWords, isBaseline: isBaseline)

        let record = SnapshotRecord(
            snapshot: SnapshotRecordMeta(
                id: snapshot.id,
                name: snapshot.name,
                createdAt: snapshot.createdAt,
                wordCount: snapshot.wordCount,
                isBaseline: snapshot.isBaseline
            ),
            manifest: manifest,
            sceneContents: contents,
            previousSnapshotId: existing.first?.id
        )

        let recordURL = snapshotsURL.appendingPathComponent("snap-\(id.uuidString.lowercased()).json")
        let data = try SnapshotRecordCoder.encode(record)
        try data.write(to: recordURL, options: .atomic)

        if isBaseline {
            let baselineDir = snapshotsURL.appendingPathComponent("baselines/snap-\(id.uuidString.lowercased())", isDirectory: true)
            try FileManager.default.createDirectory(at: baselineDir, withIntermediateDirectories: true)
            for (sceneId, content) in contents {
                let file = baselineDir.appendingPathComponent("scene-\(sceneId.uuidString.lowercased()).md")
                try Data(content.utf8).write(to: file, options: .atomic)
            }
        }

        return snapshot
    }

    func listSnapshots() -> [Snapshot] {
        guard let root = projectManager.projectRootURL else { return [] }
        let url = snapshotRootURL(root)
        let files = (try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)) ?? []

        return files
            .filter { $0.lastPathComponent.hasPrefix("snap-") && $0.pathExtension == "json" }
            .compactMap { file in
                guard let data = try? Data(contentsOf: file),
                      let record = try? SnapshotRecordCoder.decode(data) else { return nil }
                return Snapshot(
                    id: record.snapshot.id,
                    name: record.snapshot.name,
                    createdAt: record.snapshot.createdAt,
                    wordCount: record.snapshot.wordCount,
                    isBaseline: record.snapshot.isBaseline
                )
            }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func deleteSnapshot(id: UUID) throws {
        guard let root = projectManager.projectRootURL else { throw ProjectIOError.noOpenProject }
        let snapshotsURL = snapshotRootURL(root)
        let file = snapshotsURL.appendingPathComponent("snap-\(id.uuidString.lowercased()).json")
        if FileManager.default.fileExists(atPath: file.path) {
            try FileManager.default.removeItem(at: file)
        }

        let baseline = snapshotsURL.appendingPathComponent("baselines/snap-\(id.uuidString.lowercased())", isDirectory: true)
        if FileManager.default.fileExists(atPath: baseline.path) {
            try FileManager.default.removeItem(at: baseline)
        }
    }

    func diff(snapshotA: UUID, snapshotB: UUID) throws -> ManuscriptDiff {
        let a = try loadSnapshotRecord(id: snapshotA)
        let b = try loadSnapshotRecord(id: snapshotB)
        return buildDiff(a: a, b: b)
    }

    func diffWithCurrent(snapshotId: UUID) throws -> ManuscriptDiff {
        let a = try loadSnapshotRecord(id: snapshotId)
        let currentManifest = projectManager.getManifest()
        var currentContents = try collectAllSceneContents(from: currentManifest)

        if let unsavedCurrentContent {
            for sceneId in currentContents.keys {
                if let override = unsavedCurrentContent(sceneId) {
                    currentContents[sceneId] = override
                }
            }
        }

        let currentWordCount = currentContents.values.reduce(0) { $0 + WordCounter.count($1) }
        let b = SnapshotRecord(
            snapshot: SnapshotRecordMeta(
                id: UUID(),
                name: "Current",
                createdAt: Date(),
                wordCount: currentWordCount,
                isBaseline: false
            ),
            manifest: currentManifest,
            sceneContents: currentContents,
            previousSnapshotId: nil
        )

        return buildDiff(a: a, b: b)
    }

    func restore(snapshotId: UUID) throws {
        guard let root = projectManager.projectRootURL else { throw ProjectIOError.noOpenProject }
        let target = try loadSnapshotRecord(id: snapshotId)

        let currentManifest = projectManager.getManifest()
        let currentContents = try collectAllSceneContents(from: currentManifest)

        if try isEquivalentState(
            manifestA: target.manifest,
            contentsA: target.sceneContents,
            manifestB: currentManifest,
            contentsB: currentContents
        ) {
            return
        }

        _ = try createSnapshot(name: "Auto-save before restoring '\(target.snapshot.name)'")

        for scene in target.manifest.hierarchy.scenes {
            let content = target.sceneContents[scene.id] ?? ""
            let sceneURL = root.appendingPathComponent(scene.filePath)
            try FileManager.default.createDirectory(at: sceneURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(content.utf8).write(to: sceneURL, options: .atomic)
        }

        let manifestURL = root.appendingPathComponent("manifest.json")
        try ManifestCoder.write(target.manifest, to: manifestURL)

        try projectManager.closeProject()
        _ = try projectManager.openProject(at: root)
    }

    private func buildDiff(a: SnapshotRecord, b: SnapshotRecord) -> ManuscriptDiff {
        let aSummary = SnapshotSummary(id: a.snapshot.id, name: a.snapshot.name, date: a.snapshot.createdAt, wordCount: a.snapshot.wordCount)
        let bSummary = SnapshotSummary(id: b.snapshot.id, name: b.snapshot.name, date: b.snapshot.createdAt, wordCount: b.snapshot.wordCount)

        let aScenes = Dictionary(uniqueKeysWithValues: a.manifest.hierarchy.scenes.map { ($0.id, $0) })
        let bScenes = Dictionary(uniqueKeysWithValues: b.manifest.hierarchy.scenes.map { ($0.id, $0) })
        let ids = Set(aScenes.keys).union(bScenes.keys)

        let sceneDiffs: [SceneComparisonResult] = ids.sorted { $0.uuidString < $1.uuidString }.map { id in
            switch (aScenes[id], bScenes[id]) {
            case let (nil, sceneB?):
                return SceneComparisonResult(sceneId: id, sceneTitle: sceneB.title, changeType: .added, lineDiffs: fullAddedDiff(text: b.sceneContents[id] ?? ""))
            case let (sceneA?, nil):
                return SceneComparisonResult(sceneId: id, sceneTitle: sceneA.title, changeType: .removed, lineDiffs: fullRemovedDiff(text: a.sceneContents[id] ?? ""))
            case let (_, sceneB?):
                let aText = a.sceneContents[id] ?? ""
                let bText = b.sceneContents[id] ?? ""
                if aText == bText {
                    return SceneComparisonResult(sceneId: id, sceneTitle: sceneB.title, changeType: .unchanged, lineDiffs: nil)
                }
                return SceneComparisonResult(sceneId: id, sceneTitle: sceneB.title, changeType: .modified, lineDiffs: lineDiffs(old: aText, new: bText))
            default:
                return SceneComparisonResult(sceneId: id, sceneTitle: "Unknown", changeType: .unchanged, lineDiffs: nil)
            }
        }

        let hierarchy = HierarchyDiff(
            addedScenes: b.manifest.hierarchy.scenes.map(\.id).filter { !Set(a.manifest.hierarchy.scenes.map(\.id)).contains($0) },
            removedScenes: a.manifest.hierarchy.scenes.map(\.id).filter { !Set(b.manifest.hierarchy.scenes.map(\.id)).contains($0) },
            reorderedChapters: [],
            reorderedScenes: []
        )

        return ManuscriptDiff(
            snapshotA: aSummary,
            snapshotB: bSummary,
            sceneDiffs: sceneDiffs,
            hierarchyChanges: hierarchy,
            wordCountDelta: bSummary.wordCount - aSummary.wordCount
        )
    }

    private func lineDiffs(old: String, new: String) -> [LineDiff] {
        let oldLines = old.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let newLines = new.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)

        var result: [LineDiff] = []
        let maxCount = max(oldLines.count, newLines.count)

        for i in 0..<maxCount {
            let oldLine = i < oldLines.count ? oldLines[i] : nil
            let newLine = i < newLines.count ? newLines[i] : nil

            switch (oldLine, newLine) {
            case let (o?, n?) where o == n:
                result.append(LineDiff(lineNumber: i + 1, type: .unchanged, text: n))
            case let (o?, n?):
                result.append(LineDiff(lineNumber: i + 1, type: .modified, text: "- \(o)"))
                result.append(LineDiff(lineNumber: i + 1, type: .modified, text: "+ \(n)"))
            case let (o?, nil):
                result.append(LineDiff(lineNumber: i + 1, type: .removed, text: o))
            case let (nil, n?):
                result.append(LineDiff(lineNumber: i + 1, type: .added, text: n))
            default:
                break
            }
        }

        return result
    }

    private func fullAddedDiff(text: String) -> [LineDiff] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { LineDiff(lineNumber: $0.offset + 1, type: .added, text: String($0.element)) }
    }

    private func fullRemovedDiff(text: String) -> [LineDiff] {
        text.split(separator: "\n", omittingEmptySubsequences: false)
            .enumerated()
            .map { LineDiff(lineNumber: $0.offset + 1, type: .removed, text: String($0.element)) }
    }

    private func loadSnapshotRecord(id: UUID) throws -> SnapshotRecord {
        guard let root = projectManager.projectRootURL else { throw ProjectIOError.noOpenProject }
        let file = snapshotRootURL(root).appendingPathComponent("snap-\(id.uuidString.lowercased()).json")
        let data = try Data(contentsOf: file)
        return try SnapshotRecordCoder.decode(data)
    }

    private func collectAllSceneContents(from manifest: Manifest) throws -> [UUID: String] {
        var contents: [UUID: String] = [:]
        for scene in manifest.hierarchy.scenes {
            contents[scene.id] = try projectManager.loadSceneContent(sceneId: scene.id)
        }
        return contents
    }

    private func isEquivalentState(
        manifestA: Manifest,
        contentsA: [UUID: String],
        manifestB: Manifest,
        contentsB: [UUID: String]
    ) throws -> Bool {
        let manifestDataA = try ManifestCoder.encode(manifestA)
        let manifestDataB = try ManifestCoder.encode(manifestB)
        return manifestDataA == manifestDataB && contentsA == contentsB
    }

    private func snapshotRootURL(_ projectRoot: URL) -> URL {
        projectRoot.appendingPathComponent("metadata/snapshots", isDirectory: true)
    }
}

private struct SnapshotRecord: Codable {
    var snapshot: SnapshotRecordMeta
    var manifest: Manifest
    var sceneContents: [UUID: String]
    var previousSnapshotId: UUID?
}

private struct SnapshotRecordMeta: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var wordCount: Int
    var isBaseline: Bool
}

private enum SnapshotRecordCoder {
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }()

    private static let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }()

    static func encode(_ value: SnapshotRecord) throws -> Data {
        try encoder.encode(value)
    }

    static func decode(_ data: Data) throws -> SnapshotRecord {
        try decoder.decode(SnapshotRecord.self, from: data)
    }
}
