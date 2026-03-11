# Scribbles-N-Scripts

Scribbles-N-Scripts is a macOS writing application built with Swift and SwiftUI.

## Status

Feature-complete across the major manuscript-writing surfaces in the project Bible, with current work focused on release polish, workflow depth, and export/research refinement.

## Current Surfaces

- Project I/O, backups, and recovery mode
- Editor, split editor, linear mode, modular mode, corkboard, and outliner
- Sidebar navigation, command palette, inspector, staging tray, and project settings
- Snapshots, tags, metadata schemas, goals/statistics, and advanced Find/Replace
- Timeline, entities, notes, sources/research library, and scratchpad
- Import/export with Markdown, HTML, DOCX, PDF, and EPUB output

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

Without those permissions, the app still runs normally, but automated visual inspection can be limited.

## License

GNU General Public License v3.0. See [LICENSE](LICENSE).
