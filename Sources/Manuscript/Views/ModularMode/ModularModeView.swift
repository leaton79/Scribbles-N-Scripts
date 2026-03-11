import SwiftUI
import UniformTypeIdentifiers

struct ModularModeView: View {
    @ObservedObject var navigationState: NavigationState
    @ObservedObject var editorState: EditorState

    var grouping: CardGrouping
    var activeFilters: FilterSet
    @ObservedObject var modularState: ModularModeState
    @Environment(\.appThemePalette) private var palette

    func selectCard(sceneId: UUID) {
        modularState.selectCard(sceneId: sceneId)
    }

    func openCard(sceneId: UUID) {
        modularState.openCard(sceneId: sceneId)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                modularControls
                if modularState.presentationMode == .corkboard {
                    corkboardView
                } else {
                    outlinerView
                }
            }
            .padding()
        }
        .background(palette.canvas)
    }

    private var modularControls: some View {
        HStack(spacing: 12) {
            Picker("Layout", selection: $modularState.presentationMode) {
                Text("Corkboard").tag(ModularPresentationMode.corkboard)
                Text("Outliner").tag(ModularPresentationMode.outliner)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 280)
            .accessibilityLabel("Modular layout")

            Picker("Grouping", selection: $modularState.grouping) {
                Text("Chapters").tag(CardGrouping.byChapter)
                Text("Flat").tag(CardGrouping.flat)
                Text("Status").tag(CardGrouping.byStatus)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)
            .accessibilityLabel("Modular grouping")

            if modularState.presentationMode == .corkboard {
                Picker("Density", selection: $modularState.corkboardDensity) {
                    Text("Comfortable").tag(CorkboardDensity.comfortable)
                    Text("Compact").tag(CorkboardDensity.compact)
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 260)
                .accessibilityLabel("Corkboard density")

                Button("Collapse All") {
                    modularState.collapseAllGroups()
                }
                .buttonStyle(.borderless)

                Button("Expand All") {
                    modularState.expandAllGroups()
                }
                .buttonStyle(.borderless)
            }

            Spacer()

            Text(modularState.presentationMode == .corkboard ? "Spatial cards for structure and drag-reorder." : "Scene list with synopsis, status, and chapter context.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var corkboardView: some View {
        ForEach(modularState.groups) { group in
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    modularState.toggleGroupCollapsed(group.id)
                } label: {
                    HStack {
                        Image(systemName: modularState.isGroupCollapsed(group.id) ? "chevron.right" : "chevron.down")
                            .font(.caption)
                        groupHeader(title: group.title, matchingCount: group.matchingCount)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(modularState.isGroupCollapsed(group.id) ? "Expand" : "Collapse") \(group.title)")

                if !modularState.isGroupCollapsed(group.id) {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: modularState.corkboardDensity == .compact ? 160 : 200), spacing: 12)], spacing: 12) {
                        ForEach(group.cards, id: \.sceneId) { card in
                            CardView(
                                card: card,
                                isSelected: modularState.selectedSceneIds.contains(card.sceneId),
                                density: modularState.corkboardDensity
                            )
                                .onTapGesture { selectCard(sceneId: card.sceneId) }
                                .onTapGesture(count: 2) { openCard(sceneId: card.sceneId) }
                                .onDrag {
                                    NSItemProvider(object: card.sceneId.uuidString as NSString)
                                }
                                .accessibilityElement(children: .combine)
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(group.isStagingArea ? Color.orange.opacity(0.10) : palette.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(group.isStagingArea ? Color.orange.opacity(0.22) : palette.border, lineWidth: 1)
                    )
                    .shadow(color: palette.softShadow, radius: 10, x: 0, y: 5)
                    .onDrop(of: [UTType.text], isTargeted: nil) { providers in
                        handleDrop(providers: providers, into: group)
                    }
                }
            }
        }
    }

    private var outlinerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            ForEach(modularState.outlineSections) { section in
                VStack(alignment: .leading, spacing: 8) {
                    groupHeader(title: section.title, matchingCount: section.matchingCount)

                    VStack(spacing: 0) {
                        ForEach(section.rows) { row in
                            OutlineRowView(
                                row: row,
                                isSelected: modularState.selectedSceneIds.contains(row.id),
                                onSelect: { selectCard(sceneId: row.id) },
                                onOpen: { openCard(sceneId: row.id) }
                            )
                            if row.id != section.rows.last?.id {
                                Divider()
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(section.isStagingArea ? Color.orange.opacity(0.10) : palette.panel)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(section.isStagingArea ? Color.orange.opacity(0.22) : palette.border, lineWidth: 1)
                    )
                    .shadow(color: palette.softShadow, radius: 10, x: 0, y: 5)
                }
            }
        }
    }

    private func groupHeader(title: String, matchingCount: Int?) -> some View {
        HStack {
            Text(title)
                .font(.headline.weight(.semibold))
            if let matchingCount {
                Text("(\(matchingCount) matching)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 2)
    }

    private func handleDrop(providers: [NSItemProvider], into group: CardGroup) -> Bool {
        guard let provider = providers.first else { return false }
        provider.loadItem(forTypeIdentifier: UTType.text.identifier, options: nil) { item, _ in
            let stringValue: String?
            switch item {
            case let data as Data:
                stringValue = String(data: data, encoding: .utf8)
            case let string as String:
                stringValue = string
            default:
                stringValue = nil
            }
            guard let raw = stringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let sceneID = UUID(uuidString: raw) else { return }
            Task { @MainActor in
                do {
                    if group.isStagingArea {
                        try modularState.dragCardToStaging(sceneId: sceneID)
                    } else if let chapterID = group.destinationChapterId {
                        try modularState.dragCard(sceneId: sceneID, toChapterId: chapterID, atIndex: group.cards.count)
                    }
                } catch {
                    // Drop failures should not crash interaction.
                }
            }
        }
        return true
    }
}

private struct CardView: View {
    let card: CardData
    let isSelected: Bool
    let density: CorkboardDensity
    @Environment(\.appThemePalette) private var palette
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(card.title)
                .font(density == .compact ? .subheadline.weight(.semibold) : .headline)
                .lineLimit(2)

            Text(card.previewText)
                .font(density == .compact ? .caption : .subheadline)
                .lineLimit(density == .compact ? 2 : 4)
                .foregroundStyle(.secondary)

            HStack {
                Text("\(card.wordCount) words")
                    .font(.caption)
                Spacer()
                Text(card.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.statusFill(card.status), in: Capsule())
                    .foregroundStyle(palette.statusText(card.status))
            }

            HStack(spacing: 6) {
                if let colorLabel = card.colorLabel {
                    Circle()
                        .fill(palette.colorLabelFill(colorLabel))
                        .frame(width: 8, height: 8)
                        .overlay(Text(colorLabel.rawValue.prefix(1).uppercased()).font(.system(size: 1)))
                }
                ForEach(card.tags.prefix(density == .compact ? 2 : 3), id: \.id) { tag in
                    Text(tag.name)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(palette.tagFill())
                        .foregroundStyle(palette.tagText)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(density == .compact ? 10 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.interactiveFill(isSelected: isSelected, isHovered: isHovering))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.interactiveBorder(isSelected: isSelected, isHovered: isHovering), lineWidth: isSelected ? 2 : 1)
        )
        .shadow(color: isHovering ? palette.softShadow.opacity(1.4) : palette.softShadow, radius: isHovering ? 12 : 8, x: 0, y: isHovering ? 8 : 4)
        .scaleEffect(isHovering ? 1.01 : 1.0)
        .animation(.easeOut(duration: 0.14), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

private struct OutlineRowView: View {
    let row: OutlineRow
    let isSelected: Bool
    let onSelect: () -> Void
    let onOpen: () -> Void
    @Environment(\.appThemePalette) private var palette
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                if let colorLabel = row.colorLabel {
                    Circle()
                        .fill(palette.colorLabelFill(colorLabel))
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .strokeBorder(Color.primary.opacity(0.15), lineWidth: 0.5)
                        )
                        .help(colorLabel.rawValue.capitalized)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.title)
                        .font(.headline)
                    Text(row.chapterTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(row.status.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(palette.statusFill(row.status), in: Capsule())
                    .foregroundStyle(palette.statusText(row.status))
                Text("\(row.wordCount) words")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(row.synopsis)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if !row.tagNames.isEmpty {
                HStack(spacing: 6) {
                    ForEach(row.tagNames.prefix(4), id: \.self) { tagName in
                        Text(tagName)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(palette.tagFill())
                            .foregroundStyle(palette.tagText)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.interactiveFill(isSelected: isSelected, isHovered: isHovering))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(palette.interactiveBorder(isSelected: isSelected, isHovered: isHovering), lineWidth: isSelected ? 1.5 : 1)
        )
        .shadow(color: isHovering ? palette.softShadow.opacity(1.3) : .clear, radius: 8, x: 0, y: 4)
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onTapGesture(count: 2, perform: onOpen)
        .onHover { hovering in
            isHovering = hovering
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
