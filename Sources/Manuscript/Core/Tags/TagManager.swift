import Combine
import Foundation

@MainActor
final class TagManager: ObservableObject {
    @Published var allTags: [Tag] = []

    private let projectManager: ProjectManager

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        self.allTags = loadTags()
        allTags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    func createTag(name: String, color: String?) throws -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectIOError.invalidHierarchy(details: "Tag name must contain at least one character")
        }
        guard !allTags.contains(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw ProjectIOError.invalidHierarchy(details: "Tag '\(trimmed)' already exists.")
        }

        let tag = Tag(id: UUID(), name: trimmed, color: color)
        allTags.append(tag)
        allTags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try persistTags()
        return tag
    }

    func renameTag(id: UUID, newName: String) throws {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectIOError.invalidHierarchy(details: "Tag name must contain at least one character")
        }

        guard let index = allTags.firstIndex(where: { $0.id == id }) else {
            throw ProjectIOError.invalidHierarchy(details: "Tag not found")
        }

        if allTags.enumerated().contains(where: { $0.offset != index && $0.element.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            throw ProjectIOError.invalidHierarchy(details: "Tag '\(trimmed)' already exists.")
        }

        allTags[index].name = trimmed
        allTags.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        try persistTags()
    }

    func deleteTag(id: UUID) throws {
        allTags.removeAll { $0.id == id }
        for scene in projectManager.getManifest().hierarchy.scenes {
            try removeTag(id, from: scene.id)
        }
        try persistTags()
    }

    func mergeTag(sourceId: UUID, targetId: UUID) throws {
        guard sourceId != targetId else { return }

        for scene in projectManager.getManifest().hierarchy.scenes {
            var tags = scene.tags
            let hadSource = tags.contains(sourceId)
            tags.removeAll { $0 == sourceId }
            if hadSource && !tags.contains(targetId) {
                tags.append(targetId)
            }
            if tags != scene.tags {
                try projectManager.updateSceneMetadata(
                    sceneId: scene.id,
                    updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: tags, colorLabel: nil, metadata: nil)
                )
            }
        }

        allTags.removeAll { $0.id == sourceId }
        try persistTags()
    }

    func addTag(_ tagId: UUID, to sceneId: UUID) throws {
        let manifest = projectManager.getManifest()
        guard let scene = manifest.hierarchy.scenes.first(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        var tags = scene.tags
        if !tags.contains(tagId) {
            tags.append(tagId)
            try projectManager.updateSceneMetadata(
                sceneId: sceneId,
                updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: tags, colorLabel: nil, metadata: nil)
            )
        }
    }

    func removeTag(_ tagId: UUID, from sceneId: UUID) throws {
        let manifest = projectManager.getManifest()
        guard let scene = manifest.hierarchy.scenes.first(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        var tags = scene.tags
        tags.removeAll { $0 == tagId }

        try projectManager.updateSceneMetadata(
            sceneId: sceneId,
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: tags, colorLabel: nil, metadata: nil)
        )
    }

    func scenesWithTag(_ tagId: UUID) -> [UUID] {
        projectManager.getManifest().hierarchy.scenes
            .filter { $0.tags.contains(tagId) }
            .map(\.id)
    }

    func autocomplete(prefix: String) -> [Tag] {
        let p = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !p.isEmpty else { return allTags }
        return allTags
            .filter { $0.name.lowercased().hasPrefix(p.lowercased()) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func loadTags() -> [Tag] {
        if let current = projectManager.currentProject, !current.tags.isEmpty {
            return current.tags
        }

        guard let root = projectManager.projectRootURL else { return [] }
        let tagsFile = root.appendingPathComponent("metadata/tags.json")
        guard let data = try? Data(contentsOf: tagsFile) else { return [] }
        return (try? JSONDecoder().decode([Tag].self, from: data)) ?? []
    }

    private func persistTags() throws {
        guard let root = projectManager.projectRootURL else { throw ProjectIOError.noOpenProject }
        let tagsURL = root.appendingPathComponent("metadata/tags.json")
        let data = try JSONEncoder().encode(allTags)
        try data.write(to: tagsURL, options: .atomic)

        if let fs = projectManager as? FileSystemProjectManager,
           var project = fs.currentProject {
            project.tags = allTags
            fs._assignCurrentProjectForTesting(project)
        }
    }
}
