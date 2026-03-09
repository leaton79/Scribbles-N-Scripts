import Combine
import Foundation

@MainActor
final class MetadataManager: ObservableObject {
    @Published var customFields: [CustomMetadataField] = []

    private let projectManager: ProjectManager
    private var singleSelectOptionsByFieldId: [UUID: [String]] = [:]

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        if let current = projectManager.currentProject {
            customFields = current.settings.customMetadataFields
        }
    }

    func addField(_ field: CustomMetadataField) throws {
        guard !customFields.contains(where: { $0.name.caseInsensitiveCompare(field.name) == .orderedSame }) else {
            throw ProjectIOError.invalidHierarchy(details: "Field '\(field.name)' already exists")
        }
        customFields.append(field)

        for scene in projectManager.getManifest().hierarchy.scenes {
            var metadata = scene.metadata
            metadata[field.name] = metadata[field.name] ?? ""
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: metadata)
            )
        }
    }

    func removeField(id: UUID) throws {
        guard let field = customFields.first(where: { $0.id == id }) else { return }
        customFields.removeAll { $0.id == id }
        singleSelectOptionsByFieldId.removeValue(forKey: id)

        for scene in projectManager.getManifest().hierarchy.scenes {
            var metadata = scene.metadata
            metadata.removeValue(forKey: field.name)
            try projectManager.updateSceneMetadata(
                sceneId: scene.id,
                updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: metadata)
            )
        }
    }

    func renameField(id: UUID, newName: String) throws {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else { return }
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ProjectIOError.invalidHierarchy(details: "Field name must contain at least one character")
        }

        let old = customFields[index].name
        customFields[index].name = trimmed

        for scene in projectManager.getManifest().hierarchy.scenes {
            var metadata = scene.metadata
            if let value = metadata.removeValue(forKey: old) {
                metadata[trimmed] = value
                try projectManager.updateSceneMetadata(
                    sceneId: scene.id,
                    updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: metadata)
                )
            }
        }
    }

    func configureSingleSelectOptions(fieldId: UUID, options: [String]) {
        singleSelectOptionsByFieldId[fieldId] = options
    }

    func setSceneMetadata(sceneId: UUID, field: String, value: String) throws {
        guard let fieldDef = customFields.first(where: { $0.name == field }) else {
            throw ProjectIOError.invalidHierarchy(details: "Unknown field '\(field)'")
        }

        if fieldDef.fieldType == .singleSelect,
           let options = singleSelectOptionsByFieldId[fieldDef.id],
           !options.contains(value) {
            throw ProjectIOError.invalidHierarchy(details: "Value '\(value)' is not allowed for '\(field)'")
        }

        guard let scene = projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        var metadata = scene.metadata
        metadata[field] = value
        try projectManager.updateSceneMetadata(
            sceneId: sceneId,
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: metadata)
        )
    }

    func getSceneMetadata(sceneId: UUID, field: String) -> String? {
        projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneId })?.metadata[field]
    }

    func scenesMatching(field: String, value: String) -> [UUID] {
        projectManager.getManifest().hierarchy.scenes
            .filter { $0.metadata[field] == value }
            .map(\.id)
    }
}
