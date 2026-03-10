import Foundation

@MainActor
protocol SearchEngine {
    // Index management
    func buildIndex(for project: Project) async
    func updateIndex(sceneId: UUID, content: String)

    // Search
    func search(query: SearchQuery) -> [SearchResult]
    func searchCount(query: SearchQuery) -> Int

    // Replace
    func replaceNext(in editorState: EditorState, replacement: String)
    func replaceAll(query: SearchQuery, replacement: String) throws -> ReplaceReport
    func replaceAll(query: SearchQuery, replacement: String, inSceneIDs: [UUID]) throws -> ReplaceReport
}

struct SearchQuery {
    var text: String
    var isRegex: Bool
    var isCaseSensitive: Bool
    var isWholeWord: Bool
    var scope: SearchScope

    init(
        text: String,
        isRegex: Bool = false,
        isCaseSensitive: Bool = false,
        isWholeWord: Bool = false,
        scope: SearchScope = .entireProject
    ) {
        self.text = text
        self.isRegex = isRegex
        self.isCaseSensitive = isCaseSensitive
        self.isWholeWord = isWholeWord
        self.scope = scope
    }
}

enum SearchScope {
    case currentScene
    case currentChapter
    case selectedChapters(ids: [UUID])
    case entireProject
    case markdownFormatting(MarkdownElement)
}

enum MarkdownElement {
    case heading(level: Int?)
    case bold
    case italic
    case strikethrough
    case codeBlock
    case inlineCode
    case blockQuote
    case link
    case footnote
}

struct SearchResult {
    let sceneId: UUID
    let sceneTitle: String
    let chapterTitle: String
    let matchRange: Range<Int>
    let contextSnippet: String
    let matchText: String
}

struct ReplaceError: Error, Equatable {
    let sceneId: UUID
    let message: String
}

struct ReplaceReport {
    let replacementCount: Int
    let scenesAffected: Int
    let errors: [ReplaceError]
}

@MainActor
final class IndexedSearchEngine: SearchEngine {
    private let projectManager: ProjectManager
    private let currentSceneProvider: () -> UUID?
    private let currentChapterProvider: () -> UUID?
    private let unsavedSceneProvider: () -> (sceneId: UUID, content: String)?

    private var sceneIndex: [UUID: String] = [:]
    private var hasBuiltIndex = false
    private var lastQuery: SearchQuery?
    private var replaceUndoStack: [[UUID: String]] = []

    private(set) var lastErrorMessage: String?

    init(
        projectManager: ProjectManager,
        currentSceneProvider: @escaping () -> UUID? = { nil },
        currentChapterProvider: @escaping () -> UUID? = { nil },
        unsavedSceneProvider: @escaping () -> (sceneId: UUID, content: String)? = { nil }
    ) {
        self.projectManager = projectManager
        self.currentSceneProvider = currentSceneProvider
        self.currentChapterProvider = currentChapterProvider
        self.unsavedSceneProvider = unsavedSceneProvider
    }

    func buildIndex(for project: Project) async {
        _ = project
        sceneIndex.removeAll()
        for scene in projectManager.getManifest().hierarchy.scenes {
            let content = (try? projectManager.loadSceneContent(sceneId: scene.id)) ?? ""
            sceneIndex[scene.id] = content
            await Task.yield()
        }
        hasBuiltIndex = true
    }

    func updateIndex(sceneId: UUID, content: String) {
        sceneIndex[sceneId] = content
    }

    func search(query: SearchQuery) -> [SearchResult] {
        lastQuery = query
        lastErrorMessage = nil

        let isFormattingQuery: Bool
        if case .markdownFormatting = query.scope {
            isFormattingQuery = true
        } else {
            isFormattingQuery = false
        }

        if query.text.isEmpty && !isFormattingQuery {
            return []
        }

        let manifest = projectManager.getManifest()
        let sceneMetaById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.scenes.map { ($0.id, $0) })
        let chapterById = Dictionary(uniqueKeysWithValues: manifest.hierarchy.chapters.map { ($0.id, $0.title) })

