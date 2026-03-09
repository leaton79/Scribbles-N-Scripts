import SwiftUI

struct SidebarView: View {
    @ObservedObject var navigationState: NavigationState
    let nodes: [SidebarNode]

    var body: some View {
        List {
            ForEach(nodes) { node in
                NodeRow(node: node, depth: 0)
            }
        }
    }
}

private struct NodeRow: View {
    let node: SidebarNode
    let depth: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(String(repeating: "  ", count: depth) + node.title)
                    .lineLimit(1)
                Spacer()
                Text("\(node.wordCount)")
                    .foregroundStyle(.secondary)
                if let matchingCount = node.matchingCount {
                    Text("(\(matchingCount) matching)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            ForEach(node.children) { child in
                NodeRow(node: child, depth: depth + 1)
            }
        }
    }
}
