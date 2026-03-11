import Combine
import Foundation

@MainActor
final class MetadataManager: ObservableObject {
    @Published var customFields: [CustomMetadataField] = []

    private let projectManager: ProjectManager
    private var singleSelectOptionsByFieldId: [UUID: [String]] = [:]
    private let metadataDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    init(projectManager: ProjectManager) {
        self.projectManager = projectManager
        reloadFromProject()
    }

    func reloadFromProject() {
        if let current = projectManager.currentProject {
            customFields = current.settings.customMetadataFields
            singleSelectOptionsByFieldId = Dictionary(
                uniqueKeysWithValues: customFields.map { ($0.id, $0.options) }
            )
        } else {
            customFields = []
            singleSelectOptionsByFieldId = [:]
        }
    }

    func addField(_ field: CustomMetadataField) throws {
        guard !customFields.contains(where: { $0.name.caseInsensitiveCompare(field.name) == .orderedSame }) else {
            throw ProjectIOError.invalidHierarchy(details: "Field '\(field.name)' already exists")
        }
        customFields.append(field)
        try persistCustomFields()

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
        try persistCustomFields()

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
        guard !customFields.contains(where: { $0.id != id && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) else {
            throw ProjectIOError.invalidHierarchy(details: "Field '\(trimmed)' already exists")
        }

        let old = customFields[index].name
        customFields[index].name = trimmed
        try persistCustomFields()

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

    func configureOptions(fieldId: UUID, options: [String]) {
        guard let index = customFields.firstIndex(where: { $0.id == fieldId }) else { return }
        let normalized = normalizeOptions(options)
        singleSelectOptionsByFieldId[fieldId] = normalized
        customFields[index].options = normalized
        try? persistCustomFields()

        guard customFields[index].fieldType == .singleSelect || customFields[index].fieldType == .multiSelect else { return }
        let fieldName = customFields[index].name
        let fieldType = customFields[index].fieldType
        let fallback = normalized.first ?? ""
        for scene in projectManager.getManifest().hierarchy.scenes {
            guard let currentValue = scene.metadata[fieldName], !currentValue.isEmpty else {
                continue
            }
            let normalizedValue: String
            if fieldType == .singleSelect && !normalized.contains(currentValue) {
                normalizedValue = fallback
            } else {
                guard let candidate = try? normalizedMetadataValue(
                    rawValue: currentValue,
                    for: customFields[index],
                    options: normalized
                ) else {
                    continue
                }
                normalizedValue = candidate
            }
            if normalizedValue != currentValue {
                var metadata = scene.metadata
                metadata[fieldName] = normalizedValue
                try? projectManager.updateSceneMetadata(
                    sceneId: scene.id,
                    updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: nil, tags: nil, colorLabel: nil, metadata: metadata)
                )
            }
        }
    }

    func configureSingleSelectOptions(fieldId: UUID, options: [String]) {
        configureOptions(fieldId: fieldId, options: options)
    }

    func moveField(id: UUID, by offset: Int) throws {
        guard let index = customFields.firstIndex(where: { $0.id == id }) else { return }
        let destination = index + offset
        guard customFields.indices.contains(destination) else { return }
        let field = customFields.remove(at: index)
        customFields.insert(field, at: destination)
        try persistCustomFields()
    }

    func setSceneMetadata(sceneId: UUID, field: String, value: String) throws {
        guard let fieldDef = customFields.first(where: { $0.name == field }) else {
            throw ProjectIOError.invalidHierarchy(details: "Unknown field '\(field)'")
        }

        guard let scene = projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == sceneId }) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        var metadata = scene.metadata
        metadata[field] = try normalizedMetadataValue(
            rawValue: value,
            for: fieldDef,
            options: singleSelectOptionsByFieldId[fieldDef.id] ?? fieldDef.options
        )
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

    private func persistCustomFields() throws {
        guard var settings = projectManager.currentProject?.settings else {
            throw ProjectIOError.noOpenProject
        }
        settings.customMetadataFields = customFields
        try projectManager.updateProjectSettings(settings)
    }

    private func normalizeOptions(_ options: [String]) -> [String] {
        var seen = Set<String>()
        return options
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    private func normalizedMetadataValue(rawValue: String, for field: CustomMetadataField, options: [String]) throws -> String {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        switch field.fieldType {
        case .text:
            return rawValue
        case .singleSelect:
            guard !trimmed.isEmpty || options.isEmpty else {
                return options.first ?? ""
            }
            guard options.isEmpty || options.contains(trimmed) else {
                throw ProjectIOError.invalidHierarchy(details: "Value '\(trimmed)' is not allowed for '\(field.name)'")
            }
            return trimmed
        case .multiSelect:
            let selected = normalizeOptions(trimmed.split(separator: ",").map(String.init))
            guard options.isEmpty || Set(selected).isSubset(of: Set(options)) else {
                throw ProjectIOError.invalidHierarchy(details: "One or more values are not allowed for '\(field.name)'")
            }
            return selected.joined(separator: ", ")
        case .number:
            guard !trimmed.isEmpty else { return "" }
            guard Double(trimmed) != nil else {
                throw ProjectIOError.invalidHierarchy(details: "'\(field.name)' requires a numeric value")
            }
            return trimmed
        case .date:
            guard !trimmed.isEmpty else { return "" }
            guard let date = metadataDateFormatter.date(from: trimmed) else {
                throw ProjectIOError.invalidHierarchy(details: "'\(field.name)' requires a date in YYYY-MM-DD format")
            }
            return metadataDateFormatter.string(from: date)
        }
    }
}
