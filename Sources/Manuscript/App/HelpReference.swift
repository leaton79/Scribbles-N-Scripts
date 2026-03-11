import SwiftUI

struct HelpReferenceEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let category: String
    let summary: String
    let whatItDoes: String
    let howToUse: [String]
    let whyUseIt: String
    let menuPath: String?
    let shortcut: String?
    let relatedIDs: [String]
    let keywords: [String]

    func matches(query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }
        let haystack = [
            title,
            category,
            summary,
            whatItDoes,
            whyUseIt,
            menuPath ?? "",
            shortcut ?? ""
        ]
        .appending(contentsOf: howToUse)
        .appending(contentsOf: keywords)
        .joined(separator: " ")
        .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
        let tokens = trimmed
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
        return tokens.allSatisfy { haystack.contains($0) }
    }
}

private extension Array {
    func appending(contentsOf other: [Element]) -> [Element] {
        var copy = self
        copy.append(contentsOf: other)
        return copy
    }
}

enum HelpReferenceLibrary {
    static let entries: [HelpReferenceEntry] = [
        entry(
            "welcome-screen",
            "Welcome Screen",
            category: "Start",
            summary: "The start screen is the home screen you see when no project is open.",
            what: "It gives you the fastest way to begin: create a project, open a project, reopen a recent project, or jump into the Command Palette.",
            how: [
                "Open the app with no project loaded.",
                "Use `New Project` to create a fresh manuscript folder.",
                "Use `Open Project` to choose an existing project folder.",
                "Use `Commands` to open the Command Palette and search for actions."
            ],
            why: "Use it when you are starting a new writing session, switching between manuscripts, or learning the main flow of the app.",
            related: ["command-palette", "switch-project", "open-recent"]
        ),
        entry(
            "command-palette",
            "Command Palette",
            category: "Start",
            summary: "The Command Palette is the fastest way to search for actions, projects, chapters, and scenes.",
            what: "It works like a universal search bar for the app. You can run commands, jump to scenes, and open major panels without digging through menus.",
            how: [
                "Open `Project > Command Palette…`.",
                "Or press `Command-K`.",
                "Type the name of an action, scene, chapter, project, theme, or appearance preset.",
                "Use the arrow keys to move through results and press Return to run the selected item."
            ],
            why: "Use it when you want the quickest keyboard-first way to move around the app or run a command you do not want to hunt for in menus.",
            menuPath: "Project > Command Palette…",
            shortcut: "Command-K",
            related: ["switch-project", "help-reference", "find-project"],
            keywords: ["commands", "search actions", "jump"]
        ),
        entry(
            "switch-project",
            "Switch Project",
            category: "Start",
            summary: "Switch Project lets you jump from the current manuscript to another recent one.",
            what: "It opens a searchable project switcher so you can move between your active project and recent projects without closing the app.",
            how: [
                "Open `Project > Switch Project…`.",
                "Or press `Shift-Command-K`.",
                "Type part of the project name if the list is long.",
                "Choose the project and press Return or click it."
            ],
            why: "Use it when you work on more than one manuscript and want to move between them quickly.",
            menuPath: "Project > Switch Project…",
            shortcut: "Shift-Command-K",
            related: ["welcome-screen", "open-recent", "reopen-last-project"]
        ),
        entry(
            "project-switcher",
            "Project Switcher Sheet",
            category: "Start",
            summary: "The project switcher is the searchable picker for changing manuscripts.",
            what: "It is a focused project list with a search field, keyboard navigation, and direct open action.",
            how: [
                "Open `Project > Switch Project…`.",
                "Type in the search field to narrow the project list.",
                "Use the arrow keys to move through matches and press Return to open the selected project."
            ],
            why: "Use it when you want a dedicated project-changing workflow instead of the broader Command Palette.",
            menuPath: "Project > Switch Project…",
            shortcut: "Shift-Command-K",
            related: ["switch-project", "command-palette", "open-recent"]
        ),
        entry(
            "reopen-last-project",
            "Reopen Last Project",
            category: "Start",
            summary: "Reopen Last Project opens the manuscript you were using most recently.",
            what: "It uses the app's recent-project history to reopen your last active project in one step.",
            how: [
                "Open `Project > Reopen Last Project`.",
                "If the item is disabled, there is no recorded recent project yet."
            ],
            why: "Use it when you usually return to the same manuscript and want the shortest possible path back in.",
            menuPath: "Project > Reopen Last Project",
            related: ["open-recent", "switch-project", "welcome-screen"]
        ),
        entry(
            "open-recent",
            "Open Recent, Clear Recent Projects, and Clean Missing Entries",
            category: "Start",
            summary: "The recent-project list stores projects you opened before and helps you keep that list tidy.",
            what: "Open Recent shows saved project paths. `Clear Recent Projects` removes the list, and `Clean Missing Entries` removes projects that no longer exist on disk.",
            how: [
                "Open `Project > Open Recent`.",
                "Choose a project name to reopen it.",
                "Choose `Clear Recent Projects` to wipe the list.",
                "Choose `Clean Missing Entries` if the list contains deleted or moved projects."
            ],
            why: "Use these options to reopen common manuscripts quickly and keep the recent-project list accurate.",
            menuPath: "Project > Open Recent",
            related: ["reopen-last-project", "switch-project", "welcome-screen"],
            keywords: ["recent", "cleanup", "missing"]
        ),
        entry(
            "save-project",
            "Save Project",
            category: "Project",
            summary: "Save Project writes your current project changes to disk.",
            what: "It saves manifest changes and scene content that is ready to persist, so your current state is stored in the project folder.",
            how: [
                "Open `Project > Save Project`.",
                "Or press `Command-S`."
            ],
            why: "Use it when you want an explicit save point before switching tasks, exporting, or closing the app.",
            menuPath: "Project > Save Project",
            shortcut: "Command-S",
            related: ["save-project-as", "save-and-backup", "create-backup"]
        ),
        entry(
            "save-project-as",
            "Save Project As",
            category: "Project",
            summary: "Save Project As creates a separate copy of the current project under a new name.",
            what: "It duplicates the active project into a new project folder, which is useful when you want a branch, alternate version, or renamed copy.",
            how: [
                "Open `Project > Save Project As…`.",
                "Enter the new project name in the sheet.",
                "Confirm to create the copy."
            ],
            why: "Use it when you want to experiment on a copy without touching the original manuscript.",
            menuPath: "Project > Save Project As…",
            related: ["rename-project", "create-backup", "save-project"]
        ),
        entry(
            "rename-project",
            "Rename Project",
            category: "Project",
            summary: "Rename Project changes the display and folder name of the current project.",
            what: "It updates the current manuscript's name so the app, recent-project list, and project folder stay aligned.",
            how: [
                "Open `Project > Rename Project…`.",
                "Enter the new project name in the sheet.",
                "Confirm to rename the project."
            ],
            why: "Use it when your working title changes or you want the manuscript folder to match the project's real name.",
            menuPath: "Project > Rename Project…",
            related: ["save-project-as", "project-settings"]
        ),
        entry(
            "project-settings",
            "Project Settings",
            category: "Project",
            summary: "Project Settings collects project-level controls such as backups, metadata schema, editor appearance, and more.",
            what: "It is the main settings surface for the current project. You can edit autosave, backups, themes, appearance presets, metadata schema, and recovery-related tools there.",
            how: [
                "Open `Project > Project Settings…`.",
                "Or press `Command-,`.",
                "Move through the sections in the sheet to change the project's settings."
            ],
            why: "Use it when you want to change how the project behaves or looks without editing the manuscript itself.",
            menuPath: "Project > Project Settings…",
            shortcut: "Command-,",
            related: ["themes-and-presets", "create-backup", "metadata-schema", "staging-tray"]
        ),
        entry(
            "import-export",
            "Import / Export",
            category: "Project",
            summary: "Import / Export brings outside text into the project and compiles the manuscript into output formats.",
            what: "It lets you import `.md` or `.txt` content as scenes and export the manuscript to formats like Markdown, HTML, DOCX, PDF, and EPUB using compile presets.",
            how: [
                "Open `Project > Import / Export…`.",
                "Use the import controls to bring in a text file as scenes.",
                "Use the export controls to choose a format, preset, chapter selection, and output settings.",
                "Review warnings and export."
            ],
            why: "Use it when you want to bring an outside draft into the app or publish the current manuscript in another format.",
            menuPath: "Project > Import / Export…",
            related: ["sources", "compile-presets", "create-backup"]
        ),
        entry(
            "timeline",
            "Timeline",
            category: "Project",
            summary: "Timeline tracks story events and links them back to manuscript scenes.",
            what: "It stores events, tracks, descriptions, and linked scenes so you can manage chronology alongside the draft.",
            how: [
                "Open `Project > Timeline…`.",
                "Create or edit events in the timeline sheet.",
                "Link events to scenes so you can jump between the timeline and the manuscript."
            ],
            why: "Use it when you need to track chronology, parallel plot lines, or event order in a long project.",
            menuPath: "Project > Timeline…",
            related: ["entities", "notes", "sources"]
        ),
        entry(
            "entities",
            "Entities",
            category: "Project",
            summary: "Entities tracks recurring people, places, or other named elements in the manuscript.",
            what: "It gives you a structured list of story entities, aliases, linked scenes, mention discovery, and related notes.",
            how: [
                "Open `Project > Entities…`.",
                "Create or edit an entity in the sheet.",
                "Review linked scenes or discovered mentions to keep references consistent."
            ],
            why: "Use it when you want to track story elements across a large manuscript and avoid inconsistency.",
            menuPath: "Project > Entities…",
            related: ["notes", "sources", "inspector", "entity-highlights"]
        ),
        entry(
            "sources",
            "Sources",
            category: "Project",
            summary: "Sources manages citations, research materials, and research file attachments.",
            what: "It stores bibliography records, imported research files, and links between sources, scenes, notes, and entities.",
            how: [
                "Open `Project > Sources…`.",
                "Create or edit a source in the sheet.",
                "Import research files, review linked scenes or notes, and insert citations into the manuscript."
            ],
            why: "Use it when you are writing with references, research notes, or citation keys you want to keep organized in one place.",
            menuPath: "Project > Sources…",
            related: ["notes", "import-export", "scratchpad"]
        ),
        entry(
            "notes",
            "Notes",
            category: "Project",
            summary: "Notes stores project notes that can link to scenes and entities.",
            what: "It gives you a place for planning, reference notes, or revision notes that do not belong inside the manuscript text itself.",
            how: [
                "Open `Project > Notes…`.",
                "Create, edit, or filter notes by folder, linked scene, or linked entity.",
                "Use note links to jump back into the manuscript context."
            ],
            why: "Use it when you want to capture project thinking without cluttering the manuscript.",
            menuPath: "Project > Notes…",
            related: ["sources", "entities", "scratchpad"]
        ),
        entry(
            "scratchpad",
            "Scratchpad",
            category: "Project",
            summary: "Scratchpad is a quick place for fragments, copied lines, and temporary writing scraps.",
            what: "It stores short reusable or temporary text snippets inside the project so they do not get lost in external notes.",
            how: [
                "Open `Project > Scratchpad…`.",
                "Create or edit scratchpad items in the sheet.",
                "Insert a saved item back into the editor when you need it."
            ],
            why: "Use it when you want a project-local clipboard for lines, fragments, or cut text you might reuse later.",
            menuPath: "Project > Scratchpad…",
            related: ["notes", "sources", "command-palette"]
        ),
        entry(
            "scratchpad-capture",
            "Capture Selection to Scratchpad",
            category: "Project",
            summary: "Capture Selection turns current editor text into a scratchpad item.",
            what: "It is the fastest way to save a fragment, paragraph, or line before you cut or revise it.",
            how: [
                "Select text in the editor first.",
                "Open `Project > Scratchpad…`.",
                "Use `Capture Selection` in the sheet header.",
                "Give the captured text a title if needed, then insert it later from the item list."
            ],
            why: "Use it when you are moving fast in revision and want to keep text nearby without creating a formal note.",
            menuPath: "Project > Scratchpad…",
            related: ["scratchpad", "editor-writing", "notes"]
        ),
        entry(
            "new-chapter",
            "New Chapter",
            category: "Project",
            summary: "New Chapter adds a new chapter to the manuscript structure.",
            what: "It creates a new chapter in the current project and places it in the manuscript hierarchy.",
            how: [
                "Open `Project > New Chapter`.",
                "Or press `Shift-Command-N`."
            ],
            why: "Use it when you need a new structural section before adding scenes.",
            menuPath: "Project > New Chapter",
            shortcut: "Shift-Command-N",
            related: ["new-scene", "sidebar", "modular-mode"]
        ),
        entry(
            "new-scene",
            "New Scene",
            category: "Project",
            summary: "New Scene creates a scene in the current manuscript context.",
            what: "It adds a new scene to the active chapter or the current structural location.",
            how: [
                "Open `Project > New Scene`.",
                "Or press `Command-N`."
            ],
            why: "Use it when you want to add a new writing unit to the draft.",
            menuPath: "Project > New Scene",
            shortcut: "Command-N",
            related: ["new-scene-below", "new-chapter", "move-to-chapter"]
        ),
        entry(
            "new-scene-below",
            "New Scene Below",
            category: "Project",
            summary: "New Scene Below inserts a scene directly after the currently selected scene.",
            what: "It creates a new scene immediately under the current one so you can continue a sequence without manual reordering.",
            how: [
                "Select a scene first.",
                "Open `Project > New Scene Below`.",
                "Or press `Command-Return`."
            ],
            why: "Use it when the new scene belongs right after the current one.",
            menuPath: "Project > New Scene Below",
            shortcut: "Command-Return",
            related: ["new-scene", "move-to-chapter", "sidebar"]
        ),
        entry(
            "move-to-chapter",
            "Move to Chapter",
            category: "Project",
            summary: "Move to Chapter moves the selected scene into a different chapter.",
            what: "It opens a target-picker sheet so you can relocate the selected scene without dragging it manually.",
            how: [
                "Select a scene.",
                "Open `Project > Move to Chapter…`.",
                "Choose the destination chapter in the sheet and confirm."
            ],
            why: "Use it when you are reorganizing structure and want an exact target chapter.",
            menuPath: "Project > Move to Chapter…",
            related: ["send-to-staging", "sidebar", "modular-mode"]
        ),
        entry(
            "send-to-staging",
            "Send to Staging",
            category: "Project",
            summary: "Send to Staging removes the selected scene from the active draft and places it in staging.",
            what: "It moves a scene into the staging area so it is preserved but no longer part of the active manuscript flow.",
            how: [
                "Select a scene.",
                "Open `Project > Send to Staging`."
            ],
            why: "Use it when you are not ready to delete a scene but want it out of the main draft.",
            menuPath: "Project > Send to Staging",
            related: ["staging-tray", "move-to-chapter", "modular-mode"]
        ),
        entry(
            "create-backup",
            "Create Backup",
            category: "Project",
            summary: "Create Backup writes a backup archive of the current project.",
            what: "It creates a recoverable backup snapshot in the project's backups area.",
            how: [
                "Open `Project > Create Backup`."
            ],
            why: "Use it when you want a safety copy before a risky edit or major restructure.",
            menuPath: "Project > Create Backup",
            related: ["save-and-backup", "save-project", "recovery-mode"]
        ),
        entry(
            "save-and-backup",
            "Save and Backup",
            category: "Project",
            summary: "Save and Backup saves the project first and then creates a backup archive.",
            what: "It combines the normal save path with a backup pass so you end up with both current disk state and a backup snapshot.",
            how: [
                "Open `Project > Save and Backup`.",
                "Or press `Option-Command-S`."
            ],
            why: "Use it when you want the safest pre-change checkpoint in one step.",
            menuPath: "Project > Save and Backup",
            shortcut: "Option-Command-S",
            related: ["save-project", "create-backup"]
        ),
        entry(
            "linear-mode",
            "Linear Mode",
            category: "View",
            summary: "Linear Mode shows scenes in a manuscript-first reading and drafting flow.",
            what: "It emphasizes writing scene by scene in order, with navigation that follows manuscript sequence.",
            how: [
                "Open `View > Linear Mode`.",
                "Or press `Command-1`."
            ],
            why: "Use it when you want a focused drafting flow close to how the finished manuscript reads.",
            menuPath: "View > Linear Mode",
            shortcut: "Command-1",
            related: ["modular-mode", "split-editor", "previous-next-scene"]
        ),
        entry(
            "modular-mode",
            "Modular Mode",
            category: "View",
            summary: "Modular Mode shows scenes as movable structural units instead of a continuous draft.",
            what: "It gives you a board-style view for planning, grouping, filtering, and restructuring scenes.",
            how: [
                "Open `View > Modular Mode`.",
                "Or press `Command-2`."
            ],
            why: "Use it when you are planning, restructuring, or reviewing story shape rather than line-editing prose.",
            menuPath: "View > Modular Mode",
            shortcut: "Command-2",
            related: ["modular-corkboard", "modular-outliner", "linear-mode"]
        ),
        entry(
            "split-editor",
            "Split Editor and Open in Split",
            category: "View",
            summary: "Split editing lets you keep two scenes or two manuscript positions open at once.",
            what: "The split editor opens a second pane so you can compare scenes, move text, or cross-check references without losing your place.",
            how: [
                "Open `View > Open Split` or `View > Close Split`, depending on the current state.",
                "Or press `Command-\\` to toggle split mode.",
                "Use `View > Open in Split` to open the current selection in the secondary pane."
            ],
            why: "Use it when you need side-by-side drafting, reference checking, or revision work.",
            menuPath: "View > Open Split / Close Split",
            shortcut: "Command-\\",
            related: ["open-in-split", "linear-mode", "inspector"],
            keywords: ["split", "compare"]
        ),
        entry(
            "inspector",
            "Inspector",
            category: "View",
            summary: "The Inspector shows editable details about the current scene, chapter, note, or entity.",
            what: "It is the contextual detail panel on the right side of the workspace. It can show metadata, tags, synopsis, notes, entity details, and command shortcuts tied to the current selection.",
            how: [
                "Open `View > Show Inspector` or `Hide Inspector`, depending on the current state.",
                "Or press `Option-Command-I`."
            ],
            why: "Use it when you want to edit metadata or inspect context without leaving the main writing view.",
            menuPath: "View > Show Inspector / Hide Inspector",
            shortcut: "Option-Command-I",
            related: ["entities", "notes", "metadata-schema"]
        ),
        entry(
            "modular-corkboard",
            "Modular Corkboard",
            category: "View",
            summary: "The corkboard is the card-based version of Modular Mode.",
            what: "It shows scenes as cards that are easy to scan, group, and reorganize visually.",
            how: [
                "Switch to Modular Mode.",
                "Open `View > Modular Corkboard`."
            ],
            why: "Use it when you want a quick visual overview of scene structure.",
            menuPath: "View > Modular Corkboard",
            related: ["modular-mode", "modular-outliner", "modular-grouping"]
        ),
        entry(
            "modular-outliner",
            "Modular Outliner",
            category: "View",
            summary: "The outliner is the list-based version of Modular Mode.",
            what: "It shows chapters and scenes in a denser structured list with more metadata than the corkboard.",
            how: [
                "Switch to Modular Mode.",
                "Open `View > Modular Outliner`."
            ],
            why: "Use it when you want a structure view with more detail and less visual space than the corkboard.",
            menuPath: "View > Modular Outliner",
            related: ["modular-mode", "modular-corkboard", "modular-grouping"]
        ),
        entry(
            "modular-grouping",
            "Modular Grouping and Density Controls",
            category: "View",
            summary: "Grouping and density controls change how scenes are arranged inside Modular Mode.",
            what: "You can group scenes by chapter, flatten them into one stream, or group them by status. You can also choose compact or comfortable card density and collapse or expand all groups.",
            how: [
                "Switch to Modular Mode.",
                "Use `View > Group Modular by Chapter`, `Flat`, or `Status`.",
                "Use `View > Compact Corkboard Density` or `Comfortable Corkboard Density`.",
                "Use `View > Collapse All Modular Groups` or `Expand All Modular Groups`."
            ],
            why: "Use these controls when you want the modular view to match the kind of review you are doing: structural, status-based, or high-density scanning.",
            menuPath: "View > Modular grouping and density commands",
            related: ["modular-mode", "modular-corkboard", "modular-outliner"]
        ),
        entry(
            "previous-next-scene",
            "Previous Scene and Next Scene",
            category: "View",
            summary: "These commands move through the manuscript one scene at a time.",
            what: "They change the active scene selection to the previous or next scene in sequence.",
            how: [
                "Open `View > Previous Scene` or `View > Next Scene`.",
                "Or press `Command-[` for previous and `Command-]` for next."
            ],
            why: "Use them when you want quick sequence-based navigation while drafting or reviewing.",
            menuPath: "View > Previous Scene / Next Scene",
            shortcut: "Command-[ and Command-]",
            related: ["linear-mode", "sidebar", "split-editor"]
        ),
        entry(
            "goals-dashboard",
            "Writing Goals and Statistics",
            category: "View",
            summary: "The goals dashboard shows your writing metrics, targets, and recent progress.",
            what: "It tracks session words, project goals, pacing, history, and trend information.",
            how: [
                "Open `View > Writing Goals & Statistics…`.",
                "Or press `Shift-Command-G`."
            ],
            why: "Use it when you want to measure output, set goals, or see whether you are on pace.",
            menuPath: "View > Writing Goals & Statistics…",
            shortcut: "Shift-Command-G",
            related: ["project-settings", "sidebar"]
        ),
        entry(
            "find-current-scene",
            "Find in Current Scene",
            category: "Find",
            summary: "Find in Current Scene searches only the scene you are editing right now.",
            what: "It opens the inline scene search controls in the editor so you can move through matches in the current scene.",
            how: [
                "Open `Find > Find in Current Scene`.",
                "Or press `Command-F`."
            ],
            why: "Use it when you only need to check or replace text in the current scene, not the whole project.",
            menuPath: "Find > Find in Current Scene",
            shortcut: "Command-F",
            related: ["find-project", "search-highlights"]
        ),
        entry(
            "find-project",
            "Find in Project",
            category: "Find",
            summary: "Find in Project opens the full project search and replace sheet.",
            what: "It searches across scenes and chapters, supports scope controls, preview selection, and batch replace history.",
            how: [
                "Open `Find > Find in Project`.",
                "Or press `Shift-Command-F`.",
                "Enter search text, choose the scope, review grouped results, and optionally use replace controls."
            ],
            why: "Use it when you need manuscript-wide search, scoped replace, or grouped review of matches.",
            menuPath: "Find > Find in Project",
            shortcut: "Shift-Command-F",
            related: ["find-current-scene", "search-highlights", "replace-batches"]
        ),
        entry(
            "find-replace-sheet",
            "Find & Replace Sheet",
            category: "Find",
            summary: "The Find & Replace sheet is the main workspace for manuscript-wide search and replace.",
            what: "It combines search text, replace text, scope controls, result browsing, preview decisions, and replace history in one panel.",
            how: [
                "Open `Find > Find in Project`.",
                "Use the top fields to enter search and replace text.",
                "Review options, grouped results, and preview controls before replacing."
            ],
            why: "Use it when you need a more careful and informed workflow than inline scene search can provide.",
            menuPath: "Find > Find in Project",
            related: ["find-project", "project-search-scopes", "replace-batches"]
        ),
        entry(
            "search-highlights",
            "Search Highlight Display and Reset Highlight Settings",
            category: "Find",
            summary: "These controls change how search highlights behave in the editor.",
            what: "The toggle changes highlight display mode, and reset returns the highlight safety settings to their defaults.",
            how: [
                "Open `Find > Toggle Search Highlight Display`.",
                "Or press `Option-Command-H`.",
                "Open `Find > Reset Highlight Settings` if you want to reset the current highlight cap and safety rules."
            ],
            why: "Use these options when highlights are too noisy, too limited, or you want to return to the default behavior.",
            menuPath: "Find > highlight commands",
            shortcut: "Option-Command-H and Option-Command-0",
            related: ["find-current-scene", "find-project"]
        ),
        entry(
            "replace-batches",
            "Replace Preview, Scene Inclusion, Undo, and Redo",
            category: "Find",
            summary: "Project replace runs as a batch you can preview, narrow, undo, and redo.",
            what: "The replace sheet lets you include or exclude matched scenes, preview snippets, then undo or redo replace batches after the change.",
            how: [
                "Open `Find > Find in Project`.",
                "Enter both Find and Replace text.",
                "Review the preview list and choose which matched scenes to include.",
                "Use `Find > Select All Matched Scenes` or `Deselect All Matched Scenes` for bulk changes.",
                "Use `Find > Undo Last Replace Batch` or `Redo Last Replace Batch` if needed."
            ],
            why: "Use it when you need a safer manuscript-wide replace workflow with review and rollback.",
            menuPath: "Find > replace commands",
            shortcut: "Option-Command-I, Option-Command-U, plus the dynamic undo and redo entries",
            related: ["find-project", "search-highlights"]
        ),
        entry(
            "sidebar",
            "Sidebar",
            category: "Workspace",
            summary: "The sidebar is the manuscript navigation tree on the left side of the app.",
            what: "It shows chapters and scenes, lets you select where to work, and acts as the main structural navigation surface.",
            how: [
                "Click chapters or scenes in the left sidebar to navigate.",
                "Use the context and structural commands to create, move, or reveal items there."
            ],
            why: "Use it whenever you want to move through manuscript structure quickly or confirm where you are in the draft.",
            related: ["previous-next-scene", "move-to-chapter", "inspector"]
        ),
        entry(
            "staging-tray",
            "Staging Tray",
            category: "Workspace",
            summary: "The staging tray holds scenes that are removed from the active draft but not deleted.",
            what: "It gives you a visible holding area for staged scenes and recovery actions.",
            how: [
                "Send a scene to staging with `Project > Send to Staging`.",
                "Use the staging tray controls to move selected scenes or all staged scenes back into active chapters."
            ],
            why: "Use it when you want to set aside scenes safely during revision without committing to deletion.",
            related: ["send-to-staging", "move-to-chapter", "project-settings"]
        ),
        entry(
            "staging-recovery",
            "Staging Recovery",
            category: "Workspace",
            summary: "Staging recovery moves parked scenes back into normal manuscript chapters.",
            what: "It gives you a controlled way to restore selected or all staged scenes into an active chapter.",
            how: [
                "Open `Project > Project Settings…` and go to `Staging Recovery`, or use the staging tray.",
                "Choose the destination chapter.",
                "Run `Move Selected Out of Staging` or `Move All Staging Scenes`."
            ],
            why: "Use it when you have revised scenes in staging that should return to the manuscript without manual recreation.",
            menuPath: "Project > Project Settings…",
            related: ["staging-tray", "send-to-staging", "move-to-chapter"]
        ),
        entry(
            "themes-and-presets",
            "Themes and Appearance Presets",
            category: "Workspace",
            summary: "Themes and appearance presets change the color layout and reading feel of the workspace.",
            what: "Themes change the palette. Appearance presets bundle theme, font, editor width, and line spacing into reusable looks.",
            how: [
                "Use the Workspace menu or Command Palette to switch themes quickly.",
                "Open `Project Settings` to create, apply, or delete appearance presets."
            ],
            why: "Use them when you want a drafting environment that better fits your eyes, mood, or task.",
            related: ["project-settings", "command-palette", "welcome-screen"],
            keywords: ["theme", "appearance", "font", "width", "spacing"]
        ),
        entry(
            "editor-writing",
            "Editor and Drafting Area",
            category: "Workspace",
            summary: "The editor is the main writing surface where you draft, revise, and move through manuscript text.",
            what: "It shows the current scene's content and supports markdown-aware editing, search highlights, entity highlights, and the current writing context.",
            how: [
                "Select a scene from the sidebar, linear mode, modular mode, or search results.",
                "Type directly in the editor to draft or revise text.",
                "Use the Find commands when you want search inside the current scene or across the project."
            ],
            why: "Use it whenever you are doing actual prose work rather than structural planning.",
            related: ["linear-mode", "split-editor", "find-current-scene", "entity-highlights"]
        ),
        entry(
            "appearance-presets",
            "Appearance Presets",
            category: "Workspace",
            summary: "Appearance presets save a full reading-and-writing look, not just a color theme.",
            what: "A preset bundles theme, font, font size, line height, and editor width so you can switch between complete writing environments.",
            how: [
                "Open `Project Settings`.",
                "Go to the appearance section.",
                "Adjust theme, font, editor width, and spacing.",
                "Save the current combination as a named appearance preset.",
                "Later, apply it again from Project Settings, the Workspace menu, or the Command Palette."
            ],
            why: "Use presets when you want different looks for drafting, editing, and reading without resetting each control by hand.",
            related: ["themes-and-presets", "command-palette", "project-settings"],
            keywords: ["preset", "font", "line height", "editor width"]
        ),
        entry(
            "scene-actions",
            "Scene Actions",
            category: "Workspace",
            summary: "Scene actions are the quick structural commands tied to the currently selected scene.",
            what: "They cover actions like duplicate, move up, move down, move to chapter, send to staging, open in split, and reveal in sidebar.",
            how: [
                "Select a scene first.",
                "Use the inspector action strip, the Command Palette, or the relevant Project and View menu items.",
                "If a scene action is disabled, select a normal manuscript scene instead of a missing or invalid target."
            ],
            why: "Use scene actions when you want to reorganize structure without dragging cards or manually opening multiple panels.",
            related: ["move-to-chapter", "send-to-staging", "split-editor", "sidebar"]
        ),
        entry(
            "duplicate-and-reorder-scenes",
            "Duplicate Scene, Move Scene Up, and Move Scene Down",
            category: "Workspace",
            summary: "These commands help you clone or reorder scenes without switching into drag-and-drop mode.",
            what: "Duplicate Scene creates a copy below the current scene, and Move Scene Up or Down shifts the scene's position within its chapter.",
            how: [
                "Select a scene.",
                "Open the Command Palette and search for `Duplicate Scene`, `Move Scene Up`, or `Move Scene Down`.",
                "You can also use scene actions from the inspector when a scene is selected."
            ],
            why: "Use them when you want precise reordering or to branch a scene without changing tools.",
            related: ["scene-actions", "modular-mode", "sidebar"],
            keywords: ["duplicate", "reorder", "move up", "move down"]
        ),
        entry(
            "reveal-in-sidebar",
            "Reveal in Sidebar",
            category: "Workspace",
            summary: "Reveal in Sidebar expands the manuscript tree and highlights the currently selected scene.",
            what: "It synchronizes the left navigation tree with the current scene so you can see exactly where that scene lives in the manuscript structure.",
            how: [
                "Select a scene.",
                "Open the Command Palette and run `Reveal in Sidebar`.",
                "Or use the scene actions in the inspector."
            ],
            why: "Use it when you reached a scene from search, notes, entities, or split view and want to confirm its chapter context.",
            related: ["sidebar", "scene-actions", "find-project"]
        ),
        entry(
            "metadata-schema",
            "Metadata Schema and Custom Fields",
            category: "Workspace",
            summary: "Metadata schema controls the custom fields available on scenes and chapters.",
            what: "It defines which custom metadata fields exist, how they behave, and how they appear in the Inspector.",
            how: [
                "Open `Project Settings`.",
                "Go to the metadata schema area.",
                "Create or edit fields such as text, single-select, multi-select, number, or date."
            ],
            why: "Use it when the default manuscript data is not enough and you need project-specific tracking fields.",
            related: ["project-settings", "inspector", "entities"]
        ),
        entry(
            "inspector-modes",
            "Inspector Modes",
            category: "Workspace",
            summary: "The inspector can change between contextual manuscript details, entity detail, and note detail.",
            what: "Instead of being only a scene metadata panel, the inspector can also focus on note detail or entity detail when those items are active.",
            how: [
                "Show the inspector.",
                "Select a scene, chapter, note, or entity from the relevant UI surface.",
                "Use the inspector to edit the currently focused kind of detail."
            ],
            why: "Use it when you want to stay in the main workspace instead of bouncing in and out of modal sheets.",
            related: ["inspector", "entities", "notes"]
        ),
        entry(
            "goals-dashboard-details",
            "Goals Dashboard Details",
            category: "Workspace",
            summary: "The goals dashboard combines live session tracking with longer writing history.",
            what: "It includes session counts, project goals, pacing, and recent writing history like heatmap and trend views.",
            how: [
                "Open `View > Writing Goals & Statistics…`.",
                "Review session metrics at the top.",
                "Adjust project goals or read the history sections below."
            ],
            why: "Use it when you want both immediate writing feedback and longer-term progress trends in one place.",
            related: ["goals-dashboard", "project-settings", "welcome-screen"]
        ),
        entry(
            "recovery-mode",
            "Recovery Mode",
            category: "Safety",
            summary: "Recovery Mode opens damaged projects in a read-only salvage state.",
            what: "If the app detects a damaged project, it can reconstruct what it can and let you inspect or export it without writing over the broken data.",
            how: [
                "If the app reports a damaged project on startup or open, use the recovery option shown in the error view.",
                "From there, inspect the recovered content and use the recovery export or duplication actions."
            ],
            why: "Use it when a project is damaged and you need the safest path to salvage your writing.",
            related: ["create-backup", "save-and-backup", "import-export"]
        ),
        entry(
            "recovery-actions",
            "Recovery Export and Duplicate Recovery Project",
            category: "Safety",
            summary: "Recovery actions help you get recovered writing back into a safe writable form.",
            what: "When a project opens in recovery mode, you can export recovery content out to markdown or duplicate the recovered manuscript into a fresh writable project.",
            how: [
                "Open a damaged project in recovery mode.",
                "Use the recovery banner or Command Palette actions for recovery export or recovery duplication.",
                "Inspect the resulting export or duplicated project before continuing work."
            ],
            why: "Use these actions when the recovered content looks good and you want to move back into normal work safely.",
            related: ["recovery-mode", "create-backup", "save-project-as"],
            keywords: ["salvage", "duplicate recovery", "export recovery"]
        ),
        entry(
            "recovery-banner",
            "Recovery Banner",
            category: "Safety",
            summary: "The recovery banner is the orange warning strip shown while a recovered project is open.",
            what: "It reminds you that you are working in recovery mode and exposes the safest next actions, such as export and duplication.",
            how: [
                "Open a damaged project in recovery mode.",
                "Read the summary text in the recovery banner.",
                "Use the banner buttons for export, duplication, or help."
            ],
            why: "Use the banner as your guide when you need to leave recovery mode without risking the damaged project.",
            related: ["recovery-mode", "recovery-actions", "create-backup"]
        ),
        entry(
            "entity-highlights",
            "Entity Highlights in the Editor",
            category: "Workspace",
            summary: "Entity highlights show recognized entity mentions directly inside the editor.",
            what: "They visually mark tracked entity mentions so you can see references as you draft.",
            how: [
                "Track entities in the Entities sheet.",
                "Open scenes in the editor and review the mention highlights and entity assistant strip."
            ],
            why: "Use it when you want help keeping names and references consistent while writing.",
            related: ["entities", "inspector", "notes"]
        ),
        entry(
            "entity-relationships",
            "Entity Relationships and Linked Scenes",
            category: "Project",
            summary: "Entities can store relationships, aliases, and linked scenes instead of acting like a plain list.",
            what: "The entity system is designed to help you understand how story elements connect and where they appear in the manuscript.",
            how: [
                "Open `Project > Entities…`.",
                "Select an entity to review aliases, relationships, linked scenes, and notes.",
                "Use the linked scene actions to jump back to manuscript locations."
            ],
            why: "Use it when the same people, places, or concepts recur across many scenes and you need stronger continuity support.",
            menuPath: "Project > Entities…",
            related: ["entities", "entity-highlights", "notes", "timeline"]
        ),
        entry(
            "notes-filters",
            "Notes Folders and Filters",
            category: "Project",
            summary: "Notes can be organized by folder and filtered by linked scene or entity.",
            what: "The Notes system is more useful than a flat list because it supports context-based filtering and linked navigation.",
            how: [
                "Open `Project > Notes…`.",
                "Use the filter controls to narrow notes by folder, linked scene, or linked entity.",
                "Select a note to edit it or jump back to its manuscript context."
            ],
            why: "Use filtered notes when you want to focus on planning or revision notes tied to one part of the manuscript.",
            menuPath: "Project > Notes…",
            related: ["notes", "entities", "sidebar"]
        ),
        entry(
            "note-linking",
            "Linking Notes to Scenes and Entities",
            category: "Project",
            summary: "Notes become much more useful when they are linked to specific manuscript context.",
            what: "A linked note can point at one or more scenes and entities, which makes filtering, navigation, and review easier later.",
            how: [
                "Open `Project > Notes…`.",
                "Create a note or edit an existing note.",
                "Use the `Linked Scenes` and `Linked Entities` checkboxes before saving."
            ],
            why: "Use linked notes when a thought belongs to concrete story material instead of the project in general.",
            menuPath: "Project > Notes…",
            related: ["notes", "notes-filters", "entities"]
        ),
        entry(
            "source-attachments",
            "Source Attachments and Research Files",
            category: "Project",
            summary: "Sources can include imported research attachments stored inside the project.",
            what: "A source is not just citation text. It can also hold research files and links back to scenes, notes, and entities.",
            how: [
                "Open `Project > Sources…`.",
                "Select or create a source.",
                "Import a research file and review it from the source detail area.",
                "Use source links to move between sources and manuscript context."
            ],
            why: "Use attachments when your research material should travel with the manuscript rather than stay in a separate folder system.",
            menuPath: "Project > Sources…",
            related: ["sources", "citation-insertion", "notes", "entities"],
            keywords: ["research", "attachment", "file"]
        ),
        entry(
            "research-browser",
            "Research Browser",
            category: "Project",
            summary: "The research browser is the detailed source view for files, links, and citation context.",
            what: "It shows the selected source's attachments, linked scenes, citation mentions, linked entities, and linked notes in one place.",
            how: [
                "Open `Project > Sources…`.",
                "Select a source in the library list.",
                "Use the `Research Browser` section to inspect files and jump into linked manuscript context."
            ],
            why: "Use it when editing bibliography fields is not enough and you need to see how one source actually supports the draft.",
            menuPath: "Project > Sources…",
            related: ["sources", "source-attachments", "source-links"]
        ),
        entry(
            "source-links",
            "Source Links to Scenes, Entities, and Notes",
            category: "Project",
            summary: "Sources can connect directly to the manuscript material they support.",
            what: "Linking a source to scenes, entities, and notes helps you trace where research is used and what it informs.",
            how: [
                "Open `Project > Sources…`.",
                "Create or edit a source.",
                "Use the `Links` section to select scenes, entities, and notes before saving."
            ],
            why: "Use links when you want research context to stay connected to story material instead of floating as isolated references.",
            menuPath: "Project > Sources…",
            related: ["sources", "research-browser", "notes", "entities"]
        ),
        entry(
            "citation-insertion",
            "Citation Insertion",
            category: "Project",
            summary: "The source library can insert citation keys directly into the active editor.",
            what: "This helps you place citation markers like reference keys in the draft without typing them manually.",
            how: [
                "Open `Project > Sources…`.",
                "Choose a source with a citation key.",
                "Use the insert citation action to place it into the current editor."
            ],
            why: "Use it when you want faster, more consistent citation markup while drafting or researching.",
            menuPath: "Project > Sources…",
            related: ["sources", "source-attachments", "editor-writing"]
        ),
        entry(
            "timeline-events",
            "Timeline Events and Tracks",
            category: "Project",
            summary: "Timeline events can be arranged on tracks and linked to scenes.",
            what: "Tracks help separate different story lines, and scene links let you move from an abstract event to the actual manuscript text.",
            how: [
                "Open `Project > Timeline…`.",
                "Create events with titles, descriptions, and track placement.",
                "Link them to scenes for fast navigation back into the draft."
            ],
            why: "Use tracks when one chronological list is not enough and you need separate strands such as character arcs or parallel plots.",
            menuPath: "Project > Timeline…",
            related: ["timeline", "entities", "notes"]
        ),
        entry(
            "timeline-tracks",
            "Timeline Tracks and Positions",
            category: "Project",
            summary: "Tracks group kinds of events, and positions control their order.",
            what: "You can separate events into tracks like main plot, backstory, or subplot, then place them by real date or relative order.",
            how: [
                "Open `Project > Timeline…`.",
                "Set a track name when creating an event.",
                "Choose `Use Absolute Date` for calendar time, or leave it off to manage events with `Relative Order`."
            ],
            why: "Use this when your story has multiple strands or when chronology matters even if exact dates do not.",
            menuPath: "Project > Timeline…",
            related: ["timeline-events", "timeline", "scene-actions"]
        ),
        entry(
            "compile-presets",
            "Compile Presets",
            category: "Project",
            summary: "Compile presets save a reusable export configuration for the current project.",
            what: "A compile preset stores export format choices, included chapters, theme or stylesheet decisions, front matter, and output settings.",
            how: [
                "Open `Project > Import / Export…`.",
                "Configure the export settings the way you want them.",
                "Save the settings as a compile preset so you can reuse them later."
            ],
            why: "Use compile presets when you produce multiple output versions such as draft review copies, clean manuscript exports, or EPUB builds.",
            menuPath: "Project > Import / Export…",
            related: ["import-export", "export-review", "epub-export"],
            keywords: ["compile", "preset", "export settings"]
        ),
        entry(
            "export-review",
            "Export Review and Export Warnings",
            category: "Project",
            summary: "The export sheet reviews your current compile choices before it writes files.",
            what: "It summarizes what will be exported and warns you about problems such as empty chapter selections, missing EPUB metadata, or extreme margin settings.",
            how: [
                "Open `Project > Import / Export…`.",
                "Review the export summary and warning messages in the sheet.",
                "Adjust settings until the output looks correct, then export."
            ],
            why: "Use the review section when you want to catch configuration mistakes before creating files you need to clean up later.",
            menuPath: "Project > Import / Export…",
            related: ["import-export", "compile-presets", "epub-export"]
        ),
        entry(
            "epub-export",
            "EPUB, HTML, PDF, DOCX, and Markdown Export",
            category: "Project",
            summary: "The compile pipeline supports several different output formats for different publishing needs.",
            what: "Markdown is good for plain text workflows, HTML is useful for styled web-like output, PDF and DOCX are common shareable formats, and EPUB is for ebook packaging.",
            how: [
                "Open `Project > Import / Export…`.",
                "Choose the target export format.",
                "Adjust chapter inclusion, metadata, and preset settings.",
                "Export the manuscript."
            ],
            why: "Use different formats depending on whether you need revision review, formatting work, ebook packaging, or plain text portability.",
            menuPath: "Project > Import / Export…",
            related: ["import-export", "compile-presets", "export-review"],
            keywords: ["epub", "html", "pdf", "docx", "markdown"]
        ),
        entry(
            "project-search-scopes",
            "Project Search Scopes",
            category: "Find",
            summary: "Project search can be limited to specific chapters, formatting types, or other scopes.",
            what: "The project search sheet is not only plain text search. It can target selected chapters and several formatting-aware scopes too.",
            how: [
                "Open `Find > Find in Project`.",
                "Use the scope controls in the sheet to pick the search target.",
                "If you choose `Selected Chapters`, mark the chapters you want before running the search."
            ],
            why: "Use scope controls when a whole-project search would be too broad or when you are looking for a specific kind of markup.",
            menuPath: "Find > Find in Project",
            related: ["find-project", "regex-replace", "replace-batches"],
            keywords: ["scope", "selected chapters", "formatting"]
        ),
        entry(
            "regex-replace",
            "Regex Search and Replacement",
            category: "Find",
            summary: "Regex mode lets you search and replace using pattern matching instead of plain text.",
            what: "It supports regex search expressions and replacement groups such as `$1` when you need more advanced find-and-replace behavior.",
            how: [
                "Open `Find > Find in Project`.",
                "Turn on regex search in the search sheet.",
                "Enter the pattern and, if needed, use replacement groups in the Replace field.",
                "Review preview results before running a batch replace."
            ],
            why: "Use regex when plain text search is too limited for the pattern you need to find or reshape.",
            menuPath: "Find > Find in Project",
            related: ["find-project", "project-search-scopes", "replace-batches"],
            keywords: ["regex", "capture group", "pattern"]
        ),
        entry(
            "search-results-and-preview",
            "Grouped Search Results and Replace Preview",
            category: "Find",
            summary: "Project search results are grouped so you can understand matches by chapter and scene before taking action.",
            what: "The search sheet groups results by manuscript structure and also shows replace-preview snippets so you can include or exclude scenes intelligently.",
            how: [
                "Open `Find > Find in Project`.",
                "Run a search and read the grouped results list.",
                "If using replace, review the preview section and use scene inclusion controls before replacing."
            ],
            why: "Use the grouped view when you want to understand match context before editing the manuscript in bulk.",
            menuPath: "Find > Find in Project",
            related: ["find-project", "replace-batches", "sidebar"]
        ),
        entry(
            "modular-drag-drop",
            "Modular Drag and Drop",
            category: "Workspace",
            summary: "Modular mode supports drag-and-drop reorganization across chapters and staging.",
            what: "You can drag scenes between modular groups to restructure chapters or send items into staging depending on the active grouping and destination.",
            how: [
                "Switch to Modular Mode.",
                "Drag a scene card onto another chapter group or staging target.",
                "Release it to complete the move."
            ],
            why: "Use drag-and-drop when you want the fastest visual restructuring workflow instead of menu-based moves.",
            related: ["modular-mode", "modular-corkboard", "staging-tray", "move-to-chapter"]
        ),
        entry(
            "modular-multiselect",
            "Modular Multi-Selection and Batch Actions",
            category: "Workspace",
            summary: "Modular mode supports selecting more than one scene for bulk actions.",
            what: "You can gather a set of scenes and apply batch actions like moving or staging them together.",
            how: [
                "Switch to Modular Mode.",
                "Use the available selection interactions to mark multiple scene cards.",
                "Run the batch action controls for moving or staging the selected set."
            ],
            why: "Use it when you need to restructure several scenes at once instead of repeating the same action scene by scene.",
            related: ["modular-mode", "modular-drag-drop", "staging-tray"],
            keywords: ["multi select", "batch", "bulk"]
        ),
        entry(
            "modular-batch-actions",
            "Modular Batch Actions Bar",
            category: "Workspace",
            summary: "The modular batch actions bar appears when more than one modular scene is selected.",
            what: "It gives you direct bulk controls for moving the selected scenes into another chapter or sending them to staging.",
            how: [
                "Switch to Modular Mode.",
                "Select multiple scenes.",
                "Use the batch actions bar to choose a chapter target or send the selected scenes to staging."
            ],
            why: "Use it when you want to restructure several scenes at once without opening separate actions one by one.",
            related: ["modular-multiselect", "modular-mode", "move-to-chapter", "send-to-staging"]
        ),
        entry(
            "project-settings-backups",
            "Autosave, Backup, and Safety Settings",
            category: "Project",
            summary: "Project Settings includes safety controls that define how often work is saved and backed up.",
            what: "These settings affect autosave timing, backup interval, and backup retention count for the current project.",
            how: [
                "Open `Project > Project Settings…`.",
                "Find the autosave and backup section.",
                "Adjust the timing and retention values to match how cautious you want the project to be."
            ],
            why: "Use these settings when you want tighter safety for active drafting or lighter backup behavior for smaller projects.",
            menuPath: "Project > Project Settings…",
            related: ["create-backup", "save-and-backup", "recovery-mode"]
        ),
        entry(
            "project-settings-metadata",
            "Project Settings Metadata and Schema Management",
            category: "Project",
            summary: "Project Settings is where you define custom fields for the project, not just where you change appearance.",
            what: "The metadata schema tools let you create, rename, reorder, and configure project-wide metadata fields used in the inspector.",
            how: [
                "Open `Project > Project Settings…`.",
                "Go to the metadata schema section.",
                "Edit field names, field types, and option lists as needed."
            ],
            why: "Use it when your story tracking needs more structure than the default built-in metadata provides.",
            menuPath: "Project > Project Settings…",
            related: ["metadata-schema", "inspector", "entities"]
        ),
        entry(
            "help-reference",
            "Help Reference",
            category: "Help",
            summary: "The Help Reference is the in-app manual for the current program.",
            what: "It explains what commands and surfaces do, how to reach them, and when they are useful.",
            how: [
                "Open `Help > Scribbles-N-Scripts Help`.",
                "Use the search field to find a command, surface, or term.",
                "Open related topics in the detail view to move between connected entries."
            ],
            why: "Use it when you need to learn a command, remember a shortcut, or understand what a feature is for.",
            menuPath: "Help > Scribbles-N-Scripts Help",
            shortcut: "Shift-Command-?",
            related: ["command-palette", "welcome-screen"]
        )
    ]

