import Foundation

protocol MarkdownParser {
    func parse(_ text: String) -> [MarkdownBlock]
    func incrementalUpdate(editRange: Range<Int>, newText: String, existingBlocks: [MarkdownBlock]) -> [MarkdownBlock]
}

enum MarkdownBlock {
    case heading(level: Int, text: AttributedString, sourceRange: Range<Int>)
    case paragraph(text: AttributedString, sourceRange: Range<Int>)
    case blockQuote(blocks: [MarkdownBlock], sourceRange: Range<Int>)
    case codeBlock(language: String?, code: String, sourceRange: Range<Int>)
    case horizontalRule(sourceRange: Range<Int>)
    case footnote(id: String, content: AttributedString, sourceRange: Range<Int>)

    var sourceRange: Range<Int> {
        switch self {
        case let .heading(_, _, sourceRange): return sourceRange
        case let .paragraph(_, sourceRange): return sourceRange
        case let .blockQuote(_, sourceRange): return sourceRange
        case let .codeBlock(_, _, sourceRange): return sourceRange
        case let .horizontalRule(sourceRange): return sourceRange
        case let .footnote(_, _, sourceRange): return sourceRange
        }
    }
}

final class SimpleMarkdownParser: MarkdownParser {
    private(set) var lastIncrementalReparseRange: Range<Int>?
    private(set) var lastIncrementalReparsedBlockCount: Int = 0
    private var currentText: String = ""

    func parse(_ text: String) -> [MarkdownBlock] {
        currentText = text
        lastIncrementalReparseRange = nil
        lastIncrementalReparsedBlockCount = 0
        return parseAll(text)
    }

    func incrementalUpdate(editRange: Range<Int>, newText: String, existingBlocks: [MarkdownBlock]) -> [MarkdownBlock] {
        let bounded = max(0, min(editRange.lowerBound, currentText.count))..<max(0, min(editRange.upperBound, currentText.count))
        replaceSubrange(in: &currentText, range: bounded, with: newText)

        guard !existingBlocks.isEmpty else {
            return parse(currentText)
        }

        let overlapping = existingBlocks.enumerated().filter { _, block in
            rangesOverlap(block.sourceRange, bounded)
        }.map(\.offset)

        guard let firstOverlap = overlapping.first, let lastOverlap = overlapping.last else {
            lastIncrementalReparseRange = bounded
            let parsed = parseAll(currentText)
            lastIncrementalReparsedBlockCount = parsed.count
            return parsed
        }

        let reparseStart = existingBlocks[max(0, firstOverlap - 1)].sourceRange.lowerBound
        let reparseEnd = existingBlocks[min(existingBlocks.count - 1, lastOverlap + 1)].sourceRange.upperBound
        let clampedRange = max(0, min(reparseStart, currentText.count))..<max(0, min(reparseEnd + max(0, newText.count - bounded.count), currentText.count))

        lastIncrementalReparseRange = clampedRange

        let unaffectedPrefix = existingBlocks.prefix { $0.sourceRange.upperBound <= clampedRange.lowerBound }
        let unaffectedSuffix = Array(
            existingBlocks
                .reversed()
                .prefix { $0.sourceRange.lowerBound >= clampedRange.upperBound }
                .reversed()
        )

        let midText = String(slice(of: currentText, range: clampedRange))
        let reparsed = parseAll(midText, baseOffset: clampedRange.lowerBound)
        lastIncrementalReparsedBlockCount = reparsed.count

        return Array(unaffectedPrefix) + reparsed + unaffectedSuffix
    }

    static func shouldRevealRawMarkdown(cursorPosition: Int, block: MarkdownBlock) -> Bool {
        block.sourceRange.contains(cursorPosition)
    }

    private func parseAll(_ text: String, baseOffset: Int = 0) -> [MarkdownBlock] {
        var blocks: [MarkdownBlock] = []
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \ .isNewline)
        var cursor = 0
        var inCodeBlock = false
        var codeLanguage: String?
        var codeLines: [String] = []
        var codeStart = 0

