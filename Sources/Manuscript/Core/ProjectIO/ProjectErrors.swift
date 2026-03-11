import Foundation

enum ProjectIOError: Error, LocalizedError {
    case noOpenProject
    case sceneNotFound(UUID)
    case chapterNotFound(UUID)
    case partNotFound(UUID)
    case trashItemNotFound(UUID)
    case missingSceneFile(sceneId: UUID, title: String, expectedPath: String)
    case corruptManifest(details: String)
    case incompatibleVersion(projectVersion: String, supportedVersion: String)
    case concurrentAccess(lockFile: URL)
    case fileMoved(projectURL: URL)
    case invalidHierarchy(details: String)
    case backupNotFound(String)
    case unsupportedMigration(projectVersion: String, supportedVersion: String)
    case projectAlreadyExists(URL)
    case readOnlyProject(details: String)

    var errorDescription: String? {
        switch self {
        case .noOpenProject:
            return "No project is currently open."
        case let .sceneNotFound(id):
            return "Scene not found: \(id.uuidString)"
        case let .chapterNotFound(id):
            return "Chapter not found: \(id.uuidString)"
        case let .partNotFound(id):
            return "Part not found: \(id.uuidString)"
        case let .trashItemNotFound(id):
            return "Trash item not found: \(id.uuidString)"
        case let .missingSceneFile(_, title, expectedPath):
            return "Scene content missing for '\(title)' at \(expectedPath)."
        case let .corruptManifest(details):
            return "Corrupt manifest: \(details)"
        case let .incompatibleVersion(projectVersion, supportedVersion):
            return "Project format \(projectVersion) is incompatible with supported format \(supportedVersion)."
        case let .concurrentAccess(lockFile):
            return "Project is locked by another instance (\(lockFile.path))."
        case let .fileMoved(projectURL):
            return "Project directory appears moved or unavailable at \(projectURL.path)."
        case let .invalidHierarchy(details):
            return "Invalid project hierarchy: \(details)"
        case let .backupNotFound(backupId):
            return "Backup not found: \(backupId)"
        case let .unsupportedMigration(projectVersion, supportedVersion):
            return "Cannot migrate project format \(projectVersion) with app support \(supportedVersion)."
        case let .projectAlreadyExists(url):
            return "A project already exists at \(url.path)."
        case let .readOnlyProject(details):
            return "Project is open in recovery mode and is read-only. \(details)"
        }
    }
}
