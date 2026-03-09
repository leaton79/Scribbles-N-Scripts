import SwiftUI

struct ModularModeView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState

    var grouping: CardGrouping
    var activeFilters: FilterSet
    @ObservedObject var modularState: ModularModeState

    func selectCard(sceneId: UUID) {
        modularState.selectCard(sceneId: sceneId)
    }

    func openCard(sceneId: UUID) {
        modularState.openCard(sceneId: sceneId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ForEach(modularState.groups) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(group.title)
                                .font(.headline)
                            if let matching = group.matchingCount {
                                Text("(\(matching) matching)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                            ForEach(group.cards, id: \.sceneId) { card in
                                CardView(card: card, isSelected: modularState.selectedSceneIds.contains(card.sceneId))
                                    .onTapGesture { selectCard(sceneId: card.sceneId) }
                                    .onTapGesture(count: 2) { openCard(sceneId: card.sceneId) }
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

private struct CardView: View {
    let card: CardData
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(.headline)
                .lineLimit(2)

            Text(card.previewText)
                .font(.subheadline)
                .lineLimit(4)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(card.wordCount) words")
                    .font(.caption)
                Spacer()
                Text(card.status.rawValue)
                    .font(.caption)
            }

            HStack(spacing: 6) {
                if let colorLabel = card.colorLabel {
                    Circle().frame(width: 8, height: 8)
                        .overlay(Text(colorLabel.rawValue.prefix(1).uppercased()).font(.system(size: 1)))
                }
                ForEach(card.tags.prefix(3), id: \.id) { tag in
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.thinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10).fill(.ultraThinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 2)
        )
    }
}
