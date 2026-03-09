import Foundation

struct Manifest: Codable {
    var schema: String
    var formatVersion: String
    var project: ManifestProject
    var hierarchy: ManifestHierarchy
    var settings: ProjectSettings

    enum CodingKeys: String, CodingKey {
        case schema = "$schema"
        case formatVersion
        case project
        case hierarchy
        case settings
    }
}

struct ManifestProject: Codable {
    var id: UUID
    var name: String
    var createdAt: Date
    var modifiedAt: Date
}

struct ManifestHierarchy: Codable {
    var parts: [ManifestPart]
    var chapters: [ManifestChapter]
    var scenes: [ManifestScene]
    var stagingScenes: [UUID]
}

struct ManifestPart: Codable, Identifiable {
    var id: UUID
    var title: String
    var synopsis: String
    var sequenceIndex: Int
    var chapters: [UUID]
}

struct ManifestChapter: Codable, Identifiable {
    var id: UUID
    var title: String
    var synopsis: String
    var status: ContentStatus
    var sequenceIndex: Int
    var parentPartId: UUID?
    var goalWordCount: Int?
    var scenes: [UUID]
}

struct ManifestScene: Codable, Identifiable {
    var id: UUID
    var title: String
    var synopsis: String
    var status: ContentStatus
    var tags: [UUID]
    var colorLabel: ColorLabel?
    var metadata: [String: String]
    var sequenceIndex: Int
    var parentChapterId: UUID?
    var wordCount: Int
    var filePath: String
    var createdAt: Date
    var modifiedAt: Date
}

enum ManifestCoder {
    static let schemaVersion = "manuscript-manifest-v1"
    static let formatVersion = "1.0.0"

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

    static func encode(_ manifest: Manifest) throws -> Data {
        try encoder.encode(manifest)
    }

    static func decode(_ data: Data) throws -> Manifest {
        do {
            return try decoder.decode(Manifest.self, from: data)
        } catch {
            throw ProjectIOError.corruptManifest(details: error.localizedDescription)
        }
    }

    static func write(_ manifest: Manifest, to url: URL) throws {
        let data = try encode(manifest)
        try data.write(to: url, options: .atomic)
    }

    static func read(from url: URL) throws -> Manifest {
        let data = try Data(contentsOf: url)
        return try decode(data)
    }
}
