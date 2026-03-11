import Combine
import Foundation

struct CardData {
    let sceneId: UUID
    let title: String
    let previewText: String
    let wordCount: Int
    let status: ContentStatus
    let colorLabel: ColorLabel?
    let tags: [Tag]
    let chapterTitle: String
}

enum ModularPresentationMode: String, CaseIterable {
    case corkboard
    case outliner
}

enum CorkboardDensity: String, CaseIterable {
    case comfortable
    case compact
}

enum CardGrouping: Hashable {
    case byChapter
    case flat
    case byTag(tagId: UUID)
    case byStatus
}

struct OutlineRow: Identifiable, Equatable {
    let id: UUID
    let title: String
    let synopsis: String
    let chapterTitle: String
    let status: ContentStatus
    let wordCount: Int
    let colorLabel: ColorLabel?
    let tagNames: [String]
}

struct OutlineSection: Identifiable, Equatable {
    let id: String
    var title: String
    var matchingCount: Int?
    var rows: [OutlineRow]
    var isStagingArea: Bool
}

struct CardGroup: Identifiable {
    let id: String
    var title: String
    var cards: [CardData]
    var matchingCount: Int?
    var destinationChapterId: UUID?
    var isStagingArea: Bool = false
}

@MainActor
final class ModularModeState: ObservableObject {
    @Published var grouping: CardGrouping {
        didSet { reload() }
    }
    @Published var presentationMode: ModularPresentationMode = .corkboard
    @Published var corkboardDensity: CorkboardDensity = .comfortable
    @Published var activeFilters: FilterSet
    @Published private(set) var groups: [CardGroup] = []
    @Published private(set) var outlineSections: [OutlineSection] = []
    @Published private(set) var selectedSceneIds: Set<UUID> = []
    @Published private(set) var renderedCardCount: Int = 0
    @Published private(set) var collapsedGroupIDs: Set<String> = []

    private let projectManager: ProjectManager
    private let navigationState: NavigationState
    private let editorState: EditorState
    private var previewCache: [UUID: String] = [:]
    private var undoStack: [ModularUndoOperation] = []

    init(projectManager: ProjectManager, navigationState: NavigationState, editorState: EditorState, grouping: CardGrouping = .byChapter) {
        self.projectManager = projectManager
        self.navigationState = navigationState
        self.editorState = editorState
        self.grouping = grouping
        self.activeFilters = navigationState.activeFilters
        reload()
    }

    func reload() {
        activeFilters = navigationState.activeFilters
        let builtGroups = buildGroups()
        groups = builtGroups
        synchronizeCollapsedGroups(with: builtGroups.map(\.id))
        outlineSections = builtGroups.map { group in
            OutlineSection(
                id: group.id,
                title: group.title,
                matchingCount: group.matchingCount,
                rows: group.cards.map {
                    OutlineRow(
                        id: $0.sceneId,
                        title: $0.title,
                        synopsis: $0.previewText,
                        chapterTitle: $0.chapterTitle,
                        status: $0.status,
                        wordCount: $0.wordCount,
                        colorLabel: $0.colorLabel,
                        tagNames: $0.tags.map(\.name)
                    )
                },
                isStagingArea: group.isStagingArea
            )
        }
    }

    func selectCard(sceneId: UUID, multiSelect: Bool = false) {
        if multiSelect {
            if selectedSceneIds.contains(sceneId) {
                selectedSceneIds.remove(sceneId)
            } else {
                selectedSceneIds.insert(sceneId)
            }
        } else {
            selectedSceneIds = [sceneId]
        }
        navigationState.navigateTo(sceneId: sceneId)
    }

    func openCard(sceneId: UUID) {
        editorState.navigateToScene(id: sceneId)
        navigationState.navigateTo(sceneId: sceneId)
    }

