import Foundation

struct FilterEngine {
    static func buildPredicate(from filterSet: FilterSet) -> (Scene) -> Bool {
        { scene in
            if let tags = filterSet.tags, !tags.isEmpty {
                if Set(scene.tags).isDisjoint(with: tags) { return false }
            }

            if let statuses = filterSet.statuses, !statuses.isEmpty {
                if !statuses.contains(scene.status) { return false }
            }

            if let colorLabels = filterSet.colorLabels, !colorLabels.isEmpty {
                guard let label = scene.colorLabel, colorLabels.contains(label) else { return false }
            }

            if let metadataFilters = filterSet.metadataFilters, !metadataFilters.isEmpty {
                for (field, value) in metadataFilters where scene.metadata[field] != value {
                    return false
                }
            }

            return true
        }
    }

    static func matchingSceneIds(in project: Project, filters: FilterSet) -> Set<UUID> {
        let predicate = buildPredicate(from: filters)

        let allScenes = project.manuscript.parts
            .flatMap(\.chapters)
            .flatMap(\.scenes)
            + project.manuscript.chapters.flatMap(\.scenes)
            + project.manuscript.stagingArea

        return Set(allScenes.filter(predicate).map(\.id))
    }
}
