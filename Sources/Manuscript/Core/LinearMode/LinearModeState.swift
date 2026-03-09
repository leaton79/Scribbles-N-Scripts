import Combine
import Foundation

struct SceneBoundary: Equatable {
    let precedingSceneId: UUID
    let followingSceneId: UUID
    let chapterBreak: Bool
    let chapterTitle: String?
}

@MainActor
final class LinearModeState: ObservableObject {
    @Published private(set) var orderedSceneIds: [UUID] = []
    @Published private(set) var boundaries: [SceneBoundary] = []
    @Published private(set) var beginningIndicatorVisible = false

    private let projectManager: ProjectManager
    private let navigationState: NavigationState
    private let editorState: EditorState
    private var chapterBySceneId: [UUID: UUID] = [:]
    private var chapterTitleById: [UUID: String] = [:]

    private var sceneCache = LRUSceneCache(capacity: 5)
    private(set) var preloadedSceneIds: [UUID] = []

    init(projectManager: ProjectManager, navigationState: NavigationState, editorState: EditorState) {
        self.projectManager = projectManager
        self.navigationState = navigationState
        self.editorState = editorState
        reloadSequence()
    }

    func reloadSequence() {
        let manifest = projectManager.getManifest()
        let chaptersById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.chapters.map { ($0.id, $0) })

        var orderedChapterIds: [UUID] = []
        if manifest.hierarchy.parts.isEmpty {
            orderedChapterIds = manifest.hierarchy.chapters
                .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                .map(\.id)
        } else {
            for part in manifest.hierarchy.parts.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }) {
                orderedChapterIds.append(contentsOf: part.chapters)
            }
            let topLevel = manifest.hierarchy.chapters
                .filter { $0.parentPartId == nil && !orderedChapterIds.contains($0.id) }
                .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                .map(\.id)
            orderedChapterIds.append(contentsOf: topLevel)
        }

        var sequence: [UUID] = []
        chapterBySceneId.removeAll()
        chapterTitleById.removeAll()

        for chapterId in orderedChapterIds {
            guard let chapter = chaptersById[chapterId] else { continue }
            chapterTitleById[chapter.id] = chapter.title
            for sceneId in chapter.scenes {
                chapterBySceneId[sceneId] = chapter.id
                sequence.append(sceneId)
            }
        }

        orderedSceneIds = sequence
        boundaries = zip(sequence, sequence.dropFirst()).map { prior, next in
            let priorChapter = chapterBySceneId[prior]
            let nextChapter = chapterBySceneId[next]
            let isBreak = priorChapter != nextChapter
            return SceneBoundary(
                precedingSceneId: prior,
                followingSceneId: next,
                chapterBreak: isBreak,
                chapterTitle: isBreak ? chapterTitleById[nextChapter ?? UUID()] : nil
            )
        }

        if editorState.currentSceneId == nil, let first = orderedSceneIds.first {
            goToScene(id: first)
        }
    }

    func goToNextScene() {
        guard let current = editorState.currentSceneId,
              let index = orderedSceneIds.firstIndex(of: current),
              index + 1 < orderedSceneIds.count else {
            return
        }
        beginningIndicatorVisible = false
        transition(to: orderedSceneIds[index + 1])
    }

    func goToPreviousScene() {
        guard let current = editorState.currentSceneId,
              let index = orderedSceneIds.firstIndex(of: current) else {
            return
        }
        guard index > 0 else {
            beginningIndicatorVisible = true
            return
        }
        beginningIndicatorVisible = false
        transition(to: orderedSceneIds[index - 1])
    }

    func goToScene(id: UUID) {
        guard orderedSceneIds.contains(id) else { return }
        beginningIndicatorVisible = false
        transition(to: id)
    }

    func createNewSceneBelowCurrent(title: String = "Untitled Scene") throws {
        guard let current = editorState.currentSceneId,
              let chapterId = chapterBySceneId[current] else {
            return
        }

        let manifest = projectManager.getManifest()
        guard let chapter = manifest.hierarchy.chapters.first(where: { $0.id == chapterId }),
              let currentIndex = chapter.scenes.firstIndex(of: current) else {
            return
        }

        let newScene = try projectManager.addScene(to: chapterId, at: currentIndex + 1, title: title)
        reloadSequence()
        transition(to: newScene.id)
    }

    func sceneOrderWithTitles() -> [(UUID, String)] {
        let sceneMap = Dictionary(uniqueKeysWithValues: projectManager.getManifest().hierarchy.scenes.map { ($0.id, $0.title) })
        return orderedSceneIds.map { ($0, sceneMap[$0] ?? "") }
    }

    private func transition(to sceneId: UUID) {
        try? editorState.autosaveIfNeeded(projectManager: projectManager)
        editorState.navigateToScene(id: sceneId)
        navigationState.navigateTo(sceneId: sceneId)
        preloadAdjacent(to: sceneId)
    }

    private func preloadAdjacent(to sceneId: UUID) {
        guard let idx = orderedSceneIds.firstIndex(of: sceneId) else { return }
        let neighbors = [idx - 1, idx + 1]
            .filter { $0 >= 0 && $0 < orderedSceneIds.count }
            .map { orderedSceneIds[$0] }

        for neighborId in neighbors {
            if sceneCache.value(for: neighborId) != nil {
                if !preloadedSceneIds.contains(neighborId) {
                    preloadedSceneIds.append(neighborId)
                }
                continue
            }
            if let content = try? projectManager.loadSceneContent(sceneId: neighborId) {
                sceneCache.set(value: content, for: neighborId)
                if !preloadedSceneIds.contains(neighborId) {
                    preloadedSceneIds.append(neighborId)
                }
            }
        }
    }
}

private struct LRUSceneCache {
    private let capacity: Int
    private var order: [UUID] = []
    private var values: [UUID: String] = [:]

    init(capacity: Int) {
        self.capacity = max(1, capacity)
    }

    mutating func set(value: String, for id: UUID) {
        values[id] = value
        touch(id)
        if order.count > capacity, let evicted = order.first {
            order.removeFirst()
            values.removeValue(forKey: evicted)
        }
    }

    mutating func value(for id: UUID) -> String? {
        guard let value = values[id] else { return nil }
        touch(id)
        return value
    }

    private mutating func touch(_ id: UUID) {
        order.removeAll { $0 == id }
        order.append(id)
    }
}
