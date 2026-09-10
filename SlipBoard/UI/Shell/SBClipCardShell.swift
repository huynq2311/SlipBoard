import AppKit
import SwiftUI

private nonisolated enum SBClipThumbnailCache {
    static let shared = NSCache<NSString, NSImage>()
    static let assetStore = ClipboardImageAssetStore()
}

/// Carries each visible card's bounds up to the popup shell so its action
/// menus can be positioned next to the item that opened them.
struct SBClipCardAnchorPreferenceKey: PreferenceKey {
    static var defaultValue: [String: Anchor<CGRect>] = [:]

    static func reduce(value: inout [String: Anchor<CGRect>], nextValue: () -> [String: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, latest in latest })
    }
}

struct SBClipCardShell: View {
    let clip: ClipPreviewSummary
    let theme: SBTheme
    @SBLocalizedCopy private var copy
    var width: CGFloat = 216
    var height: CGFloat = 128
    var isSelected: Bool = false
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var onSelect: () -> Void = {}
    var noteEditorState: ClipNoteEditorState? = nil
    var onToggleNoteEditor: () -> Void = {}
    var onUpdateNoteDraft: (String) -> Void = { _ in }
    var onSaveNote: () -> Void = {}
    var onCancelNoteEditing: () -> Void = {}
    var onClearNote: () -> Void = {}
    var onPrimaryAction: () -> Void = {}
    var onOpenContextMenu: () -> Void = {}
    var onPerformContextAction: (String) -> Void = { _ in }