        for line in lines {
            let lineString = String(line)
            let lineStart = cursor
            let lineEnd = lineStart + lineString.count
            cursor = lineEnd + 1

            if lineString.hasPrefix("```") {
                if inCodeBlock {
                    let code = codeLines.joined(separator: "\n")
                    blocks.append(.codeBlock(language: codeLanguage, code: code, sourceRange: baseOffset + codeStart..<baseOffset + lineEnd))
                    inCodeBlock = false
                    codeLanguage = nil
                    codeLines.removeAll()
                } else {
                    inCodeBlock = true
                    codeStart = lineStart
                    let lang = lineString.dropFirst(3).trimmingCharacters(in: .whitespaces)
                    codeLanguage = lang.isEmpty ? nil : lang
                }
                continue
            }

            if inCodeBlock {
                codeLines.append(lineString)
                continue
            }

            if let heading = parseHeading(lineString, range: baseOffset + lineStart..<baseOffset + lineEnd) {
                blocks.append(heading)
                continue
            }

            if isHorizontalRule(lineString) {
                blocks.append(.horizontalRule(sourceRange: baseOffset + lineStart..<baseOffset + lineEnd))
                continue
            }

            if let footnote = parseFootnote(lineString, range: baseOffset + lineStart..<baseOffset + lineEnd) {
                blocks.append(footnote)
                continue
            }

            if lineString.hasPrefix(">") {
                let inner = lineString.dropFirst().trimmingCharacters(in: .whitespaces)
                let quoteParagraph = MarkdownBlock.paragraph(text: AttributedString(inner), sourceRange: baseOffset + lineStart..<baseOffset + lineEnd)
                blocks.append(.blockQuote(blocks: [quoteParagraph], sourceRange: baseOffset + lineStart..<baseOffset + lineEnd))
                continue
            }

            blocks.append(.paragraph(text: parseInline(lineString), sourceRange: baseOffset + lineStart..<baseOffset + lineEnd))
        }

        if inCodeBlock {
            let code = codeLines.joined(separator: "\n")
            blocks.append(.codeBlock(language: codeLanguage, code: code, sourceRange: baseOffset + codeStart..<baseOffset + text.count))
        }

        return blocks
    }

    private func parseHeading(_ line: String, range: Range<Int>) -> MarkdownBlock? {
        let hashes = line.prefix { $0 == "#" }
        let level = hashes.count
        guard (1...6).contains(level), line.dropFirst(level).hasPrefix(" ") else { return nil }
        let content = line.dropFirst(level).trimmingCharacters(in: .whitespaces)
        return .heading(level: level, text: AttributedString(content), sourceRange: range)
    }

    private func parseFootnote(_ line: String, range: Range<Int>) -> MarkdownBlock? {
        guard line.hasPrefix("[^") else { return nil }
        guard let closing = line.firstIndex(of: "]"), line[closing...].hasPrefix("]:"), line.count > 4 else { return nil }
        let id = String(line[line.index(line.startIndex, offsetBy: 2)..<closing])
        let contentStart = line.index(closing, offsetBy: 2)
        let content = line[contentStart...].trimmingCharacters(in: .whitespaces)
        return .footnote(id: id, content: AttributedString(content), sourceRange: range)
    }

    private func isHorizontalRule(_ line: String) -> Bool {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        return trimmed == "---" || trimmed == "***"
    }

    private func parseInline(_ text: String) -> AttributedString {
        var result = text
        result = result.replacingOccurrences(of: "**", with: "")
        result = result.replacingOccurrences(of: "*", with: "")
        result = result.replacingOccurrences(of: "~~", with: "")
        return AttributedString(result)
    }

    private func rangesOverlap(_ lhs: Range<Int>, _ rhs: Range<Int>) -> Bool {
        if rhs.isEmpty {
            return rhs.lowerBound >= lhs.lowerBound && rhs.lowerBound <= lhs.upperBound
        }
        return lhs.lowerBound < rhs.upperBound && rhs.lowerBound < lhs.upperBound
    }

    private func replaceSubrange(in text: inout String, range: Range<Int>, with replacement: String) {
        let lower = text.index(text.startIndex, offsetBy: range.lowerBound)
        let upper = text.index(text.startIndex, offsetBy: range.upperBound)
        text.replaceSubrange(lower..<upper, with: replacement)
    }

    private func slice(of text: String, range: Range<Int>) -> Substring {
        let lower = text.index(text.startIndex, offsetBy: max(0, min(range.lowerBound, text.count)))
        let upper = text.index(text.startIndex, offsetBy: max(0, min(range.upperBound, text.count)))
        return text[lower..<upper]
    }
}
