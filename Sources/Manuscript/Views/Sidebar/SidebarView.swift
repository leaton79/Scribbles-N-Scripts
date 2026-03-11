import SwiftUI

struct SidebarView: View {
    @ObservedObject var navigationState: NavigationState
    let nodes: [SidebarNode]
    var baseFontSize: CGFloat = 15
    var onSelect: ((SidebarNode) -> Void)? = nil

    var body: some View {
        List {
            ForEach(nodes) { node in
                NodeRow(node: node, depth: 0, baseFontSize: baseFontSize, onSelect: onSelect)
                    .listRowInsets(EdgeInsets(top: 4, leading: 12, bottom: 4, trailing: 12))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }
        }
        .font(.system(size: baseFontSize))
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}

private struct NodeRow: View {
    let node: SidebarNode
    let depth: Int
    let baseFontSize: CGFloat
    let onSelect: ((SidebarNode) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button {
                onSelect?(node)
            } label: {
                HStack {
                    Text(node.title)
                        .lineLimit(1)
                        .fontWeight(depth == 0 ? .semibold : .regular)
                    Spacer()
                    if let goalProgressText = node.goalProgressText {
                        Text(goalProgressText)
                            .font(.system(size: max(baseFontSize - 2, 10)))
                            .foregroundStyle(.secondary)
                    } else {
                        Text("\(node.wordCount)")
                            .foregroundStyle(.secondary)
                    }
                    if let matchingCount = node.matchingCount {
                        Text("(\(matchingCount) matching)")
                            .font(.system(size: max(baseFontSize - 2, 10)))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.leading, CGFloat(depth) * 14)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.primary.opacity(0.035))
                )
            }
            .buttonStyle(.plain)
            ForEach(node.children) { child in
                NodeRow(node: child, depth: depth + 1, baseFontSize: baseFontSize, onSelect: onSelect)
            }
        }
    }
}
