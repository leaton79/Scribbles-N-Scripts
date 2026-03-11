import AppKit
import SwiftUI

struct AppThemePalette {
    let colorScheme: ColorScheme?
    let tint: Color
    let canvas: Color
    let chrome: Color
    let sidebar: Color
    let panel: Color
    let card: Color
    let border: Color
    let mutedBadge: Color
    let notice: Color
    let shadow: Color
    let softShadow: Color
    let editorBackground: NSColor
    let editorText: NSColor
    let entityHighlight: NSColor
    let searchHighlight: NSColor
    let activeSearchHighlight: NSColor

    func interactiveFill(isSelected: Bool = false, isHovered: Bool = false, isPressed: Bool = false) -> Color {
        if isPressed {
            return tint.opacity(colorScheme == .dark ? 0.24 : 0.14)
        }
        if isSelected {
            return tint.opacity(colorScheme == .dark ? 0.20 : 0.11)
        }
        if isHovered {
            return mutedBadge.opacity(colorScheme == .dark ? 1.15 : 1.35)
        }
        return card
    }

    func interactiveBorder(isSelected: Bool = false, isHovered: Bool = false, isPressed: Bool = false) -> Color {
        if isPressed || isSelected {
            return tint.opacity(colorScheme == .dark ? 0.75 : 0.55)
        }
        if isHovered {
            return tint.opacity(colorScheme == .dark ? 0.38 : 0.24)
        }
        return border
    }

    var focusRing: Color {
        tint.opacity(colorScheme == .dark ? 0.42 : 0.22)
    }

    func tagFill(isEmphasized: Bool = false) -> Color {
        isEmphasized ? tint.opacity(0.18) : mutedBadge
    }

    var tagText: Color {
        tint
    }

    func metadataFill() -> Color {
        tint.opacity(0.10)
    }

    var metadataText: Color {
        tint
    }

    func warningFill() -> Color {
        Color.orange.opacity(colorScheme == .dark ? 0.22 : 0.14)
    }

    var warningText: Color {
        colorScheme == .dark ? Color(red: 1.0, green: 0.78, blue: 0.42) : .orange
    }

    func colorLabelFill(_ label: ColorLabel) -> Color {
        switch label {
        case .red:
            return Color(red: 0.80, green: 0.29, blue: 0.31)
        case .orange:
            return Color(red: 0.89, green: 0.53, blue: 0.24)
        case .yellow:
            return Color(red: 0.86, green: 0.72, blue: 0.24)
        case .green:
            return Color(red: 0.27, green: 0.60, blue: 0.39)
        case .blue:
            return Color(red: 0.27, green: 0.49, blue: 0.80)
        case .purple:
            return Color(red: 0.53, green: 0.40, blue: 0.76)
        case .gray:
            return Color.gray.opacity(0.75)
        case .none:
            return border
        }
    }

    func statusFill(_ status: ContentStatus) -> Color {
        switch status {
        case .todo:
            return Color.gray.opacity(colorScheme == .dark ? 0.24 : 0.12)
        case .inProgress:
            return tint.opacity(colorScheme == .dark ? 0.28 : 0.16)
        case .firstDraft:
            return Color(red: 0.87, green: 0.62, blue: 0.24).opacity(colorScheme == .dark ? 0.30 : 0.18)
        case .revised:
            return Color(red: 0.23, green: 0.60, blue: 0.44).opacity(colorScheme == .dark ? 0.28 : 0.16)
        case .final_:
            return Color(red: 0.47, green: 0.33, blue: 0.78).opacity(colorScheme == .dark ? 0.28 : 0.16)
        }
    }

    func statusText(_ status: ContentStatus) -> Color {
        switch status {
        case .todo:
            return .secondary
        case .inProgress:
            return tint
        case .firstDraft:
            return Color(red: 0.75, green: 0.42, blue: 0.07)
        case .revised:
            return Color(red: 0.16, green: 0.49, blue: 0.34)
        case .final_:
            return Color(red: 0.42, green: 0.27, blue: 0.70)
        }
    }

