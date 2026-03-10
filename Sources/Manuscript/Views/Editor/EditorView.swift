import AppKit
import SwiftUI

@MainActor
struct EditorView: View {
    @ObservedObject var state: EditorState

    var body: some View {
        ZStack(alignment: .topLeading) {
            SearchHighlightingTextView(state: state)

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

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = NSTextView()
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDataDetectionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
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
        context.coordinator.applyStateToView()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var state: EditorState
        weak var textView: NSTextView?
        private var isApplyingState = false

        init(state: EditorState) {
            self.state = state
        }

        func applyStateToView() {
            guard let textView else { return }

            let content = state.getCurrentContent()
            if textView.string != content {
                isApplyingState = true
                textView.string = content
                isApplyingState = false
            }

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

        private func applyHighlightAttributes(on textView: NSTextView, content: String) {
            guard let storage = textView.textStorage else { return }
            let fullRange = NSRange(location: 0, length: storage.length)

            isApplyingState = true
            storage.beginEditing()
            storage.removeAttribute(.backgroundColor, range: fullRange)

            for range in state.searchHighlightRanges {
                let nsRange = nsRange(for: range, in: content)
                guard nsRange.length > 0 else { continue }
                storage.addAttribute(
                    .backgroundColor,
                    value: NSColor.systemYellow.withAlphaComponent(0.32),
                    range: nsRange
                )
            }

            if let active = state.activeSearchHighlightRange {
                let nsRange = nsRange(for: active, in: content)
                if nsRange.length > 0 {
                    storage.addAttribute(
                        .backgroundColor,
                        value: NSColor.systemOrange.withAlphaComponent(0.45),
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
    }
}
