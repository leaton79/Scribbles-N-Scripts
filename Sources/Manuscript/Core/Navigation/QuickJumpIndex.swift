import Foundation

struct QuickJumpResult: Equatable {
    let id: UUID
    let title: String
    let path: String
    let level: HierarchyLevel
    let titleMatch: Bool
}

final class QuickJumpIndex {
    private struct Entry {
        var id: UUID
        var title: String
        var path: String
        var level: HierarchyLevel
        var content: String?
    }

    private var entries: [Entry] = []

    func rebuild(project: Project, contentProvider: ((UUID) -> String?)? = nil) {
        entries.removeAll()

        for part in project.manuscript.parts {
            let partPath = "\(project.name) > \(part.title)"
            entries.append(Entry(id: part.id, title: part.title, path: partPath, level: .part, content: nil))

            for chapter in part.chapters {
                let chapterPath = "\(partPath) > \(chapter.title)"
                entries.append(Entry(id: chapter.id, title: chapter.title, path: chapterPath, level: .chapter, content: nil))

                for scene in chapter.scenes {
                    let scenePath = "\(chapterPath) > \(scene.title)"
                    entries.append(
                        Entry(
                            id: scene.id,
                            title: scene.title,
                            path: scenePath,
                            level: .scene,
                            content: contentProvider?(scene.id)
                        )
                    )
                }
            }
        }

        for chapter in project.manuscript.chapters {
            let chapterPath = "\(project.name) > \(chapter.title)"
            entries.append(Entry(id: chapter.id, title: chapter.title, path: chapterPath, level: .chapter, content: nil))

            for scene in chapter.scenes {
                let scenePath = "\(chapterPath) > \(scene.title)"
                entries.append(
                    Entry(
                        id: scene.id,
                        title: scene.title,
                        path: scenePath,
                        level: .scene,
                        content: contentProvider?(scene.id)
                    )
                )
            }
        }
    }

    func search(query: String) -> [QuickJumpResult] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !q.isEmpty else { return [] }

        let titleMatches = entries.filter { $0.title.lowercased().contains(q) }
        let titleIDs = Set(titleMatches.map(\.id))

        let contentMatches = entries.filter {
            guard $0.level == .scene, !titleIDs.contains($0.id) else { return false }
            return ($0.content ?? "").lowercased().contains(q)
        }

        let ranked = titleMatches + contentMatches
        return ranked.map {
            QuickJumpResult(id: $0.id, title: $0.title, path: $0.path, level: $0.level, titleMatch: $0.title.lowercased().contains(q))
        }
    }
}
