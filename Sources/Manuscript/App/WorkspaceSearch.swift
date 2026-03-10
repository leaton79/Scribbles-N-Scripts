import Foundation

enum WorkspaceSearchScope: String, CaseIterable, Identifiable {
    case currentScene
    case currentChapter
    case entireProject

    var id: String { rawValue }

    var title: String {
        switch self {
        case .currentScene:
            return "Current Scene"
        case .currentChapter:
            return "Current Chapter"
        case .entireProject:
            return "Entire Project"
        }
    }

    var searchScope: SearchScope {
        switch self {
        case .currentScene:
            return .currentScene
        case .currentChapter:
            return .currentChapter
        case .entireProject:
            return .entireProject
        }
    }
}