    func dragCard(sceneId: UUID, toChapterId: UUID, atIndex: Int) throws {
        let manifest = projectManager.getManifest()
        try projectManager.moveScene(sceneId: sceneId, toChapterId: toChapterId, atIndex: atIndex)
        if let sourceChapter = manifest.hierarchy.chapters.first(where: { $0.scenes.contains(sceneId) }),
           let sourceIndex = sourceChapter.scenes.firstIndex(of: sceneId) {
            undoStack.append(.sceneMove(sceneId: sceneId, chapterId: sourceChapter.id, index: sourceIndex))
        } else if let stagingIndex = manifest.hierarchy.stagingScenes.firstIndex(of: sceneId) {
            undoStack.append(.sceneMoveFromStaging(sceneId: sceneId, index: stagingIndex))
        } else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }
        reload()
    }

    func dragCardToStaging(sceneId: UUID) throws {
        let manifest = projectManager.getManifest()
        guard let sourceChapter = manifest.hierarchy.chapters.first(where: { $0.scenes.contains(sceneId) }),
              let sourceIndex = sourceChapter.scenes.firstIndex(of: sceneId) else {
            throw ProjectIOError.sceneNotFound(sceneId)
        }

        try projectManager.moveToStaging(sceneId: sceneId)
        undoStack.append(.sceneMove(sceneId: sceneId, chapterId: sourceChapter.id, index: sourceIndex))
        reload()
    }

    func dragCard(sceneId: UUID, toStatus status: ContentStatus) throws {
        let original = projectManager
            .getManifest()
            .hierarchy
            .scenes
            .first(where: { $0.id == sceneId })?
            .status

        try projectManager.updateSceneMetadata(
            sceneId: sceneId,
            updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: status, tags: nil, colorLabel: nil, metadata: nil)
        )

        if let original {
            undoStack.append(.statusChange(sceneIds: [sceneId], previousStatus: original))
        }
        reload()
    }

    func bulkSetStatus(sceneIds: Set<UUID>, status: ContentStatus) throws {
        var previousStatus: ContentStatus?

        for id in sceneIds {
            if previousStatus == nil {
                previousStatus = projectManager.getManifest().hierarchy.scenes.first(where: { $0.id == id })?.status
            }
            try projectManager.updateSceneMetadata(
                sceneId: id,
                updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: status, tags: nil, colorLabel: nil, metadata: nil)
            )
        }

        if let previousStatus {
            undoStack.append(.statusChange(sceneIds: Array(sceneIds), previousStatus: previousStatus))
        }
        reload()
    }

    func undoLastOperation() throws {
        guard let op = undoStack.popLast() else { return }
        switch op {
        case let .sceneMove(sceneId, chapterId, index):
            try projectManager.moveScene(sceneId: sceneId, toChapterId: chapterId, atIndex: index)
        case let .sceneMoveFromStaging(sceneId, _):
            try projectManager.moveToStaging(sceneId: sceneId)
        case let .statusChange(sceneIds, previousStatus):
            for sceneId in sceneIds {
                try projectManager.updateSceneMetadata(
                    sceneId: sceneId,
                    updates: SceneMetadataUpdate(title: nil, synopsis: nil, status: previousStatus, tags: nil, colorLabel: nil, metadata: nil)
                )
            }
        }
        reload()
    }

    func visibleCards(viewportRange: Range<Int>, buffer: Int = 10, maxRendered: Int = 49) -> [CardData] {
        let flatCards = groups.flatMap(\.cards)
        guard !flatCards.isEmpty else {
            renderedCardCount = 0
            return []
        }

        let start = max(0, viewportRange.lowerBound - buffer)
        let end = min(flatCards.count, viewportRange.upperBound + buffer)
        let cards = Array(flatCards[start..<end]).prefix(maxRendered)
        renderedCardCount = cards.count
        return Array(cards)
    }

    func toggleGroupCollapsed(_ groupID: String) {
        if collapsedGroupIDs.contains(groupID) {
            collapsedGroupIDs.remove(groupID)
        } else {
            collapsedGroupIDs.insert(groupID)
        }
    }

    func collapseAllGroups() {
        collapsedGroupIDs = Set(groups.map(\.id))
    }

    func expandAllGroups() {
        collapsedGroupIDs.removeAll()
    }

    func isGroupCollapsed(_ groupID: String) -> Bool {
        collapsedGroupIDs.contains(groupID)
    }

    private func buildGroups() -> [CardGroup] {
        guard projectManager.currentProject != nil else { return [] }
        let manifest = projectManager.getManifest()
        let tagsById = Dictionary(uniqueKeysWithValues: (projectManager.currentProject?.tags ?? []).map { ($0.id, $0) })
        let sceneById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0) })
        let chaptersById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.chapters.map { ($0.id, $0) })

        func card(from scene: ManifestScene) -> CardData {
            let preview: String
            if !scene.synopsis.isEmpty {
                preview = scene.synopsis
            } else if let cached = previewCache[scene.id] {
                preview = cached
            } else if let content = try? projectManager.loadSceneContent(sceneId: scene.id), !content.isEmpty {
                preview = content
                    .split(whereSeparator: \ .isWhitespace)
                    .prefix(50)
                    .joined(separator: " ")
                previewCache[scene.id] = preview
            } else {
                preview = "(Empty)"
            }

            let resolvedTags = scene.tags.compactMap { tagsById[$0] }
            let chapterTitle: String
            if let chapterId = scene.parentChapterId {
                chapterTitle = chaptersById[chapterId]?.title ?? "Unknown Chapter"
            } else {
                chapterTitle = "Staging Area"
            }

            return CardData(
                sceneId: scene.id,
                title: scene.title,
                previewText: preview,
                wordCount: scene.wordCount,
                status: scene.status,
                colorLabel: scene.colorLabel,
                tags: resolvedTags,
                chapterTitle: chapterTitle
            )
        }

        func filtered(_ cards: [CardData]) -> [CardData] {
            cards.filter { card in
                guard let scene = sceneById[card.sceneId] else { return false }
                let sceneModel = Scene(
                    id: scene.id,
                    title: scene.title,
                    content: "",
                    synopsis: scene.synopsis,
                    status: scene.status,
                    tags: scene.tags,
                    colorLabel: scene.colorLabel,
                    metadata: scene.metadata,
                    sequenceIndex: scene.sequenceIndex,
                    wordCount: scene.wordCount,
                    createdAt: scene.createdAt,
                    modifiedAt: scene.modifiedAt
                )
                return !activeFilters.isActive || activeFilters.matches(scene: sceneModel)
            }
        }

        switch grouping {
        case .flat:
            let cards = filtered(manifest.hierarchy.scenes.map(card(from:)))
            return [CardGroup(id: "flat", title: "All Scenes", cards: cards, matchingCount: activeFilters.isActive ? cards.count : nil, destinationChapterId: nil, isStagingArea: false)]

        case .byChapter:
            var chapterGroups = manifest.hierarchy.chapters
                .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                .map { chapter -> CardGroup in
                    let cards = filtered(chapter.scenes.compactMap { sceneById[$0] }.map(card(from:)))
                    return CardGroup(
                        id: chapter.id.uuidString,
                        title: chapter.title,
                        cards: cards,
                        matchingCount: activeFilters.isActive ? cards.count : nil,
                        destinationChapterId: chapter.id,
                        isStagingArea: false
                    )
                }

            let stagingCards = filtered(manifest.hierarchy.stagingScenes.compactMap { sceneById[$0] }.map(card(from:)))
            chapterGroups.append(
                CardGroup(
                    id: "staging",
                    title: "Staging Area",
                    cards: stagingCards,
                    matchingCount: activeFilters.isActive ? stagingCards.count : nil,
                    destinationChapterId: nil,
                    isStagingArea: true
                )
            )
            return chapterGroups

        case let .byTag(tagId):
            let cards = filtered(manifest.hierarchy.scenes.map(card(from:))).filter { $0.tags.contains(where: { $0.id == tagId }) }
            return [CardGroup(id: tagId.uuidString, title: "Tag", cards: cards, matchingCount: activeFilters.isActive ? cards.count : nil, destinationChapterId: nil, isStagingArea: false)]

        case .byStatus:
            return ContentStatus.allCases.map { status in
                let cards = filtered(manifest.hierarchy.scenes.map(card(from:))).filter { $0.status == status }
                return CardGroup(id: status.rawValue, title: status.rawValue, cards: cards, matchingCount: activeFilters.isActive ? cards.count : nil, destinationChapterId: nil, isStagingArea: false)
            }
        }
    }

    private func synchronizeCollapsedGroups(with activeIDs: [String]) {
        collapsedGroupIDs = collapsedGroupIDs.intersection(Set(activeIDs))
    }
}

private enum ModularUndoOperation {
    case sceneMove(sceneId: UUID, chapterId: UUID, index: Int)
    case sceneMoveFromStaging(sceneId: UUID, index: Int)
    case statusChange(sceneIds: [UUID], previousStatus: ContentStatus)
}
