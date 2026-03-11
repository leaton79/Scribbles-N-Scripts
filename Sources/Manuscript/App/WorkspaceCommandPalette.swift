import Foundation

enum CommandPaletteAction: Equatable {
    case createProject
    case openProject
    case switchProject
    case reopenLastProject
    case openRecentProject(URL)
    case saveProject
    case saveProjectAs
    case renameProject
    case duplicateRecoveryProject
    case exportRecoveryMarkdown
    case showProjectSettings
    case setTheme(AppTheme)
    case applyAppearancePreset(UUID)
    case showImportExport
    case showTimeline
    case showEntities
    case showSources
    case showNotes
    case showScratchpad
    case createChapter
    case createScene
    case createSceneBelow
    case duplicateSelectedScene
    case createBackup
    case saveAndBackup
    case setMode(ViewMode)
    case toggleSplit
    case openSelectionInSplit
    case toggleInspector
    case moveSelectedSceneUp
    case moveSelectedSceneDown
    case moveSelectedSceneToChapter
    case sendSelectedSceneToStaging
    case revealSelectionInSidebar
    case showCorkboard
    case showOutliner
    case modularGroupingChapter
    case modularGroupingFlat
    case modularGroupingStatus
    case corkboardDensityComfortable
    case corkboardDensityCompact
    case collapseAllModularGroups
    case expandAllModularGroups
    case navigateToPreviousScene
    case navigateToNextScene
    case showInlineSearch
    case showProjectSearch
    case undoLastReplaceBatch
    case redoLastReplaceBatch
    case navigateToChapter(UUID)
    case navigateToScene(UUID)
}

struct CommandPaletteItem: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let category: String
    let shortcut: String?
    let keywords: [String]
    let isEnabled: Bool
    let action: CommandPaletteAction
    let sortOrder: Int

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let haystack = ([title, subtitle, category] + keywords)
            .joined(separator: " ")
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let tokens = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        return tokens.allSatisfy { haystack.contains($0) }
    }
}

