import Foundation

struct BlockRenderer {
    static func visibleBlocks(
        allBlocks: [MarkdownBlock],
        centeredAt index: Int,
        visibleCount: Int = 10,
        buffer: Int = 10,
        maxRendered: Int = 30
    ) -> [MarkdownBlock] {
        guard !allBlocks.isEmpty else { return [] }

        let center = max(0, min(index, allBlocks.count - 1))
        let halfVisible = max(1, visibleCount / 2)

        let start = max(0, center - halfVisible - buffer)
        let end = min(allBlocks.count, center + halfVisible + buffer)

        let window = Array(allBlocks[start..<end])
        if window.count <= maxRendered {
            return window
        }

        let maxStart = max(0, center - maxRendered / 2)
        let maxEnd = min(allBlocks.count, maxStart + maxRendered)
        return Array(allBlocks[maxStart..<maxEnd])
    }
}