    static func entry(for id: String) -> HelpReferenceEntry? {
        entries.first(where: { $0.id == id })
    }

    private static func entry(
        _ id: String,
        _ title: String,
        category: String,
        summary: String,
        what: String,
        how: [String],
        why: String,
        menuPath: String? = nil,
        shortcut: String? = nil,
        related: [String] = [],
        keywords: [String] = []
    ) -> HelpReferenceEntry {
        HelpReferenceEntry(
            id: id,
            title: title,
            category: category,
            summary: summary,
            whatItDoes: what,
            howToUse: how,
            whyUseIt: why,
            menuPath: menuPath,
            shortcut: shortcut,
            relatedIDs: related,
            keywords: keywords
        )
    }
}

struct HelpReferenceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appThemePalette) private var palette
    let startingEntryID: String?
    @State private var query = ""
    @State private var selectedEntryID: String?

    private var filteredEntries: [HelpReferenceEntry] {
        HelpReferenceLibrary.entries.filter { $0.matches(query: query) }
    }

    private var groupedEntries: [(String, [HelpReferenceEntry])] {
        Dictionary(grouping: filteredEntries, by: \.category)
            .map { ($0.key, $0.value.sorted { $0.title < $1.title }) }
            .sorted { $0.0 < $1.0 }
    }

    private var selectedEntry: HelpReferenceEntry? {
        if let selectedEntryID {
            return filteredEntries.first(where: { $0.id == selectedEntryID }) ?? HelpReferenceLibrary.entry(for: selectedEntryID)
        }
        return filteredEntries.first
    }

    var body: some View {
        NavigationSplitView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Help")
                    .font(.title2.weight(.semibold))
                TextField("Search commands, panels, and terms", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Help search")
                    .accessibilityHint("Search help topics by command name, panel, or keyword")
                if filteredEntries.isEmpty {
                    ContentUnavailableView(
                        "No Matching Help Topics",
                        systemImage: "questionmark.bubble",
                        description: Text("Try a broader search term like project, find, modular, or notes.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(selection: $selectedEntryID) {
                        ForEach(groupedEntries, id: \.0) { category, entries in
                            Section(category) {
                                ForEach(entries) { entry in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.title)
                                        Text(entry.summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    .tag(entry.id)
                                }
                            }
                        }
                    }
                    .listStyle(.sidebar)
                }
            }
            .padding(18)
            .frame(minWidth: 320)
        } detail: {
            if let selectedEntry {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedEntry.category.uppercased())
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text(selectedEntry.title)
                                .font(.system(size: 28, weight: .bold, design: .default))
                            Text(selectedEntry.summary)
                                .font(.body)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 10) {
                            if let menuPath = selectedEntry.menuPath {
                                helpChip(title: "Menu", value: menuPath)
                            }
                            if let shortcut = selectedEntry.shortcut {
                                helpChip(title: "Shortcut", value: shortcut)
                            }
                        }

                        detailSection(title: "What It Does", body: selectedEntry.whatItDoes)
                        detailStepsSection(title: "How To Use It", steps: selectedEntry.howToUse)
                        detailSection(title: "Why Use It", body: selectedEntry.whyUseIt)

                        if !selectedEntry.relatedIDs.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Related Topics")
                                    .font(.headline)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), alignment: .leading)], alignment: .leading, spacing: 8) {
                                    ForEach(selectedEntry.relatedIDs, id: \.self) { relatedID in
                                        if let relatedEntry = HelpReferenceLibrary.entry(for: relatedID) {
                                            Button(relatedEntry.title) {
                                                selectedEntryID = relatedEntry.id
                                            }
                                            .buttonStyle(.bordered)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                    .frame(maxWidth: 860, alignment: .leading)
                }
                .background(palette.canvas)
            } else {
                ContentUnavailableView(
                    "Choose a Help Topic",
                    systemImage: "book.closed",
                    description: Text("Select a topic from the list to learn what it does, how to use it, and when to use it.")
                )
            }
        }
        .frame(minWidth: 1080, minHeight: 720)
        .onAppear {
            if let startingEntryID,
               HelpReferenceLibrary.entry(for: startingEntryID) != nil {
                selectedEntryID = startingEntryID
            } else {
                synchronizeSelection()
            }
        }
        .onChange(of: filteredEntries.map(\.id)) { _, _ in
            synchronizeSelection()
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
    }

    private func synchronizeSelection() {
        guard !filteredEntries.isEmpty else {
            selectedEntryID = nil
            return
        }
        if let selectedEntryID, filteredEntries.contains(where: { $0.id == selectedEntryID }) {
            return
        }
        selectedEntryID = filteredEntries.first?.id
    }

    private func detailSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            Text(body)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func detailStepsSection(title: String, steps: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(alignment: .top, spacing: 10) {
                    Text("\(index + 1).")
                        .fontWeight(.semibold)
                        .frame(width: 24, alignment: .trailing)
                    Text(step)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func helpChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospaced())
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(palette.card, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        )
    }
}