@MainActor
enum WorkspaceCommandPalette {
    static func items(workspace: WorkspaceCoordinator, commands: WorkspaceCommandBindings) -> [CommandPaletteItem] {
        var items: [CommandPaletteItem] = []
        var order = 0

        func append(
            _ title: String,
            subtitle: String,
            category: String,
            shortcut: String? = nil,
            keywords: [String] = [],
            isEnabled: Bool = true,
            action: CommandPaletteAction
        ) {
            items.append(
                CommandPaletteItem(
                    id: "\(category)-\(order)-\(title)",
                    title: title,
                    subtitle: subtitle,
                    category: category,
                    shortcut: shortcut,
                    keywords: keywords,
                    isEnabled: isEnabled,
                    action: action,
                    sortOrder: order
                )
            )
            order += 1
        }

        append(
            "New Project",
            subtitle: "Create a new project",
            category: "Project",
            keywords: ["create", "project"],
            action: .createProject
        )
        append(
            "Open Project",
            subtitle: "Choose a project folder",
            category: "Project",
            keywords: ["open", "folder", "project"],
            action: .openProject
        )
        append(
            "Switch Project",
            subtitle: "Search open and recent projects",
            category: "Project",
            shortcut: "⇧⌘K",
            keywords: ["project", "switcher", "recent"],
            action: .switchProject
        )
        append(
            "Reopen Last Project",
            subtitle: "Open the most recently used project",
            category: "Project",
            keywords: ["recent", "last", "project"],
            isEnabled: commands.canReopenLastProject,
            action: .reopenLastProject
        )
        append(
            "Save Project",
            subtitle: workspace.projectDisplayName,
            category: "Project",
            shortcut: "⌘S",
            keywords: ["save", "project"],
            isEnabled: commands.canSaveProject,
            action: .saveProject
        )
        append(
            "Save Project As",
            subtitle: "Duplicate the current project under a new name",
            category: "Project",
            keywords: ["save", "copy", "duplicate", "project"],
            isEnabled: commands.canSaveProjectAs,
            action: .saveProjectAs
        )
        append(
            "Rename Project",
            subtitle: "Rename the current project",
            category: "Project",
            keywords: ["rename", "project"],
            isEnabled: commands.canRenameProject,
            action: .renameProject
        )
        append(
            "Duplicate Recovery Project",
            subtitle: "Create a writable recovered copy beside the damaged project",
            category: "Project",
            keywords: ["recovery", "duplicate", "salvage", "copy"],
            isEnabled: workspace.isRecoveryMode,
            action: .duplicateRecoveryProject
        )
        append(
            "Export Recovery Markdown",
            subtitle: "Write a salvage markdown export outside the damaged project",
            category: "Project",
            keywords: ["recovery", "export", "salvage", "markdown"],
            isEnabled: workspace.isRecoveryMode,
            action: .exportRecoveryMarkdown
        )
        append(
            "Project Settings",
            subtitle: "Edit project settings, staging recovery, and metadata schema",
            category: "Project",
            shortcut: "⌘,",
            keywords: ["settings", "preferences", "metadata", "schema", "staging"],
            isEnabled: workspace.hasOpenProject,
            action: .showProjectSettings
        )
        for theme in AppTheme.allCases {
            append(
                "Theme: \(theme.displayName)",
                subtitle: theme == commands.currentTheme ? "Current workspace theme" : "Switch the workspace appearance",
                category: "Appearance",
                keywords: ["theme", "appearance", "color", theme.displayName.lowercased()],
                isEnabled: workspace.hasOpenProject,
                action: .setTheme(theme)
            )
        }
        for preset in commands.appearancePresets {
            append(
                "Appearance Preset: \(preset.name)",
                subtitle: "\(preset.theme.displayName) • \(preset.fontName) \(preset.fontSize) pt • \(Int(preset.editorContentWidth)) pt width",
                category: "Appearance",
                keywords: [
                    "appearance",
                    "preset",
                    "theme",
                    preset.name.lowercased(),
                    preset.theme.displayName.lowercased(),
                    preset.fontName.lowercased()
                ],
                isEnabled: workspace.hasOpenProject,
                action: .applyAppearancePreset(preset.id)
            )
        }
        append(
            "Import / Export",
            subtitle: "Import scenes or compile the project to export formats",
            category: "Project",
            keywords: ["import", "export", "compile", "markdown", "html"],
            isEnabled: commands.canShowImportExport,
            action: .showImportExport
        )
        append(
            "Entities",
            subtitle: "Track recurring characters, locations, and linked scenes",
            category: "Project",
            keywords: ["entities", "characters", "locations", "tracking"],
            isEnabled: commands.canCreateProjectContent,
            action: .showEntities
        )
        append(
            "Timeline",
            subtitle: "Arrange story events across tracks and linked scenes",
            category: "Project",
            keywords: ["timeline", "events", "plot", "tracks"],
            isEnabled: commands.canCreateProjectContent,
            action: .showTimeline
        )
        append(
            "Sources",
            subtitle: "Manage sources and insert citations while writing",
            category: "Project",
            keywords: ["sources", "citations", "research", "references"],
            isEnabled: commands.canCreateProjectContent,
            action: .showSources
        )
        append(
            "Notes",
            subtitle: "Capture project notes linked to scenes and entities",
            category: "Project",
            keywords: ["notes", "scene notes", "entity notes", "research"],
            isEnabled: commands.canCreateProjectContent,
            action: .showNotes
        )
        append(
            "Scratchpad",
            subtitle: "Store reusable snippets and clipboard captures for fast insertion",
            category: "Project",
            keywords: ["scratchpad", "clipboard", "snippets", "reuse"],
            isEnabled: commands.canCreateProjectContent,
            action: .showScratchpad
        )
        append(
            "Create Backup",
            subtitle: "Write a timestamped backup archive",
            category: "Project",
            keywords: ["backup", "archive"],
            isEnabled: commands.canCreateBackup,
            action: .createBackup
        )
        append(
            "Save and Backup",
            subtitle: "Save changes and create a backup",
            category: "Project",
            shortcut: "⌥⌘S",
            keywords: ["save", "backup", "archive"],
            isEnabled: commands.canSaveAndBackup,
            action: .saveAndBackup
        )
        append(
            "New Chapter",
            subtitle: "Create a new chapter in the current project",
            category: "Create",
            shortcut: "⇧⌘N",
            keywords: ["chapter", "create", "new"],
            isEnabled: commands.canCreateProjectContent,
            action: .createChapter
        )
        append(
            "New Scene",
            subtitle: "Create a new scene in the current chapter",
            category: "Create",
            shortcut: "⌘N",
            keywords: ["scene", "create", "new"],
            isEnabled: commands.canCreateProjectContent,
            action: .createScene
        )
        append(
            "New Scene Below",
            subtitle: "Insert a scene after the current scene",
            category: "Create",
            shortcut: "⌘↩",
            keywords: ["scene", "below", "insert", "next"],
            isEnabled: commands.canCreateSceneBelow,
            action: .createSceneBelow
        )
        append(
            "Duplicate Scene",
            subtitle: "Copy the selected scene below the original",
            category: "Create",
            shortcut: "⇧⌘D",
            keywords: ["scene", "duplicate", "copy"],
            isEnabled: commands.canDuplicateSelectedScene,
            action: .duplicateSelectedScene
        )
        append(
            "Switch to Linear Mode",
            subtitle: "Open the manuscript in the linear editor",
            category: "View",
            shortcut: "⌘1",
            keywords: ["mode", "linear", "view"],
            isEnabled: commands.canSwitchToLinearMode,
            action: .setMode(.linear)
        )
        append(
            "Switch to Modular Mode",
            subtitle: "Open the manuscript in the modular board",
            category: "View",
            shortcut: "⌘2",
            keywords: ["mode", "modular", "view", "cards"],
            isEnabled: commands.canSwitchToModularMode,
            action: .setMode(.modular)
        )
        append(
            commands.splitToggleTitle,
            subtitle: "Open or close the split editor",
            category: "View",
            shortcut: "⌘\\",
            keywords: ["split", "editor", "pane"],
            isEnabled: commands.canToggleSplitEditor,
            action: .toggleSplit
        )
        append(
            "Open in Split",
            subtitle: "Open the selected scene in the split editor",
            category: "View",
            keywords: ["split", "open", "scene", "compare"],
            isEnabled: commands.canOpenSelectionInSplit,
            action: .openSelectionInSplit
        )
        append(
            "Reveal in Sidebar",
            subtitle: "Select the current scene in the sidebar",
            category: "View",
            keywords: ["sidebar", "reveal", "scene", "selection"],
            isEnabled: commands.canRevealSelectionInSidebar,
            action: .revealSelectionInSidebar
        )
        append(
            "Show Corkboard",
            subtitle: "Use the modular card board",
            category: "View",
            keywords: ["modular", "corkboard", "board", "cards"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .showCorkboard
        )
        append(
            "Show Outliner",
            subtitle: "Use the modular outline view",
            category: "View",
            keywords: ["modular", "outliner", "outline", "list"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .showOutliner
        )
        append(
            "Group Modular by Chapter",
            subtitle: "Section modular content by chapter",
            category: "View",
            keywords: ["modular", "group", "chapter"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .modularGroupingChapter
        )
        append(
            "Group Modular Flat",
            subtitle: "Show modular content in one pool",
            category: "View",
            keywords: ["modular", "group", "flat"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .modularGroupingFlat
        )
        append(
            "Group Modular by Status",
            subtitle: "Section modular content by status",
            category: "View",
            keywords: ["modular", "group", "status"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .modularGroupingStatus
        )
        append(
            "Corkboard Density Comfortable",
            subtitle: "Use larger, more detailed cards",
            category: "View",
            keywords: ["corkboard", "density", "comfortable"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .corkboardDensityComfortable
        )
        append(
            "Corkboard Density Compact",
            subtitle: "Use tighter cards for overview scanning",
            category: "View",
            keywords: ["corkboard", "density", "compact"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .corkboardDensityCompact
        )
        append(
            "Collapse All Modular Groups",
            subtitle: "Fold all corkboard groups",
            category: "View",
            keywords: ["modular", "collapse", "groups"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .collapseAllModularGroups
        )
        append(
            "Expand All Modular Groups",
            subtitle: "Expand all corkboard groups",
            category: "View",
            keywords: ["modular", "expand", "groups"],
            isEnabled: commands.canUseModularPresentationControls,
            action: .expandAllModularGroups
        )
        append(
            commands.inspectorToggleTitle,
            subtitle: "Show or hide the inspector panel",
            category: "View",
            shortcut: "⌥⌘I",
            keywords: ["inspector", "metadata", "panel"],
            isEnabled: commands.canToggleInspector,
            action: .toggleInspector
        )
        append(
            "Previous Scene",
            subtitle: "Move to the previous scene in linear mode",
            category: "Navigate",
            shortcut: "⌘[",
            keywords: ["scene", "previous", "back"],
            isEnabled: commands.canNavigateToPreviousScene,
            action: .navigateToPreviousScene
        )
        append(
            "Next Scene",
            subtitle: "Move to the next scene in linear mode",
            category: "Navigate",
            shortcut: "⌘]",
            keywords: ["scene", "next", "forward"],
            isEnabled: commands.canNavigateToNextScene,
            action: .navigateToNextScene
        )
        append(
            "Move Scene Up",
            subtitle: "Reorder the selected scene earlier in its chapter",
            category: "Navigate",
            keywords: ["scene", "move", "up", "reorder"],
            isEnabled: commands.canMoveSelectedSceneUp,
            action: .moveSelectedSceneUp
        )
        append(
            "Move Scene Down",
            subtitle: "Reorder the selected scene later in its chapter",
            category: "Navigate",
            keywords: ["scene", "move", "down", "reorder"],
            isEnabled: commands.canMoveSelectedSceneDown,
            action: .moveSelectedSceneDown
        )
        append(
            "Move to Chapter",
            subtitle: "Move the selected scene into another chapter",
            category: "Navigate",
            keywords: ["scene", "move", "chapter", "rehome"],
            isEnabled: commands.canMoveSelectedSceneToAnotherChapter,
            action: .moveSelectedSceneToChapter
        )
        append(
            "Send to Staging",
            subtitle: "Move the selected scene into the staging area",
            category: "Navigate",
            keywords: ["scene", "staging", "send", "shelve"],
            isEnabled: commands.canSendSelectedSceneToStaging,
            action: .sendSelectedSceneToStaging
        )
        append(
            "Find in Current Scene",
            subtitle: "Open inline find for the active scene",
            category: "Search",
            shortcut: "⌘F",
            keywords: ["find", "search", "scene"],
            isEnabled: commands.canSearchProject,
            action: .showInlineSearch
        )
        append(
            "Find in Project",
            subtitle: "Search across the full manuscript",
            category: "Search",
            shortcut: "⇧⌘F",
            keywords: ["find", "search", "project"],
            isEnabled: commands.canSearchProject,
            action: .showProjectSearch
        )
        append(
            commands.replaceUndoMenuTitle,
            subtitle: "Undo the most recent replace-all batch",
            category: "Search",
            keywords: ["replace", "undo", "search"],
            isEnabled: commands.canUndoLastReplaceBatch,
            action: .undoLastReplaceBatch
        )
        append(
            commands.replaceRedoMenuTitle,
            subtitle: "Redo the most recently undone replace-all batch",
            category: "Search",
            keywords: ["replace", "redo", "search"],
            isEnabled: commands.canRedoLastReplaceBatch,
            action: .redoLastReplaceBatch
        )

        let currentProjectPath = workspace.projectManager.projectRootURL?.path
        for project in commands.switchableProjects where project.url.path != currentProjectPath {
            append(
                "Open Project: \(project.name)",
                subtitle: project.url.path,
                category: "Projects",
                keywords: ["open", "project", project.name, project.url.lastPathComponent],
                action: .openRecentProject(project.url)
            )
        }

        guard workspace.hasOpenProject else {
            return items
        }

        let manifest = workspace.projectManager.getManifest()
        let orderedChapters = manifest.hierarchy.chapters.sorted {
            if $0.sequenceIndex == $1.sequenceIndex {
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
            return $0.sequenceIndex < $1.sequenceIndex
        }

        for chapter in orderedChapters {
            append(
                "Go to Chapter: \(chapter.title)",
                subtitle: "Navigation",
                category: "Navigate",
                keywords: ["chapter", "go", "jump", chapter.title],
                action: .navigateToChapter(chapter.id)
            )

            let scenes = manifest.hierarchy.scenes
                .filter { $0.parentChapterId == chapter.id }
                .sorted {
                    if $0.sequenceIndex == $1.sequenceIndex {
                        return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
                    }
                    return $0.sequenceIndex < $1.sequenceIndex
                }

            for scene in scenes {
                append(
                    "Go to Scene: \(scene.title)",
                    subtitle: chapter.title,
                    category: "Navigate",
                    keywords: ["scene", "go", "jump", scene.title, chapter.title],
                    action: .navigateToScene(scene.id)
                )
            }
        }

        return items
    }

    static func filteredItems(
        workspace: WorkspaceCoordinator,
        commands: WorkspaceCommandBindings,
        query: String
    ) -> [CommandPaletteItem] {
        items(workspace: workspace, commands: commands)
            .filter { $0.matches(query: query) }
            .sorted { lhs, rhs in
                lhs.sortOrder < rhs.sortOrder
            }
    }
}