    @State private var isHovering = false
    @State private var loadedThumbnail: NSImage?

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .frame(height: 34)
                    .background(typeHeaderBackground)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            isHovering = hovering
                        }
                    }

                bodyContent
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: max(0, proxy.size.height - 34),
                        alignment: .topLeading
                    )
                    .clipped()
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .background {
            ZStack {
                theme.palette.cardBase
                cardBodyTint
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay { cardRim }
        .shadow(color: restingShadowColor, radius: 6, x: 0, y: 2)
        .shadow(color: selectionGlowColor, radius: isSelected ? 10 : 0, x: 0, y: isSelected ? 2 : 0)
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture(count: 2) {
            onSelect()
            onPrimaryAction()
        }
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                onSelect()
            }
        )
        .simultaneousGesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded(onOpenContextMenu)
        )
        // Right-click now opens the same custom action surface as the card's
        // ellipsis button, instead of a separate native NSMenu with a second
        // action path.
        .background(SBRightClickGesture(action: onOpenContextMenu))
        .anchorPreference(key: SBClipCardAnchorPreferenceKey.self, value: .bounds) {
            [clip.id: $0]
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: theme.spacing.control6) {
            HStack(spacing: 6) {
                Image(systemName: clipKindSymbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(typeColor)

                Text(clipKindLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(typeColor)
                    .lineLimit(1)
            }
            .fixedSize(horizontal: true, vertical: false)

            Spacer(minLength: theme.spacing.control4)

            Text(clip.sourceApp.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(1)

            Text(clip.createdLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)

            Button(action: handleHeaderTap) {
                SBIconAvatar(
                    symbolName: isPreviewRedacted ? redactionSymbolName : clip.sourceApp.symbolName,
                    accentToken: clip.sourceApp.accentToken,
                    theme: theme,
                    size: 20
                )
                .overlay(alignment: .bottomTrailing) {
                    if clip.hasNote && isPreviewRedacted == false {
                        Circle()
                            .fill(theme.palette.accentPrimary)
                            .frame(width: 5, height: 5)
                            .overlay(Circle().stroke(theme.palette.canvas, lineWidth: 1))
                    }
                }
            }
            .buttonStyle(.plain)
            .disabled(isSelected == false || noteInteractionsEnabled == false)
            .accessibilityLabel(copy.text(.accessibilityClipFrom, ["app": clip.sourceApp.displayName]))
            .help(clip.sourceApp.displayName)

            if isHovering {
                Button(action: onOpenContextMenu) {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(theme.palette.textSecondary)
                        .frame(width: 18, height: 18)
                        .background(theme.palette.raised)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.text(.accessibilityMoreActions))
                .transition(.opacity)
            } else if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent(for: .danger))
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            if isPreviewRedacted {
                redactedBody
            } else {
                switch clip.previewStyle {
                case .text:
                    textBody(font: cardBodyFont, color: theme.palette.textPrimary)
                case let .code(languageHint):
                    VStack(alignment: .leading, spacing: theme.spacing.control6) {
                        if let languageHint, languageHint.isEmpty == false {
                            Text(languageHint.uppercased())
                                .font(theme.typography.uppercaseLabel)
                                .foregroundStyle(theme.palette.textTertiary)
                        }
                        textBody(font: cardCodeFont, color: theme.palette.textPrimary)
                    }
                case .image:
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(theme.accentBackground(for: .success))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay {
                            if let thumbnail = thumbnailImage {
                                Image(nsImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                            } else {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(theme.accent(for: .success))
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        .task(id: clip.id) {
                            await loadThumbnailIfNeeded()
                        }
                case let .file(fileExtension):
                    HStack(spacing: theme.spacing.control8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(theme.accent(for: .warning))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(clip.titleText)
                                .font(cardBodyFont)
                                .foregroundStyle(theme.palette.textPrimary)
                                .lineLimit(1)

                            Text(fileExtension?.uppercased() ?? clip.metadataText)
                                .font(cardBodyFont)
                                .foregroundStyle(theme.palette.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if let bodyText = clip.bodyText, bodyText.isEmpty == false {
                        Text(bodyText)
                            .font(cardBodyFont)
                            .foregroundStyle(theme.palette.textSecondary)
                            .lineLimit(min(bodyLineLimit, 4))
                    }
                case .url:
                    textBody(font: cardBodyFont, color: theme.accent(for: .primary))
                case let .color(swatches):
                    HStack(spacing: 3) {
                        ForEach(swatches, id: \.self) { swatch in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(sbHex: swatch) ?? theme.palette.raised)
                                .frame(width: 14, height: 14)
                        }
                    }
                    textBody(font: cardCodeFont, color: theme.palette.textSecondary)
                case .richText:
                    richTextBody
                }
            }

            if showsCollapsedNoteSummary, let noteText = clip.noteText, noteText.isEmpty == false {
                Text(noteText)
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineLimit(2)
            }

            if isInlineEditorVisible, let noteEditorState = noteEditorState {
                ClipNoteEditorInline(
                    state: noteEditorState,
                    theme: theme,
                    onUpdateDraft: onUpdateNoteDraft,
                    onSave: onSaveNote,
                    onCancel: onCancelNoteEditing,
                    onClear: onClearNote
                )
                .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var cachedThumbnailImage: NSImage? {
        guard clip.kind == .image else { return nil }
        return SBClipThumbnailCache.shared.object(forKey: clip.id as NSString)
    }

    private var thumbnailImage: NSImage? {
        cachedThumbnailImage ?? loadedThumbnail
    }

    private func loadThumbnailIfNeeded() async {
        guard clip.kind == .image, cachedThumbnailImage == nil else { return }

        let clipID = clip.id
        let decoded = await Task.detached(priority: .userInitiated) { () -> NSImage? in
            guard let data = SBClipThumbnailCache.assetStore.data(for: clipID) else { return nil }
            return NSImage(data: data)
        }.value

        guard let decoded else { return }
        SBClipThumbnailCache.shared.setObject(decoded, forKey: clipID as NSString)
        if clip.id == clipID {
            loadedThumbnail = decoded
        }
    }

    private var typeColor: Color {
        SBClipTypeColor.base(for: clip.kind)
    }

    private var typeHeaderBackground: Color {
        typeColor.opacity(theme.mode == .dark ? 0.12 : 0.10)
    }

    private var cardBodyTint: Color {
        typeColor.opacity(theme.mode == .dark ? 0.05 : 0.06)
    }

    private var cardBorderTint: Color {
        guard let rim = theme.glassRim else {
            return typeColor.opacity(theme.mode == .dark ? 0.22 : 0.18)
        }
        return typeColor.opacity(rim.cardBorderOpacity)
    }

    /// Cards stay on their type color and never become glass themselves. On a
    /// glass theme they only pick up a softer rim, a top highlight that catches
    /// the same light as the shell, and a lit selection instead of a hard border.
    @ViewBuilder
    private var cardRim: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)

        if let rim = theme.glassRim {

            ZStack {
                shape.strokeBorder(cardBorderTint, lineWidth: theme.border.hairline)

                shape
                    .inset(by: 0.5)
                    .strokeBorder(
                        LinearGradient(
                            colors: [rim.cardHighlight, .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: theme.border.hairline
                    )

                if isSelected {
                    shape.strokeBorder(
                        LinearGradient(
                            colors: [
                                theme.palette.accentPrimary.opacity(0.85),
                                theme.palette.accentPrimary.opacity(0.35)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
                }
            }
        } else {
            shape.stroke(
                isSelected ? theme.palette.accentPrimary : cardBorderTint,
                lineWidth: isSelected ? 1.5 : theme.border.hairline
            )
        }
    }

    private var restingShadowColor: Color {
        theme.glassRim?.cardShadow ?? .clear
    }

    private var selectionGlowColor: Color {
        guard isSelected, let rim = theme.glassRim else { return .clear }
        return rim.selectionGlow
    }

    private var cardBodyFont: Font {
        .system(size: 13, weight: .regular)
    }

    private var cardCodeFont: Font {
        .system(size: 13, weight: .regular, design: .monospaced)
    }

    private func textBody(font: Font, color: Color) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            Text(clip.titleText)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(clip.kind == .url ? 2 : bodyLineLimit)

            if let bodyText = clip.bodyText, bodyText.isEmpty == false {
                Text(bodyText)
                    .font(font)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineLimit(max(2, bodyLineLimit - 2))
            }
        }
    }

    @ViewBuilder
    private var richTextBody: some View {
        if let richTextRTFData = clip.richTextRTFData {
            if let preview = SBRichTextPreview.makeAttributedString(from: richTextRTFData, theme: theme) {
                Text(preview)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineSpacing(5)
                    .lineLimit(bodyLineLimit)
                    .truncationMode(.tail)
            } else {
                SBRichTextPreviewFallback(theme: theme)
            }
        } else {
            // Plain-text rich clips retain the Rich Text header but use the normal preview.
            textBody(font: cardBodyFont, color: theme.palette.textPrimary)
        }
    }

    // Rough line-count the taller card's preview area can hold, so text/code
    // previews actually use the extra height instead of leaving it blank.
    private var bodyLineLimit: Int {
        let bodyAreaHeight = height - 34 - 24
        let approxLineHeight: CGFloat = 16
        return max(3, Int((bodyAreaHeight / approxLineHeight).rounded(.down)))
    }

    private var headerLabelText: String {
        if isPreviewRedacted {
            return clip.sourceApp.displayName
        }

        if clip.hasNote, let noteText = clip.noteText, noteText.isEmpty == false {
            return noteText
        }

        return clip.sourceApp.displayName
    }

    private var clipKindLabel: String {
        switch clip.kind {
        case .text:
            return copy.text(.contentText)
        case .code:
            return copy.text(.contentCode)
        case .image:
            return copy.text(.contentImage)
        case .file:
            return copy.text(.contentFile)
        case .url:
            return copy.text(.contentURL)
        case .color:
            return copy.text(.contentColor)
        case .richText:
            return copy.text(.contentRichText)
        }
    }

    private var clipKindSymbolName: String {
        switch clip.kind {
        case .text:
            return "text.alignleft"
        case .code:
            return "chevron.left.forwardslash.chevron.right"
        case .image:
            return "photo"
        case .file:
            return "paperclip"
        case .url:
            return "link"
        case .color:
            return "paintpalette"
        case .richText:
            return "textformat"
        }
    }

    private var isInlineEditorVisible: Bool {
        guard isPreviewRedacted == false else { return false }
        guard let noteEditorState else { return false }
        return noteEditorState.clipID == clip.id && noteEditorState.isPresented && isSelected
    }

    private var showsCollapsedNoteSummary: Bool {
        guard isPreviewRedacted == false else { return false }
        return clip.hasNote && isInlineEditorVisible == false && headerLabelText == clip.sourceApp.displayName
    }

    private func handleHeaderTap() {
        if noteInteractionsEnabled == false {
            onSelect()
        } else if isSelected {
            onToggleNoteEditor()
        } else {
            onSelect()
        }
    }

    private var isPreviewRedacted: Bool {
        guard let securitySnapshot else { return false }
        return securitySnapshot.lockState.revealsProtectedContent == false || securitySnapshot.isPreviewRedactionActive
    }

    private var noteInteractionsEnabled: Bool {
        guard let securitySnapshot else { return true }
        return securitySnapshot.lockState.revealsProtectedContent && securitySnapshot.isPreviewRedactionActive == false
    }

    private var headerLabelColor: Color {
        if isPreviewRedacted {
            return theme.palette.textSecondary
        }

        return clip.hasNote ? theme.palette.accentPrimary : theme.palette.textSecondary
    }

    private var redactionTone: SBAccentTone {
        guard let securitySnapshot else { return .neutral }
        return securitySnapshot.lockState.revealsProtectedContent ? .info : .danger
    }

    private var redactionSymbolName: String {
        guard let securitySnapshot else { return "eye.slash" }
        return securitySnapshot.lockState.revealsProtectedContent ? "eye.slash" : "lock.fill"
    }

    private var redactedBody: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack(spacing: theme.spacing.control6) {
                SBStatusPill(
                    title: securitySnapshot?.lockState.revealsProtectedContent == false ? copy.text(.popupLocked).uppercased() : copy.text(.popupPrivate).uppercased(),
                    theme: theme,
                    tone: redactionTone
                )

                Text(securitySnapshot?.lockState.revealsProtectedContent == false ? copy.text(.popupUnlockRequired) : copy.text(.popupPreviewHidden))
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textTertiary)
                    .lineLimit(1)
            }

            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .fill(theme.palette.raised)
                .frame(height: 14)

            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .fill(theme.palette.raised.opacity(0.82))
                .frame(height: 14)
                .padding(.trailing, 22)

            Text(redactionDetailText)
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var redactionDetailText: String {
        guard let securitySnapshot else {
            return copy.text(.clipRedactionNoSnapshot)
        }

        if securitySnapshot.lockState.revealsProtectedContent == false {
            return copy.text(.clipRedactionLocked)
        }

        return copy.text(.clipRedactionPrivacy)
    }
}

private struct SBRightClickGesture: NSViewRepresentable {
    let action: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(action: action)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = false
        view.addGestureRecognizer(context.coordinator.recognizer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.action = action
    }

    final class Coordinator: NSObject {
        var action: () -> Void
        let recognizer: NSClickGestureRecognizer

        init(action: @escaping () -> Void) {
            self.action = action
            recognizer = NSClickGestureRecognizer()
            super.init()
            recognizer.target = self
            recognizer.action = #selector(handleRightClick)
            recognizer.buttonMask = 0x2
        }

        @objc private func handleRightClick() {
            action()
        }
    }
}

private enum SBRichTextPreview {
    static func makeAttributedString(from rtfData: Data, theme: SBTheme) -> AttributedString? {
        guard let source = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ), source.length > 0, containsUnsupportedContent(source) == false else {
            return nil
        }

        let normalized = NSMutableAttributedString(attributedString: source)
        let range = NSRange(location: 0, length: normalized.length)
        normalized.enumerateAttribute(.font, in: range) { value, attributeRange, _ in
            let sourceFont = value as? NSFont
            let traits = sourceFont?.fontDescriptor.symbolicTraits ?? []
            let isMonospaced = traits.contains(.monoSpace) || traits.contains(.classModernSerifs)
            let isBold = traits.contains(.bold)
            let isItalic = traits.contains(.italic)
            var font = isMonospaced
                ? NSFont.monospacedSystemFont(ofSize: 13, weight: isBold ? .semibold : .regular)
                : NSFont.systemFont(ofSize: 13, weight: isBold ? .semibold : .regular)

            if isItalic {
                font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
            }

            normalized.addAttribute(.font, value: font, range: attributeRange)
        }
        normalized.enumerateAttribute(.link, in: range) { value, attributeRange, _ in
            guard value != nil else { return }
            normalized.addAttributes([
                .foregroundColor: NSColor(theme.accent(for: .primary)),
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ], range: attributeRange)
        }

        return AttributedString(normalized)
    }

    private static func containsUnsupportedContent(_ value: NSAttributedString) -> Bool {
        var hasAttachment = false
        value.enumerateAttribute(.attachment, in: NSRange(location: 0, length: value.length)) { attachment, _, stop in
            if attachment != nil {
                hasAttachment = true
                stop.pointee = true
            }
        }
        return hasAttachment
    }
}

private struct SBRichTextPreviewFallback: View {
    let theme: SBTheme
    @SBLocalizedCopy private var copy

    var body: some View {
        HStack(spacing: theme.spacing.control6) {
            Image(systemName: "doc.richtext")
                .foregroundStyle(theme.accent(for: .primary))
            Text(copy.text(.popupRichContent))
                .font(theme.typography.rowPrimary)
                .foregroundStyle(theme.palette.textSecondary)
        }
        .padding(theme.spacing.control8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.accentBackground(for: .primary).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
    }
}

struct SBHorizontalClipRail: View {
    let clips: [ClipPreviewSummary]
    let theme: SBTheme
    let emptyTitle: String
    let emptyDetail: String
    var cardWidth: CGFloat = 216
    var cardHeight: CGFloat = 128
    /// Puts the scrollbar in its own strip below the cards instead of over
    /// their bottom edge. Only for a rail with free space underneath it.
    var reservesScrollbarTrack: Bool = false
    var selectedClipID: String?
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var onSelectClip: (String) -> Void = { _ in }
    var noteEditorState: ClipNoteEditorState? = nil
    var onToggleNoteEditor: (String) -> Void = { _ in }
    var onUpdateNoteDraft: (String, String) -> Void = { _, _ in }
    var onSaveNoteDraft: (String) -> Void = { _ in }
    var onCancelNoteEditing: (String) -> Void = { _ in }
    var onClearNote: (String) -> Void = { _ in }
    var onPrimaryAction: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    @State private var visibleClipIDs: Set<String> = []
    @State private var scrollMetrics = SBRailScrollMetrics()
    @State private var scrollPosition = ScrollPosition(x: 0)
    @State private var isHoveringRail = false
    @Environment(\.sbPopupPresentationID) private var popupPresentationID

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: theme.spacing.railGap) {
                    if clips.isEmpty {
                        SBEmptyStateCard(
                            title: emptyTitle,
                            detailText: emptyDetail,
                            theme: theme
                        )
                        .frame(width: 220, alignment: .leading)
                    } else {
                        ForEach(clips) { clip in
                            SBClipCardShell(
                                clip: clip,
                                theme: theme,
                                width: cardWidth,
                                height: cardHeight,
                                isSelected: clip.id == selectedClipID,
                                securitySnapshot: securitySnapshot,
                                onSelect: {
                                    onSelectClip(clip.id)
                                },
                                noteEditorState: noteEditorState?.clipID == clip.id ? noteEditorState : nil,
                                onToggleNoteEditor: {
                                    onToggleNoteEditor(clip.id)
                                },
                                onUpdateNoteDraft: { draftText in
                                    onUpdateNoteDraft(clip.id, draftText)
                                },
                                onSaveNote: {
                                    onSaveNoteDraft(clip.id)
                                },
                                onCancelNoteEditing: {
                                    onCancelNoteEditing(clip.id)
                                },
                                onClearNote: {
                                    onClearNote(clip.id)
                                },
                                onPrimaryAction: {
                                    if securitySnapshot?.lockState.revealsProtectedContent != false,
                                       securitySnapshot?.isPreviewRedactionActive != true {
                                        onPrimaryAction(clip.id)
                                    }
                                },
                                onOpenContextMenu: {
                                    if securitySnapshot?.lockState.revealsProtectedContent != false,
                                       securitySnapshot?.isPreviewRedactionActive != true {
                                        onOpenContextMenu(clip.id)
                                    }
                                },
                                onPerformContextAction: onPerformContextAction
                            )
                            .id(clip.id)
                            .transition(.opacity.combined(with: .scale(scale: 0.94)))
                            .onScrollVisibilityChange(threshold: 0.85) { isVisible in
                                if isVisible {
                                    visibleClipIDs.insert(clip.id)
                                } else {
                                    visibleClipIDs.remove(clip.id)
                                }
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.22), value: clips)
                .padding(.top, 5)
                .padding(.bottom, 2)
            }
            .contentMargins(.horizontal, theme.spacing.popupPadding, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .onAppear {
                scrollToSelectionIfNeeded(using: proxy, animated: false)
            }
            .onChange(of: selectedClipID) { _, _ in
                scrollToSelectionIfNeeded(using: proxy, animated: true)
            }
            .onChange(of: popupPresentationID) { _, _ in
                // The panel keeps this view alive while hidden, so its scroll
                // offset survives a reopen; start again from the newest clip.
                guard let firstClipID = clips.first?.id else { return }
                proxy.scrollTo(firstClipID, anchor: .leading)
            }
            .onScrollGeometryChange(for: SBRailScrollMetrics.self) { geometry in
                SBRailScrollMetrics(
                    contentWidth: geometry.contentSize.width,
                    viewportWidth: geometry.containerSize.width,
                    offsetX: geometry.contentOffset.x
                )
            } action: { _, newValue in
                scrollMetrics = newValue
            }
            .padding(.bottom, reservesScrollbarTrack ? Self.scrollbarTrackHeight : 0)
            // Empty padding isn't hit-testable; without this the track strip
            // under the cards would not count as hovering the rail.
            .contentShape(Rectangle())
            .overlay(alignment: .bottom) {
                if scrollMetrics.contentWidth > scrollMetrics.viewportWidth + 1 {
                    SBRailScrollbarThumb(
                        contentWidth: scrollMetrics.contentWidth,
                        viewportWidth: max(scrollMetrics.viewportWidth - theme.spacing.popupPadding * 2, 0),
                        offsetX: scrollMetrics.offsetX,
                        theme: theme,
                        isVisible: isHoveringRail,
                        hitHeight: reservesScrollbarTrack ? Self.scrollbarTrackHeight : 12,
                        onDrag: { targetOffsetX in
                            scrollPosition = ScrollPosition(x: targetOffsetX)
                        }
                    )
                    .padding(.horizontal, theme.spacing.popupPadding)
                    .padding(.bottom, reservesScrollbarTrack ? 0 : 3)
                }
            }
            // After the overlay, so the pointer resting on the thumb itself
            // still counts as hovering the rail.
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHoveringRail = hovering
                }
            }
        }
    }

    private static let scrollbarTrackHeight: CGFloat = 16

    private func scrollToSelectionIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedClipID,
              clips.contains(where: { $0.id == selectedClipID }),
              visibleClipIDs.contains(selectedClipID) == false else {
            return
        }

        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(selectedClipID, anchor: .leading)
            }
        } else {
            proxy.scrollTo(selectedClipID, anchor: .leading)
        }
    }
}

extension EnvironmentValues {
    /// Bumped each time the popup is shown again.
    @Entry var sbPopupPresentationID = 0
}

private struct SBRailScrollMetrics: Equatable {
    var contentWidth: CGFloat = 0
    var viewportWidth: CGFloat = 0
    var offsetX: CGFloat = 0
}

private struct SBRailScrollbarThumb: View {
    let contentWidth: CGFloat
    let viewportWidth: CGFloat
    let offsetX: CGFloat
    let theme: SBTheme
    var isVisible: Bool = true
    var hitHeight: CGFloat = 12
    var onDrag: (CGFloat) -> Void = { _ in }

    @State private var dragStartOffsetX: CGFloat?

    private var thumbWidth: CGFloat {
        guard contentWidth > 0 else { return 0 }
        let ratio = viewportWidth / contentWidth
        return max(viewportWidth * ratio, 28)
    }

    private var maxScrollable: CGFloat {
        max(contentWidth - viewportWidth, 1)
    }

    private var maxThumbOffset: CGFloat {
        max(viewportWidth - thumbWidth, 0)
    }

    private var thumbOffsetX: CGFloat {
        let progress = min(max(offsetX / maxScrollable, 0), 1)
        return maxThumbOffset * progress
    }

    var body: some View {
        // Stay visible and grabbable mid-drag even if the pointer slips off
        // the rail; otherwise hover ends and the drag is cancelled.
        let isActive = isVisible || dragStartOffsetX != nil

        Capsule()
            .fill(theme.palette.accentPrimary.opacity(isActive ? 0.65 : 0))
            .frame(width: thumbWidth, height: 6)
            .frame(width: thumbWidth, height: hitHeight)
            .contentShape(Rectangle())
            .gesture(
                // Global space: the thumb moves while dragging, so a local
                // translation shrinks under the pointer and the thumb lags.
                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                    .onChanged { value in
                        let startOffsetX = dragStartOffsetX ?? offsetX
                        if dragStartOffsetX == nil {
                            dragStartOffsetX = offsetX
                        }
                        guard maxThumbOffset > 0 else { return }
                        let deltaProgress = value.translation.width / maxThumbOffset
                        let newOffsetX = min(max(startOffsetX + deltaProgress * maxScrollable, 0), maxScrollable)
                        onDrag(newOffsetX)
                    }
                    .onEnded { _ in
                        dragStartOffsetX = nil
                    }
            )
            .allowsHitTesting(isActive)
            .frame(width: viewportWidth, alignment: .leading)
            .offset(x: thumbOffsetX)
    }
}

private struct ClipNoteEditorInline: View {
    let state: ClipNoteEditorState
    let theme: SBTheme
    @SBLocalizedCopy private var copy
    let onUpdateDraft: (String) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            HStack(spacing: theme.spacing.control6) {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(state.isEditable ? theme.palette.accentPrimary : theme.palette.textTertiary)

                TextField(
                    state.hasPersistedNote ? copy.text(.popupUpdateNote) : copy.text(.popupAddNote),
                    text: Binding(
                        get: { state.draftText },
                        set: onUpdateDraft
                    )
                )
                .textFieldStyle(.plain)
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textPrimary)
                .disabled(state.isEditable == false)

                if state.canClear {
                    Button(action: onClear) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(theme.palette.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .disabled(state.isEditable == false)
                }
            }

            HStack(spacing: theme.spacing.control6) {
                if state.isEditable == false {
                    Text(copy.text(.popupNotesLocked))
                        .font(theme.typography.keyboard)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(2)
                } else {
                    Button(copy.text(.cancel), action: onCancel)
                        .buttonStyle(.plain)
                        .font(theme.typography.keyboard)
                        .foregroundStyle(theme.palette.textSecondary)

                    Spacer(minLength: theme.spacing.control6)

                    Button(copy.text(.save), action: onSave)
                        .buttonStyle(.plain)
                        .font(theme.typography.keyboard)
                        .foregroundStyle(state.canSave ? Color.white : theme.palette.textTertiary)
                        .padding(.horizontal, theme.spacing.control6)
                        .padding(.vertical, 3)
                        .background(state.canSave ? theme.palette.accentPrimary : theme.palette.raised)
                        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
                        .disabled(state.canSave == false)
                }
            }
        }
        .padding(.horizontal, theme.spacing.control8)
        .padding(.vertical, theme.spacing.control6)
        .background(theme.palette.canvas)
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.control, style: .continuous)
                .stroke(
                    state.isEditable ? theme.palette.accentPrimary : theme.palette.border,
                    lineWidth: theme.border.hairline
                )
        )
        .opacity(state.isEditable ? 1 : 0.8)
    }
}

private extension Color {
    init?(sbHex value: String) {
        let sanitized = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard sanitized.count == 6, let hex = UInt32(sanitized, radix: 16) else {
            return nil
        }

        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }
}
