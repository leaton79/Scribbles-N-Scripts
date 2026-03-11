import Foundation

enum WorkspaceSearchScope: String, CaseIterable, Identifiable {
    case currentScene
    case currentChapter
    case entireProject
    case selectedChapters
    case formattingItalic
    case formattingBold
    case formattingHeadings
    case formattingStrikethrough
    case formattingCodeBlocks
    case formattingInlineCode
    case formattingBlockQuotes
    case formattingLinks
    case formattingFootnotes

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentScene:
            return "Current Scene"
        case .currentChapter:
            return "Current Chapter"
        case .entireProject:
            return "Entire Project"
        case .selectedChapters:
            return "Selected Chapters"
        case .formattingItalic:
            return "Italic Formatting"
        case .formattingBold:
            return "Bold Formatting"
        case .formattingHeadings:
            return "Headings"
        case .formattingStrikethrough:
            return "Strikethrough"
        case .formattingCodeBlocks:
            return "Code Blocks"
        case .formattingInlineCode:
            return "Inline Code"
        case .formattingBlockQuotes:
            return "Block Quotes"
        case .formattingLinks:
            return "Links"
        case .formattingFootnotes:
            return "Footnotes"
        }
    }
}

enum ReplacePreviewFilter: String, CaseIterable, Identifiable {
    case all
    case included
    case excluded

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all:
            return "All"
        case .included:
            return "Included"
        case .excluded:
            return "Excluded"
        }
    }
}

enum ReplacePreviewSort: String, CaseIterable, Identifiable {
    case manuscriptOrder
    case matchCountDescending
    case sceneTitle

    var id: String { rawValue }

    var title: String {
        switch self {
        case .manuscriptOrder:
            return "Manuscript Order"
        case .matchCountDescending:
            return "Most Matches"
        case .sceneTitle:
            return "Scene Title"
        }
    }
}

struct ReplacePreviewSceneItem: Identifiable, Equatable {
    let id: UUID
    let chapterTitle: String
    let sceneTitle: String
    let matchCount: Int
    let matchTargets: [ReplacePreviewMatchTarget]
    let isIncluded: Bool
    let manuscriptOrder: Int
}

struct ReplacePreviewMatchTarget: Identifiable, Equatable {
    let id: String
    let resultIndex: Int
    let snippet: String
    let matchText: String
}

struct ReplaceBatchHistoryItem: Identifiable, Equatable {
    let id: UUID
    let replacementCount: Int
    let scenesAffected: Int
    let searchText: String
    let replacementText: String
    let createdAt: Date

    var title: String {
        "\"\(searchText)\" -> \"\(replacementText)\""
    }

    var summary: String {
        "\(replacementCount) replacements across \(scenesAffected) scene(s)"
    }
}

struct SearchChapterScopePreset: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let chapterIDs: [UUID]
    let chapterTitles: [String]
    let createdAt: Date

    var summary: String {
        let nonEmptyTitles = chapterTitles.filter { !$0.isEmpty }
        if nonEmptyTitles.isEmpty {
            return "\(chapterIDs.count) chapter(s)"
        }
        if nonEmptyTitles.count == 1 {
            return nonEmptyTitles[0]
        }
        if nonEmptyTitles.count == 2 {
            return "\(nonEmptyTitles[0]), \(nonEmptyTitles[1])"
        }
        return "\(nonEmptyTitles[0]), \(nonEmptyTitles[1]) +\(nonEmptyTitles.count - 2) more"
    }
}

struct SearchResultSection: Identifiable {
    let id: String
    let chapterTitle: String
    let scenes: [SearchResultSceneGroup]
    let matchCount: Int
}

struct SearchResultSceneGroup: Identifiable {
    let id: UUID
    let sceneTitle: String
    let results: [SearchResultListItem]
    let matchCount: Int
}

struct SearchResultListItem: Identifiable {
    let id: String
    let resultIndex: Int
    let result: SearchResult
}

struct ReplaceProgressStatus: Equatable {
    let completedScenes: Int
    let totalScenes: Int
    let replacementsCompleted: Int
    let currentSceneTitle: String?

    var isActive: Bool {
        totalScenes > 0 && completedScenes < totalScenes
    }

    var percentage: Int {
        guard totalScenes > 0 else { return 100 }
        return Int((Double(completedScenes) / Double(totalScenes) * 100.0).rounded())
    }
}