        var results: [SearchResult] = []
        for sceneId in scopedSceneIds(for: query.scope, manifest: manifest) {
            guard let sceneMeta = sceneMetaById[sceneId] else { continue }
            let content = contentForSearch(sceneId: sceneId)
            let matchData = matches(in: content, query: query)
            if matchData == nil && lastErrorMessage != nil {
                return []
            }
            for match in matchData ?? [] {
                let chapterTitle: String
                if let chapterId = sceneMeta.parentChapterId {
                    chapterTitle = chapterById[chapterId] ?? "Unknown Chapter"
                } else {
                    chapterTitle = "Staging Area"
                }

                results.append(
                    SearchResult(
                        sceneId: sceneMeta.id,
                        sceneTitle: sceneMeta.title,
                        chapterTitle: chapterTitle,
                        matchRange: match.range,
                        contextSnippet: snippet(around: match.range, in: content),
                        matchText: match.text
                    )
                )
            }
        }
        return results
    }

    func searchCount(query: SearchQuery) -> Int {
        search(query: query).count
    }

    func replaceNext(in editorState: EditorState, replacement: String) {
        guard let query = lastQuery else { return }
        let content = editorState.getCurrentContent()
        guard let match = matches(in: content, query: query)?.first else { return }
        let replacementText = replacementForSingleMatch(in: content, query: query, replacement: replacement, range: match.range)
        editorState.replaceText(in: match.range, with: replacementText)
    }

    func replaceAll(query: SearchQuery, replacement: String) throws -> ReplaceReport {
        try replaceAll(query: query, replacement: replacement, inSceneIDs: nil)
    }

    func replaceAll(query: SearchQuery, replacement: String, inSceneIDs: [UUID]) throws -> ReplaceReport {
        try replaceAll(query: query, replacement: replacement, inSceneIDs: Set(inSceneIDs))
    }

    private func replaceAll(query: SearchQuery, replacement: String, inSceneIDs: Set<UUID>?) throws -> ReplaceReport {
        let manifest = projectManager.getManifest()
        var replacementCount = 0
        var scenesAffected = 0
        var errors: [ReplaceError] = []
        var originalsByScene: [UUID: String] = [:]

        for sceneId in scopedSceneIds(for: query.scope, manifest: manifest) {
            if let inSceneIDs, !inSceneIDs.contains(sceneId) {
                continue
            }
            let original = contentForSearch(sceneId: sceneId)
            guard let transform = transformedContent(original, query: query, replacement: replacement) else {
                if lastErrorMessage != nil { break }
                continue
            }

            if transform.count == 0 {
                continue
            }

            originalsByScene[sceneId] = original
            do {
                try projectManager.saveSceneContent(sceneId: sceneId, content: transform.content)
                updateIndex(sceneId: sceneId, content: transform.content)
                replacementCount += transform.count
                scenesAffected += 1
            } catch {
                errors.append(ReplaceError(sceneId: sceneId, message: error.localizedDescription))
            }
        }

        if !originalsByScene.isEmpty {
            replaceUndoStack.append(originalsByScene)
        }

        return ReplaceReport(replacementCount: replacementCount, scenesAffected: scenesAffected, errors: errors)
    }

    func undoLastReplaceAll() throws {
        guard let snapshot = replaceUndoStack.popLast() else { return }
        for (sceneId, originalContent) in snapshot {
            try projectManager.saveSceneContent(sceneId: sceneId, content: originalContent)
            updateIndex(sceneId: sceneId, content: originalContent)
        }
    }

    private func contentForSearch(sceneId: UUID) -> String {
        if let unsaved = unsavedSceneProvider(), unsaved.sceneId == sceneId {
            return unsaved.content
        }
        if hasBuiltIndex, let indexed = sceneIndex[sceneId] {
            return indexed
        }
        return (try? projectManager.loadSceneContent(sceneId: sceneId)) ?? ""
    }

    private func scopedSceneIds(for scope: SearchScope, manifest: Manifest) -> [UUID] {
        switch scope {
        case .entireProject, .markdownFormatting:
            return manifest.hierarchy.scenes.map(\.id)
        case .currentScene:
            if let scene = currentSceneProvider() {
                return [scene]
            }
            return []
        case .currentChapter:
            guard let chapterId = currentChapterProvider(),
                  let chapter = manifest.hierarchy.chapters.first(where: { $0.id == chapterId }) else {
                return []
            }
            return chapter.scenes
        case let .selectedChapters(ids):
            let selected = Set(ids)
            return manifest.hierarchy.chapters
                .filter { selected.contains($0.id) }
                .flatMap(\.scenes)
        }
    }

    private func transformedContent(_ content: String, query: SearchQuery, replacement: String) -> (content: String, count: Int)? {
        guard let regex = regex(for: query) else {
            return query.text.isEmpty ? (content, 0) : nil
        }

        let range = NSRange(content.startIndex..<content.endIndex, in: content)
        let count = regex.numberOfMatches(in: content, range: range)
        guard count > 0 else {
            return (content, 0)
        }
        let replaced = regex.stringByReplacingMatches(in: content, range: range, withTemplate: replacement)
        return (replaced, count)
    }

    private func replacementForSingleMatch(in content: String, query: SearchQuery, replacement: String, range: Range<Int>) -> String {
        if !query.isRegex {
            return replacement
        }
        guard let regex = regex(for: query) else { return replacement }

        let start = content.index(content.startIndex, offsetBy: range.lowerBound)
        let end = content.index(content.startIndex, offsetBy: range.upperBound)
        let target = String(content[start..<end])
        let nsRange = NSRange(target.startIndex..<target.endIndex, in: target)
        return regex.stringByReplacingMatches(in: target, range: nsRange, withTemplate: replacement)
    }

    private func matches(in content: String, query: SearchQuery) -> [(range: Range<Int>, text: String)]? {
        if case let .markdownFormatting(element) = query.scope {
            return formattingMatches(in: content, element: element)
        }

        guard let regex = regex(for: query) else {
            return query.text.isEmpty ? [] : nil
        }

        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let found = regex.matches(in: content, range: nsRange)
        return found.compactMap { match in
            guard let swiftRange = Range(match.range, in: content) else { return nil }
            let lower = content.distance(from: content.startIndex, to: swiftRange.lowerBound)
            let upper = content.distance(from: content.startIndex, to: swiftRange.upperBound)
            return (lower..<upper, String(content[swiftRange]))
        }
    }

    private func regex(for query: SearchQuery) -> NSRegularExpression? {
        var pattern = query.isRegex ? query.text : NSRegularExpression.escapedPattern(for: query.text)
        if query.isWholeWord {
            pattern = "\\b(?:\(pattern))\\b"
        }
        let options: NSRegularExpression.Options = query.isCaseSensitive ? [] : [.caseInsensitive]

        do {
            return try NSRegularExpression(pattern: pattern, options: options)
        } catch {
            lastErrorMessage = "Invalid regex: \(error.localizedDescription)"
            return nil
        }
    }

    private func formattingMatches(in content: String, element: MarkdownElement) -> [(range: Range<Int>, text: String)] {
        switch element {
        case let .heading(level):
            if let level {
                return captureGroupMatches(in: content, pattern: "(?m)^#{\(level)}\\s+(.+)$", group: 1, options: [])
            }
            return captureGroupMatches(in: content, pattern: "(?m)^#{1,6}\\s+(.+)$", group: 1, options: [])
        case .bold:
            return captureGroupMatches(in: content, pattern: "\\*\\*(.+?)\\*\\*|__(.+?)__", group: [1, 2], options: [])
        case .italic:
            return captureGroupMatches(in: content, pattern: "(?<!\\*)\\*([^*\\n]+)\\*(?!\\*)|(?<!_)_([^_\\n]+)_(?!_)", group: [1, 2], options: [])
        case .strikethrough:
            return captureGroupMatches(in: content, pattern: "~~(.+?)~~", group: 1, options: [])
        case .codeBlock:
            return captureGroupMatches(in: content, pattern: "```(?:[^\\n]*\\n)?([\\s\\S]*?)```", group: 1, options: [])
        case .inlineCode:
            return captureGroupMatches(in: content, pattern: "`([^`\\n]+)`", group: 1, options: [])
        case .blockQuote:
            return captureGroupMatches(in: content, pattern: "(?m)^>\\s?(.*)$", group: 1, options: [])
        case .link:
            return captureGroupMatches(in: content, pattern: "\\[([^\\]]+)\\]\\(([^\\)]+)\\)", group: 1, options: [])
        case .footnote:
            return captureGroupMatches(in: content, pattern: "\\[\\^([^\\]]+)\\]", group: 1, options: [])
        }
    }

    private func captureGroupMatches(
        in content: String,
        pattern: String,
        group: Int,
        options: NSRegularExpression.Options
    ) -> [(range: Range<Int>, text: String)] {
        captureGroupMatches(in: content, pattern: pattern, group: [group], options: options)
    }

    private func captureGroupMatches(
        in content: String,
        pattern: String,
        group: [Int],
        options: NSRegularExpression.Options
    ) -> [(range: Range<Int>, text: String)] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return [] }
        let nsRange = NSRange(content.startIndex..<content.endIndex, in: content)
        let found = regex.matches(in: content, range: nsRange)
        return found.compactMap { match in
            let captureRange: NSRange? = group
                .map { match.range(at: $0) }
                .first(where: { $0.location != NSNotFound && $0.length > 0 })

            guard let captureRange,
                  let swiftRange = Range(captureRange, in: content) else {
                return nil
            }
            let lower = content.distance(from: content.startIndex, to: swiftRange.lowerBound)
            let upper = content.distance(from: content.startIndex, to: swiftRange.upperBound)
            return (lower..<upper, String(content[swiftRange]))
        }
    }

    private func snippet(around range: Range<Int>, in content: String, radius: Int = 25) -> String {
        let lower = max(0, range.lowerBound - radius)
        let upper = min(content.count, range.upperBound + radius)
        let start = content.index(content.startIndex, offsetBy: lower)
        let end = content.index(content.startIndex, offsetBy: upper)
        return String(content[start..<end]).replacingOccurrences(of: "\n", with: " ")
    }
}
