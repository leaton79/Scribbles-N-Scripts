import AppKit
import SwiftUI

struct EditorPresentationSettings: Equatable {
    var fontName: String
    var fontSize: CGFloat
    var lineHeight: CGFloat
    var contentWidth: CGFloat
    var theme: AppTheme

    static let `default` = EditorPresentationSettings(
        fontName: "Menlo",
        fontSize: 14,
        lineHeight: 1.6,
        contentWidth: 860,
        theme: .system
    )
}

@MainActor
struct EditorView: View {
    @ObservedObject var state: EditorState
    var presentation = EditorPresentationSettings.default

    var body: some View {
        ZStack(alignment: .topLeading) {
            SearchHighlightingTextView(state: state, presentation: presentation)

            if state.placeholderVisible {
                Text("Start writing...")
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
        }
    }
}

@MainActor
private struct SearchHighlightingTextView: NSViewRepresentable {
    @ObservedObject var state: EditorState
    let presentation: EditorPresentationSettings

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state, presentation: presentation)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.drawsBackground = true
        textView.backgroundColor = AppThemePalette.forTheme(presentation.theme).editorBackground
        textView.delegate = context.coordinator

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.documentView = textView

        context.coordinator.textView = textView
        context.coordinator.applyStateToView()
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.state = state
        context.coordinator.presentation = presentation
        context.coordinator.applyStateToView()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var state: EditorState
        var presentation: EditorPresentationSettings
        weak var textView: NSTextView?
        private var isApplyingState = false

        init(state: EditorState, presentation: EditorPresentationSettings) {
            self.state = state
            self.presentation = presentation
        }

        func applyStateToView() {
            guard let textView else { return }

            let content = state.getCurrentContent()
            if textView.string != content {
                isApplyingState = true
                textView.string = content
                isApplyingState = false
            }

            applyPresentation(to: textView)
            textView.isEditable = state.isEditable
            applyHighlightAttributes(on: textView, content: content)
            syncSelection(on: textView)
        }

        func textDidChange(_ notification: Notification) {
            guard !isApplyingState, let textView else { return }
            let newValue = textView.string
            let oldValue = state.getCurrentContent()
            if newValue != oldValue {
                state.replaceText(in: 0..<oldValue.count, with: newValue)
            }
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isApplyingState, let textView else { return }
            let selected = textView.selectedRange()
            let lower = max(0, selected.location)
            let upper = max(lower, selected.location + selected.length)
            state.selection = lower..<upper
            state.cursorPosition = upper
        }

        private func syncSelection(on textView: NSTextView) {
            let selection = state.selection ?? (state.cursorPosition..<state.cursorPosition)
            let range = NSRange(location: selection.lowerBound, length: max(0, selection.count))
            if textView.selectedRange() != range {
                isApplyingState = true
                textView.setSelectedRange(range)
                isApplyingState = false
            }
        }

        private func applyPresentation(to textView: NSTextView) {
            let font = resolvedFont()
            let palette = AppThemePalette.forTheme(presentation.theme)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.lineSpacing = max(0, (presentation.lineHeight - 1.0) * font.pointSize)

            textView.font = font
            textView.defaultParagraphStyle = paragraphStyle
            textView.backgroundColor = palette.editorBackground
            textView.textColor = palette.editorText
            textView.insertionPointColor = palette.editorText
            textView.typingAttributes[.font] = font
            textView.typingAttributes[.paragraphStyle] = paragraphStyle
            textView.typingAttributes[.foregroundColor] = palette.editorText

            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            storage.beginEditing()
            storage.addAttribute(.font, value: font, range: fullRange)
            storage.addAttribute(.paragraphStyle, value: paragraphStyle, range: fullRange)
            storage.addAttribute(.foregroundColor, value: palette.editorText, range: fullRange)
            storage.endEditing()
        }

        private func applyHighlightAttributes(on textView: NSTextView, content: String) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)
            let palette = AppThemePalette.forTheme(presentation.theme)

            isApplyingState = true
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)

            for range in state.entityMentionRanges {
                let nsRange = nsRange(for: range, in: content)
                guard nsRange.length > 0 else { continue }
                storage.addAttribute(
                    .backgroundColor,
                    value: palette.entityHighlight,
                    range: nsRange
                )
            }

            for range in state.searchHighlightRanges {
                let nsRange = nsRange(for: range, in: content)
                guard nsRange.length > 0 else { continue }
                storage.addAttribute(
                    .backgroundColor,
                    value: palette.searchHighlight,
                    range: nsRange
                )
            }

            if let active = state.activeSearchHighlightRange {
                let nsRange = nsRange(for: active, in: content)
                if nsRange.length > 0 {
                    storage.addAttribute(
                        .backgroundColor,
                        value: palette.activeSearchHighlight,
                        range: nsRange
                    )
                }
            }

            storage.endEditing()
            isApplyingState = false
        }

        private func nsRange(for range: Range<Int>, in content: String) -> NSRange {
            let lower = max(0, min(range.lowerBound, content.count))
            let upper = max(lower, min(range.upperBound, content.count))
            let start = content.index(content.startIndex, offsetBy: lower)
            let end = content.index(content.startIndex, offsetBy: upper)
            return NSRange(start..<end, in: content)
        }

        private func resolvedFont() -> NSFont {
            if let custom = NSFont(name: presentation.fontName, size: presentation.fontSize) {
                return custom
            }
            return .monospacedSystemFont(ofSize: presentation.fontSize, weight: .regular)
        }
    }
}
