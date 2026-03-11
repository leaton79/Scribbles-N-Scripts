# Scribbles-N-Scripts

Scribbles-N-Scripts is a macOS writing application built with Swift and SwiftUI.

## Status

Feature-complete across the major manuscript-writing surfaces in the project Bible. The in-app Help system is now considered complete for the current product surface, and the main next focus is release hardening rather than more Help expansion.

## Milestones

- [v1.0.1 Release Notes](docs/releases/v1.0.1.md)
- [v1.0.0 Release Notes](docs/releases/v1.0.0.md)
- [Post-v1 Roadmap](docs/POST-V1-ROADMAP.md)
- [Screenshot Shot List](docs/screenshots/SHOTLIST.md)

## Current Surfaces

- Project I/O, backups, and recovery mode
- Editor, split editor, linear mode, modular mode, corkboard, and outliner
- Sidebar navigation, command palette, inspector, staging tray, and project settings
- Snapshots, tags, metadata schemas, goals/statistics, and advanced Find/Replace
- Timeline, entities, notes, sources/research library, and scratchpad
- Import/export with Markdown, HTML, DOCX, PDF, and EPUB output
- Branded welcome screen, bundled app icon, workspace themes, and appearance presets
- Searchable in-app Help reference with contextual entry points and guided first-use path

## Run

From the project root:

```bash
swift run Scribbles-N-Scripts
```

If you already built the app, the debug binary is usually:

```bash
.build/debug/Scribbles-N-Scripts
```

## Requirements

- macOS 14+
- Xcode 15+ (or Swift 5.9+ toolchain)

## Build

```bash
swift build
```

## Test

```bash
swift test
```

## Visual QA

For screenshot-driven UI review or automation-driven window resizing on macOS, the terminal/app running the commands may need:

- Accessibility access
- Screen Recording access

To bring the app forward and size it consistently before capture:

```bash
Tools/focus_app_window.sh
```

Without those permissions, the app still runs normally, but automated visual inspection can be limited.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
