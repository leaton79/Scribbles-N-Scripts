import SwiftUI

struct SidebarView: View {
    @ObservedObject var navigationState: NavigationState
    let nodes: [SidebarNode]
    var onSelect: ((SidebarNode) -> Void)? = nil

    var body: some View {
        List {
            ForEach(nodes) { node in
                NodeRow(node: node, depth: 0, onSelect: onSelect)
            }
        }
    }
}

private struct NodeRow: View {
    let node: SidebarNode
    let depth: Int
    let onSelect: ((SidebarNode) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Button {
                onSelect?(node)
            } label: {
                HStack {
                    Text(String(repeating: "  ", count: depth) + node.title)
                        .lineLimit(1)
                    Spacer()
                    if let goalProgressText = node.goalProgressText {
                        Text(goalProgressText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(node.wordCount)")
                            .foregroundStyle(.secondary)
                    }
                    if let matchingCount = node.matchingCount {
                        Text("(\(matchingCount) matching)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .buttonStyle(.plain)
            ForEach(node.children) { child in
                NodeRow(node: child, depth: depth + 1, onSelect: onSelect)
            }
        }
    }
}