    static func forTheme(_ theme: AppTheme) -> AppThemePalette {
        switch theme {
        case .light:
            return AppThemePalette(
                colorScheme: .light,
                tint: Color(red: 0.16, green: 0.38, blue: 0.80),
                canvas: Color(red: 0.95, green: 0.96, blue: 0.98),
                chrome: Color.white.opacity(0.88),
                sidebar: Color.white.opacity(0.92),
                panel: Color.white.opacity(0.90),
                card: Color.white.opacity(0.90),
                border: Color.black.opacity(0.08),
                mutedBadge: Color.black.opacity(0.04),
                notice: Color(red: 0.90, green: 0.95, blue: 1.00),
                shadow: Color.black.opacity(0.10),
                softShadow: Color.black.opacity(0.04),
                editorBackground: NSColor(calibratedWhite: 1.0, alpha: 1.0),
                editorText: NSColor.textColor,
                entityHighlight: NSColor.systemTeal.withAlphaComponent(0.18),
                searchHighlight: NSColor.systemYellow.withAlphaComponent(0.32),
                activeSearchHighlight: NSColor.systemOrange.withAlphaComponent(0.45)
            )
        case .dark:
            return AppThemePalette(
                colorScheme: .dark,
                tint: Color(red: 0.48, green: 0.68, blue: 1.00),
                canvas: Color(red: 0.10, green: 0.11, blue: 0.14),
                chrome: Color(red: 0.15, green: 0.16, blue: 0.20),
                sidebar: Color(red: 0.13, green: 0.14, blue: 0.18),
                panel: Color(red: 0.14, green: 0.15, blue: 0.19),
                card: Color.white.opacity(0.06),
                border: Color.white.opacity(0.08),
                mutedBadge: Color.white.opacity(0.08),
                notice: Color(red: 0.18, green: 0.24, blue: 0.34),
                shadow: Color.black.opacity(0.34),
                softShadow: Color.black.opacity(0.18),
                editorBackground: NSColor(calibratedRed: 0.11, green: 0.12, blue: 0.15, alpha: 1.0),
                editorText: NSColor(calibratedRed: 0.92, green: 0.93, blue: 0.96, alpha: 1.0),
                entityHighlight: NSColor.systemTeal.withAlphaComponent(0.24),
                searchHighlight: NSColor.systemYellow.withAlphaComponent(0.24),
                activeSearchHighlight: NSColor.systemOrange.withAlphaComponent(0.34)
            )
        case .parchment:
            return AppThemePalette(
                colorScheme: .light,
                tint: Color(red: 0.46, green: 0.24, blue: 0.12),
                canvas: Color(red: 0.94, green: 0.90, blue: 0.82),
                chrome: Color(red: 0.98, green: 0.95, blue: 0.89),
                sidebar: Color(red: 0.97, green: 0.94, blue: 0.87),
                panel: Color(red: 0.98, green: 0.95, blue: 0.89),
                card: Color(red: 1.00, green: 0.98, blue: 0.93),
                border: Color(red: 0.45, green: 0.33, blue: 0.20).opacity(0.14),
                mutedBadge: Color(red: 0.45, green: 0.33, blue: 0.20).opacity(0.08),
                notice: Color(red: 0.97, green: 0.91, blue: 0.79),
                shadow: Color(red: 0.31, green: 0.22, blue: 0.13).opacity(0.12),
                softShadow: Color(red: 0.31, green: 0.22, blue: 0.13).opacity(0.05),
                editorBackground: NSColor(calibratedRed: 0.99, green: 0.97, blue: 0.92, alpha: 1.0),
                editorText: NSColor(calibratedRed: 0.22, green: 0.16, blue: 0.10, alpha: 1.0),
                entityHighlight: NSColor(calibratedRed: 0.30, green: 0.56, blue: 0.54, alpha: 0.22),
                searchHighlight: NSColor(calibratedRed: 0.96, green: 0.83, blue: 0.35, alpha: 0.36),
                activeSearchHighlight: NSColor(calibratedRed: 0.88, green: 0.54, blue: 0.24, alpha: 0.42)
            )
        case .midnight:
            return AppThemePalette(
                colorScheme: .dark,
                tint: Color(red: 0.40, green: 0.74, blue: 0.94),
                canvas: Color(red: 0.05, green: 0.08, blue: 0.14),
                chrome: Color(red: 0.08, green: 0.12, blue: 0.20),
                sidebar: Color(red: 0.07, green: 0.10, blue: 0.17),
                panel: Color(red: 0.09, green: 0.13, blue: 0.21),
                card: Color.white.opacity(0.06),
                border: Color(red: 0.39, green: 0.71, blue: 0.89).opacity(0.16),
                mutedBadge: Color.white.opacity(0.08),
                notice: Color(red: 0.11, green: 0.19, blue: 0.29),
                shadow: Color.black.opacity(0.36),
                softShadow: Color.black.opacity(0.18),
                editorBackground: NSColor(calibratedRed: 0.07, green: 0.11, blue: 0.18, alpha: 1.0),
                editorText: NSColor(calibratedRed: 0.88, green: 0.94, blue: 0.99, alpha: 1.0),
                entityHighlight: NSColor(calibratedRed: 0.24, green: 0.72, blue: 0.74, alpha: 0.25),
                searchHighlight: NSColor(calibratedRed: 0.83, green: 0.73, blue: 0.26, alpha: 0.28),
                activeSearchHighlight: NSColor(calibratedRed: 0.95, green: 0.56, blue: 0.21, alpha: 0.34)
            )
        case .forest:
            return AppThemePalette(
                colorScheme: .light,
                tint: Color(red: 0.18, green: 0.42, blue: 0.29),
                canvas: Color(red: 0.90, green: 0.95, blue: 0.90),
                chrome: Color(red: 0.95, green: 0.98, blue: 0.94),
                sidebar: Color(red: 0.93, green: 0.97, blue: 0.92),
                panel: Color(red: 0.95, green: 0.98, blue: 0.94),
                card: Color.white.opacity(0.82),
                border: Color(red: 0.18, green: 0.42, blue: 0.29).opacity(0.14),
                mutedBadge: Color(red: 0.18, green: 0.42, blue: 0.29).opacity(0.08),
                notice: Color(red: 0.86, green: 0.94, blue: 0.86),
                shadow: Color(red: 0.14, green: 0.22, blue: 0.16).opacity(0.12),
                softShadow: Color(red: 0.14, green: 0.22, blue: 0.16).opacity(0.05),
                editorBackground: NSColor(calibratedRed: 0.97, green: 0.99, blue: 0.96, alpha: 1.0),
                editorText: NSColor(calibratedRed: 0.14, green: 0.22, blue: 0.16, alpha: 1.0),
                entityHighlight: NSColor(calibratedRed: 0.18, green: 0.55, blue: 0.48, alpha: 0.20),
                searchHighlight: NSColor(calibratedRed: 0.93, green: 0.84, blue: 0.40, alpha: 0.32),
                activeSearchHighlight: NSColor(calibratedRed: 0.82, green: 0.45, blue: 0.20, alpha: 0.36)
            )
        case .rose:
            return AppThemePalette(
                colorScheme: .light,
                tint: Color(red: 0.66, green: 0.26, blue: 0.36),
                canvas: Color(red: 0.98, green: 0.92, blue: 0.93),
                chrome: Color(red: 1.00, green: 0.96, blue: 0.96),
                sidebar: Color(red: 0.99, green: 0.95, blue: 0.95),
                panel: Color(red: 1.00, green: 0.96, blue: 0.96),
                card: Color.white.opacity(0.86),
                border: Color(red: 0.66, green: 0.26, blue: 0.36).opacity(0.14),
                mutedBadge: Color(red: 0.66, green: 0.26, blue: 0.36).opacity(0.08),
                notice: Color(red: 0.99, green: 0.89, blue: 0.90),
                shadow: Color(red: 0.32, green: 0.16, blue: 0.20).opacity(0.12),
                softShadow: Color(red: 0.32, green: 0.16, blue: 0.20).opacity(0.05),
                editorBackground: NSColor(calibratedRed: 1.00, green: 0.98, blue: 0.98, alpha: 1.0),
                editorText: NSColor(calibratedRed: 0.28, green: 0.15, blue: 0.18, alpha: 1.0),
                entityHighlight: NSColor(calibratedRed: 0.29, green: 0.60, blue: 0.62, alpha: 0.18),
                searchHighlight: NSColor(calibratedRed: 0.95, green: 0.84, blue: 0.42, alpha: 0.32),
                activeSearchHighlight: NSColor(calibratedRed: 0.88, green: 0.48, blue: 0.26, alpha: 0.38)
            )
        case .system:
            return AppThemePalette(
                colorScheme: nil,
                tint: .accentColor,
                canvas: Color(nsColor: .windowBackgroundColor),
                chrome: Color(nsColor: .underPageBackgroundColor),
                sidebar: Color(nsColor: .controlBackgroundColor),
                panel: Color(nsColor: .controlBackgroundColor),
                card: Color(nsColor: .windowBackgroundColor),
                border: Color.primary.opacity(0.08),
                mutedBadge: Color.primary.opacity(0.05),
                notice: Color.accentColor.opacity(0.10),
                shadow: Color.black.opacity(0.12),
                softShadow: Color.black.opacity(0.05),
                editorBackground: .textBackgroundColor,
                editorText: .textColor,
                entityHighlight: NSColor.systemTeal.withAlphaComponent(0.18),
                searchHighlight: NSColor.systemYellow.withAlphaComponent(0.32),
                activeSearchHighlight: NSColor.systemOrange.withAlphaComponent(0.45)
            )
        }
    }
}

private struct AppThemePaletteKey: EnvironmentKey {
    static let defaultValue = AppThemePalette.forTheme(.system)
}

extension EnvironmentValues {
    var appThemePalette: AppThemePalette {
        get { self[AppThemePaletteKey.self] }
        set { self[AppThemePaletteKey.self] = newValue }
    }
}
