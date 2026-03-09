import Combine
import Foundation

@MainActor
final class NavigationState: ObservableObject {
    @Published var selectedSceneId: UUID?
    @Published var selectedChapterId: UUID?
    @Published var expandedNodes: Set<UUID>
    @Published var breadcrumb: [BreadcrumbItem]
    @Published var activeFilters: FilterSet

    private let projectProvider: () -> Project?
    private var operationStack: [NavigationOperation] = []

    init(projectProvider: @escaping () -> Project? = { nil }) {
        self.projectProvider = projectProvider
        self.selectedSceneId = nil
        self.selectedChapterId = nil
        self.expandedNodes = []
        self.breadcrumb = []
        self.activeFilters = FilterSet()
    }

    func navigateTo(sceneId: UUID) {
        selectedSceneId = sceneId
        selectedChapterId = nil
        breadcrumb = BreadcrumbBuilder.breadcrumb(forSceneId: sceneId, in: projectProvider())
    }

    func navigateTo(chapterId: UUID) {
        selectedChapterId = chapterId
        selectedSceneId = firstScene(in: chapterId)
        breadcrumb = BreadcrumbBuilder.breadcrumb(forChapterId: chapterId, in: projectProvider())
    }

    func expandAll() {
        guard let project = projectProvider() else { return }
        var all: Set<UUID> = Set(project.manuscript.parts.map(\.id))
        all.formUnion(project.manuscript.parts.flatMap { $0.chapters.map(\.id) })
        all.formUnion(project.manuscript.chapters.map(\.id))
        expandedNodes = all
    }

    func collapseAll() {
        expandedNodes.removeAll()
    }

    func performSceneMove(sceneId: UUID, toChapterId: UUID, atIndex: Int, manager: ProjectManager) throws {
        let manifest = manager.getManifest()
        guard let sourceChapter = manifest.hierarchy.chapters.first(where: { $0.scenes.contains(sceneId) }),
              let sourceIndex = sourceChapter.scenes.firstIndex(of: sceneId) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        try manager.moveScene(sceneId: sceneId, toChapterId: toChapterId, atIndex: atIndex)
        operationStack.append(.moveScene(sceneId: sceneId, fromChapterId: sourceChapter.id, fromIndex: sourceIndex))
    }

    func performChapterMove(chapterId: UUID, toPartId: UUID?, atIndex: Int, manager: ProjectManager) throws {
        let manifest = manager.getManifest()
        guard let current = manifest.hierarchy.chapters.first(where: { $0.id == chapterId }) else {
            throw ProjectIOError.chapterNotFound(chapterId)
        }

        try manager.moveChapter(chapterId: chapterId, toPartId: toPartId, atIndex: atIndex)
        operationStack.append(.moveChapter(chapterId: chapterId, fromPartId: current.parentPartId, fromIndex: current.sequenceIndex))
    }

    func undoLastOperation(manager: ProjectManager) throws {
        guard let op = operationStack.popLast() else { return }
        switch op {
        case let .moveScene(sceneId, fromChapterId, fromIndex):
            try manager.moveScene(sceneId: sceneId, toChapterId: fromChapterId, atIndex: fromIndex)
        case let .moveChapter(chapterId, fromPartId, fromIndex):
            try manager.moveChapter(chapterId: chapterId, toPartId: fromPartId, atIndex: fromIndex)
        }
    }

    private func firstScene(in chapterId: UUID) -> UUID? {
        guard let project = projectProvider() else { return nil }

        for part in project.manuscript.parts {
            if let chapter = part.chapters.first(where: { $0.id == chapterId }) {
                return chapter.scenes.first?.id
            }
        }
        if let chapter = project.manuscript.chapters.first(where: { $0.id == chapterId }) {
            return chapter.scenes.first?.id
        }
        return nil
    }
}

struct BreadcrumbItem: Equatable {
    let id: UUID
    let title: String
    let type: HierarchyLevel
}

enum HierarchyLevel: Equatable {
    case manuscript
    case part
    case chapter
    case scene
}

struct FilterSet: Equatable {
    var tags: Set<UUID>?
    var statuses: Set<ContentStatus>?
    var colorLabels: Set<ColorLabel>?
    var metadataFilters: [String: String]?

    var isActive: Bool {
        (tags?.isEmpty == false) ||
        (statuses?.isEmpty == false) ||
        (colorLabels?.isEmpty == false) ||
        (metadataFilters?.isEmpty == false)
    }

    func matches(scene: Scene) -> Bool {
        if let tags, !tags.isEmpty, Set(scene.tags).isDisjoint(with: tags) { return false }
        if let statuses, !statuses.isEmpty, !statuses.contains(scene.status) { return false }
        if let colorLabels, !colorLabels.isEmpty {
            guard let label = scene.colorLabel, colorLabels.contains(label) else { return false }
        }
        if let metadataFilters, !metadataFilters.isEmpty {
            for (key, value) in metadataFilters where scene.metadata[key] != value {
                return false
            }
        }
        return true
    }
}

private enum NavigationOperation {
    case moveScene(sceneId: UUID, fromChapterId: UUID, fromIndex: Int)
    case moveChapter(chapterId: UUID, fromPartId: UUID?, fromIndex: Int)
}

enum BreadcrumbBuilder {
    static func breadcrumb(forSceneId sceneId: UUID, in project: Project?) -> [BreadcrumbItem] {
        guard let project else { return [] }
        var items: [BreadcrumbItem] = [BreadcrumbItem(id: project.id, title: project.name, type: .manuscript)]

        for part in project.manuscript.parts {
            for chapter in part.chapters {
                if let scene = chapter.scenes.first(where: { $0.id == sceneId }) {
                    items.append(BreadcrumbItem(id: part.id, title: part.title, type: .part))
                    items.append(BreadcrumbItem(id: chapter.id, title: chapter.title, type: .chapter))
                    items.append(BreadcrumbItem(id: scene.id, title: scene.title, type: .scene))
                    return items
                }
            }
        }

        for chapter in project.manuscript.chapters {
            if let scene = chapter.scenes.first(where: { $0.id == sceneId }) {
                items.append(BreadcrumbItem(id: chapter.id, title: chapter.title, type: .chapter))
                items.append(BreadcrumbItem(id: scene.id, title: scene.title, type: .scene))
                return items
            }
        }
        return items
    }

    static func breadcrumb(forChapterId chapterId: UUID, in project: Project?) -> [BreadcrumbItem] {
        guard let project else { return [] }
        var items: [BreadcrumbItem] = [BreadcrumbItem(id: project.id, title: project.name, type: .manuscript)]

        for part in project.manuscript.parts {
            if let chapter = part.chapters.first(where: { $0.id == chapterId }) {
                items.append(BreadcrumbItem(id: part.id, title: part.title, type: .part))
                items.append(BreadcrumbItem(id: chapter.id, title: chapter.title, type: .chapter))
                return items
            }
        }

        if let chapter = project.manuscript.chapters.first(where: { $0.id == chapterId }) {
            items.append(BreadcrumbItem(id: chapter.id, title: chapter.title, type: .chapter))
        }
        return items
    }
}
