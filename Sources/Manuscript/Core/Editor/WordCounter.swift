import Foundation

struct WordCounter {
    static func count(_ text: String) -> Int {
        let cjkCount = text.unicodeScalars.filter(isCJK).count

        let pattern = "[A-Za-z0-9]+(?:['’][A-Za-z0-9]+)?"
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        let latinCount = regex?.numberOfMatches(in: text, range: nsRange) ?? 0

        return latinCount + cjkCount
    }

    static func readingTimeMinutes(_ wordCount: Int) -> Int {
        max(1, Int(ceil(Double(max(0, wordCount)) / 250.0)))
    }

    private static func isCJK(_ scalar: UnicodeScalar) -> Bool {
        switch scalar.value {
        case 0x4E00...0x9FFF,
             0x3400...0x4DBF,
             0x20000...0x2A6DF,
             0x2A700...0x2B73F,
             0x2B740...0x2B81F,
             0x2B820...0x2CEAF,
             0x3040...0x309F,
             0x30A0...0x30FF,
             0xAC00...0xD7AF:
            return true
        default:
            return false
        }
    }
}
