import Foundation

struct SidebarNode: Identifiable, Equatable {
    let id: UUID
    var title: String
    var level: HierarchyLevel
    var wordCount: Int
    var colorLabel: ColorLabel?
    var goalProgressText: String?
    var children: [SidebarNode]
    var matchingCount: Int?
}

enum SidebarHierarchyBuilder {
    static func build(project: Project, filters: FilterSet = FilterSet()) -> [SidebarNode] {
        var nodes: [SidebarNode] = []

        if project.manuscript.parts.isEmpty {
            for chapter in project.manuscript.chapters.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }) {
                nodes.append(buildChapterNode(chapter: chapter, filters: filters))
            }
        } else {
            for part in project.manuscript.parts.sorted(by: { $0.sequenceIndex < $1.sequenceIndex }) {
                let chapterNodes = part.chapters
                    .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
                    .map { buildChapterNode(chapter: $0, filters: filters) }

                let partWordCount = chapterNodes.reduce(0) { $0 + $1.wordCount }
                let matching = chapterNodes.reduce(0) { $0 + ($1.matchingCount ?? $1.children.count) }

                nodes.append(
                    SidebarNode(
                        id: part.id,
                        title: part.title,
                        level: .part,
                        wordCount: partWordCount,
                        colorLabel: nil,
                        goalProgressText: nil,
                        children: chapterNodes,
                        matchingCount: filters.isActive ? matching : nil
                    )
                )
            }
        }

        let stagingScenes = project.manuscript.stagingArea
            .filter { !filters.isActive || filters.matches(scene: $0) }
            .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
            .map {
                SidebarNode(
                    id: $0.id,
                    title: $0.title,
                    level: .scene,
                    wordCount: $0.wordCount,
                    colorLabel: $0.colorLabel,
                    goalProgressText: nil,
                    children: [],
                    matchingCount: nil
                )
            }

        if !stagingScenes.isEmpty {
            let unassignedId = UUID(uuidString: "00000000-0000-0000-0000-000000000001") ?? UUID()
            nodes.append(
                SidebarNode(
                    id: unassignedId,
                    title: "Unassigned",
                    level: .chapter,
                    wordCount: stagingScenes.reduce(0) { $0 + $1.wordCount },
                    colorLabel: nil,
                    goalProgressText: nil,
                    children: stagingScenes,
                    matchingCount: filters.isActive ? stagingScenes.count : nil
                )
            )
        }

        return nodes
    }

    static func manuscriptWordCount(project: Project) -> Int {
        let partSceneWords = project.manuscript.parts
            .flatMap(\.chapters)
            .flatMap(\.scenes)
            .reduce(0) { $0 + $1.wordCount }

        let topLevelChapterSceneWords = project.manuscript.chapters
            .flatMap(\.scenes)
            .reduce(0) { $0 + $1.wordCount }

        let stagingWords = project.manuscript.stagingArea.reduce(0) { $0 + $1.wordCount }

        return partSceneWords + topLevelChapterSceneWords + stagingWords
    }

    private static func buildChapterNode(chapter: Chapter, filters: FilterSet) -> SidebarNode {
        let filteredScenes = chapter.scenes
            .sorted(by: { $0.sequenceIndex < $1.sequenceIndex })
            .filter { !filters.isActive || filters.matches(scene: $0) }

        let sceneNodes = filteredScenes.map {
            SidebarNode(
                id: $0.id,
                title: $0.title,
                level: .scene,
                wordCount: $0.wordCount,
                colorLabel: $0.colorLabel,
                goalProgressText: nil,
                children: [],
                matchingCount: nil
            )
        }

        let goalProgressText: String?
        if let goal = chapter.goalWordCount {
            goalProgressText = "\(formatWordCount(chapter.scenes.reduce(0) { $0 + $1.wordCount })) / \(formatWordCount(goal))"
        } else {
            goalProgressText = nil
        }

        return SidebarNode(
            id: chapter.id,
            title: chapter.title,
            level: .chapter,
            wordCount: chapter.scenes.reduce(0) { $0 + $1.wordCount },
            colorLabel: nil,
            goalProgressText: goalProgressText,
            children: sceneNodes,
            matchingCount: filters.isActive ? filteredScenes.count : nil
        )
    }

    private static func formatWordCount(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
