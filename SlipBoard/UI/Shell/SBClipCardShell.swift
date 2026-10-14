import AppKit
import SwiftUI

private nonisolated enum SBClipThumbnailCache {
    static let shared: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        // Without a limit the decoded card thumbnails were never evicted, so
        // the cache grew for as long as the user kept scrolling image clips.
        cache.totalCostLimit = 32 * 1_024 * 1_024
        return cache
    }()
    static let assetStore = ClipboardImageAssetStore()
    static let pixelSizes = NSCache<NSString, NSValue>()
    static let characterCounts = NSCache<NSString, NSNumber>()
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
    var width: CGFloat = SBPopupLayoutMetrics.cardWidth
    var height: CGFloat = 128
    var isSelected: Bool = false
    var securitySnapshot: SecurityRuntimeSnapshot? = nil
    var onSelect: () -> Void = {}
    var noteEditorState: ClipNoteEditorState? = nil
    var onToggleNoteEditor: () -> Void = {}
    var onUpdateNoteDraft: (String) -> Void = { _ in }
    var onSaveNote: () -> Void = {}
    var onCancelNoteEditing: () -> Void = {}
    var onPrimaryAction: () -> Void = {}
    var onOpenContextMenu: () -> Void = {}
    var onPerformContextAction: (String) -> Void = { _ in }

    @AppStorage(QuickPasteModifier.storageKey) private var quickPasteModifierRawValue = QuickPasteModifier.command.rawValue
    private var quickPasteModifier: QuickPasteModifier {
        QuickPasteModifier(rawValue: quickPasteModifierRawValue) ?? .command
    }
    @State private var loadedThumbnail: NSImage?
    @State private var loadedPixelSize: CGSize?
    @State private var loadedFileBytes: Int64?
    @State private var loadedCharacterCount: Int?

    private static let footerHeight: CGFloat = 27
    private static let editingFooterHeight: CGFloat = 40

    private struct FooterTaskKey: Hashable {
        let clipID: String
        let isVisible: Bool
    }

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .frame(height: 34)
                    .background(typeHeaderBackground)

                bodyContent
                    .padding(12)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: max(0, proxy.size.height - 34 - footerReservedHeight),
                        alignment: .topLeading
                    )
                    .clipped()

                if showsFooter {
                    footer
                }
            }
        }
        // Keyed on visibility too, so a card hidden by App Lock loads its
        // metrics once it is unlocked instead of staying blank.
        .task(id: FooterTaskKey(clipID: clip.id, isVisible: showsFooter)) {
            await loadFooterMetricsIfNeeded()
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
        .simultaneousGesture(
            TapGesture(count: 1)
                .modifiers(quickPasteModifier.eventModifiers ?? [])
                .onEnded {
                    guard quickPasteModifier.eventModifiers != nil else { return }
                    onSelect()
                    onPrimaryAction()
                }
        )
        // Right-click opens the card's action menu next to the card, instead
        // of a separate native NSMenu with a second action path. It has to sit
        // above the card: as a background it never received the click.
        .overlay(SBRightClickGesture(action: onOpenContextMenu))
        .anchorPreference(key: SBClipCardAnchorPreferenceKey.self, value: .bounds) {
            [clip.id: $0]
        }
    }

    // A redacted card keeps the lock glyph so it does not reveal the source app.
    @ViewBuilder
    private var headerAvatar: some View {
        if isPreviewRedacted {
            SBIconAvatar(symbolName: redactionSymbolName, accentToken: clip.sourceApp.accentToken, theme: theme, size: 20)
        } else {
            SBSourceAppAvatar(
                appID: clip.sourceApp.id,
                symbolName: clip.sourceApp.symbolName,
                accentToken: clip.sourceApp.accentToken,
                theme: theme,
                size: 20
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: theme.spacing.control6) {
            // When the card is too narrow the header gives way in this order: the
            // source app name goes first, then the kind label is cut with an
            // ellipsis. The time and the avatar are never pushed out of the card.
            HStack(spacing: 6) {
                Image(systemName: clipKindSymbolName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(typeColor)
                    .fixedSize()

                Text(clipKindLabel)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(typeColor)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .layoutPriority(2)

            Spacer(minLength: theme.spacing.control4)

            Text(clip.sourceApp.displayName)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(0)

            Text(clip.createdLabel)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)

            Button(action: handleHeaderTap) {
                headerAvatar
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
            .fixedSize()
            .layoutPriority(3)
            .disabled(isSelected == false || noteInteractionsEnabled == false)
            .accessibilityLabel(copy.text(.accessibilityClipFrom, ["app": clip.sourceApp.displayName]))
            .help(clip.sourceApp.displayName)

            // Actions open with a right-click (or Control-click) on the card.
            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent(for: .danger))
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
                            Text(sbCardDisplayText(clip.titleText))
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
                        Text(sbCardDisplayText(bodyText))
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
        let decoded = await Task.detached(priority: .userInitiated) { () -> (NSImage, Int)? in
            // 768 px covers the largest card (264 x 190 pt) at 2x with room for
            // aspect-fill cropping.
            guard let thumbnail = SBClipThumbnailCache.assetStore.thumbnail(for: clipID, maxPixelSize: 768) else {
                return nil
            }
            return (NSImage(cgImage: thumbnail, size: .zero), thumbnail.bytesPerRow * thumbnail.height)
        }.value

        guard let (decoded, cost) = decoded else { return }
        SBClipThumbnailCache.shared.setObject(decoded, forKey: clipID as NSString, cost: cost)
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
            Text(sbCardDisplayText(clip.titleText))
                .font(font)
                .foregroundStyle(color)
                .lineLimit(clip.kind == .url ? 2 : bodyLineLimit)

            if let bodyText = clip.bodyText, bodyText.isEmpty == false {
                Text(sbCardDisplayText(bodyText))
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

    // Colors have nothing worth measuring, and a redacted card must not reveal
    // the length, size or dimensions of what it hides.
    private var showsFooter: Bool {
        guard isPreviewRedacted == false else { return false }
        return clip.kind != .color || footerNoteText != nil || isInlineEditorVisible
    }

    /// A note replaces the footer's metrics; it says more about the clip.
    private var footerNoteText: String? {
        guard clip.hasNote, let noteText = clip.noteText else { return nil }
        // One line in the footer, so line breaks become spaces.
        let trimmed = noteText
            .split(whereSeparator: \.isNewline)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespaces)
        return trimmed.isEmpty ? nil : trimmed
    }

    private var footerReservedHeight: CGFloat {
        guard showsFooter else { return 0 }
        return isInlineEditorVisible ? Self.editingFooterHeight : Self.footerHeight
    }

    @ViewBuilder
    private var footer: some View {
        if isInlineEditorVisible, let noteEditorState {
            ClipNoteFooterEditor(
                state: noteEditorState,
                theme: theme,
                onUpdateDraft: onUpdateNoteDraft,
                onSave: onSaveNote,
                onCancel: onCancelNoteEditing
            )
            .padding(.horizontal, 8)
            .padding(.bottom, 9)
            .frame(height: Self.editingFooterHeight, alignment: .bottom)
        } else if let footerNoteText {
            HStack(spacing: 4) {
                Image(systemName: "note.text")
                    .font(.system(size: 10, weight: .semibold))
                Text(footerNoteText)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .foregroundStyle(theme.palette.accentPrimary)
            .help(footerNoteText)
            .padding(.horizontal, 12)
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: Self.footerHeight)
        } else {
            metricsFooter
        }
    }

    private var metricsFooter: some View {
        Text(footerText ?? " ")
            .font(.system(size: 12, weight: .medium).monospacedDigit())
            .foregroundStyle(theme.palette.textTertiary)
            .lineLimit(1)
            .padding(.horizontal, 12)
            // Lifts the text off the card's bottom edge.
            .padding(.bottom, 5)
            .frame(maxWidth: .infinity, alignment: .center)
            .frame(height: Self.footerHeight)
    }

    private var footerText: String? {
        switch clip.kind {
        case .text, .code, .richText, .url:
            guard let count = characterCount else { return nil }
            let key: LocalizationKey = count == 1 ? .cardCharacterCountSingular : .cardCharacterCountPlural
            return copy.text(key, ["count": count.formatted(.number.locale(Locale(identifier: copy.currentLanguage.localeIdentifier)))])
        case .image:
            guard let size = loadedPixelSize ?? SBClipThumbnailCache.pixelSizes.object(forKey: clip.id as NSString)?.sizeValue else {
                return nil
            }
            return "\(Int(size.width))x\(Int(size.height))"
        case .file:
            guard let bytes = loadedFileBytes else { return nil }
            return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
        case .color:
            return nil
        }
    }

    // Counting characters walks the whole string (about 16 ms per MB of
    // non-ASCII text), and a card redraws on every selection change. Short
    // text is counted inline; long text is counted once in the background.
    private static let inlineCountByteLimit = 20_000

    private var characterCount: Int? {
        if clip.titleText.utf8.count <= Self.inlineCountByteLimit {
            return clip.titleText.count
        }
        return loadedCharacterCount
            ?? SBClipThumbnailCache.characterCounts.object(forKey: clip.id as NSString)?.intValue
    }

    private func loadFooterMetricsIfNeeded() async {
        guard showsFooter else { return }
        let clipID = clip.id

        switch clip.kind {
        case .text, .code, .richText, .url:
            guard clip.titleText.utf8.count > Self.inlineCountByteLimit,
                  SBClipThumbnailCache.characterCounts.object(forKey: clipID as NSString) == nil else { return }
            let text = clip.titleText
            let count = await Task.detached(priority: .utility) { text.count }.value
            SBClipThumbnailCache.characterCounts.setObject(NSNumber(value: count), forKey: clipID as NSString)
            loadedCharacterCount = count
        case .image:
            if let cached = SBClipThumbnailCache.pixelSizes.object(forKey: clipID as NSString) {
                loadedPixelSize = cached.sizeValue
                return
            }
            let size = await Task.detached(priority: .utility) {
                SBClipThumbnailCache.assetStore.pixelSize(for: clipID)
            }.value
            guard let size else { return }
            SBClipThumbnailCache.pixelSizes.setObject(NSValue(size: size), forKey: clipID as NSString)
            loadedPixelSize = size
        case .file:
            let paths = clip.filePaths
            loadedFileBytes = await Task.detached(priority: .utility) {
                var total: Int64 = 0
                var foundAny = false
                for path in paths {
                    let attributes = try? FileManager.default.attributesOfItem(atPath: path)
                    guard attributes?[.type] as? FileAttributeType == .typeRegular,
                          let size = attributes?[.size] as? NSNumber else { continue }
                    total += size.int64Value
                    foundAny = true
                }
                return foundAny ? total : nil
            }.value
        default:
            break
        }
    }

    // Rough line-count the taller card's preview area can hold, so text/code
    // previews actually use the extra height instead of leaving it blank.
    private var bodyLineLimit: Int {
        let bodyAreaHeight = height - 34 - 24 - footerReservedHeight
        let approxLineHeight: CGFloat = 16
        return max(3, Int((bodyAreaHeight / approxLineHeight).rounded(.down)))
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

    func makeNSView(context: Context) -> RightClickView {
        let view = RightClickView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: RightClickView, context: Context) {
        nsView.action = action
    }

    /// Takes part in hit testing only for a right mouse down, so every other
    /// click and hover still reaches the SwiftUI card underneath.
    final class RightClickView: NSView {
        var action: () -> Void = {}

        override func hitTest(_ point: NSPoint) -> NSView? {
            guard NSApp.currentEvent?.type == .rightMouseDown else { return nil }
            return super.hitTest(point)
        }

        override func rightMouseDown(with event: NSEvent) {
            action()
        }
    }
}

private enum SBRichTextPreview {
    private static let previewCharacterLimit = 1_200

    static func makeAttributedString(from rtfData: Data, theme: SBTheme) -> AttributedString? {
        guard let source = try? NSAttributedString(
            data: rtfData,
            options: [.documentType: NSAttributedString.DocumentType.rtf],
            documentAttributes: nil
        ), source.length > 0, containsUnsupportedContent(source) == false else {
            return nil
        }

        // A card shows at most eight lines, so styling and handing SwiftUI the
        // whole document only to truncate it is wasted layout work.
        let previewSource = source.length > previewCharacterLimit
            ? source.attributedSubstring(from: NSRange(location: 0, length: previewCharacterLimit))
            : source
        let normalized = NSMutableAttributedString(attributedString: previewSource)
        let range = NSRange(location: 0, length: normalized.length)
        normalized.addAttribute(.foregroundColor, value: NSColor(theme.palette.textPrimary), range: range)
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

/// The real icon of the app a clip was copied from. `appID` is the source
/// app's bundle id; when no installed app has it (or it is just a display
/// name), the symbol avatar is shown instead.
struct SBSourceAppAvatar: View {
    let appID: String
    let symbolName: String?
    let accentToken: String
    let theme: SBTheme
    let size: CGFloat

    @State private var icon: NSImage?

    var body: some View {
        Group {
            if let icon = icon ?? SBSourceAppIconCache.cachedIcon(for: appID) {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: size, height: size)
            } else {
                SBIconAvatar(symbolName: symbolName, accentToken: accentToken, theme: theme, size: size)
            }
        }
        .task(id: appID) {
            icon = await SBSourceAppIconCache.icon(for: appID)
        }
    }
}

private nonisolated enum SBSourceAppIconCache {
    private static let icons = NSCache<NSString, NSImage>()
    // Ids with no installed app, so the lookup is not repeated on every draw.
    private static let unresolved = NSCache<NSString, NSNumber>()

    static func cachedIcon(for appID: String) -> NSImage? {
        icons.object(forKey: appID as NSString)
    }

    static func icon(for appID: String) async -> NSImage? {
        if let cached = cachedIcon(for: appID) { return cached }
        if unresolved.object(forKey: appID as NSString) != nil { return nil }

        let resolved = await Task.detached(priority: .utility) { () -> NSImage? in
            guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID) else { return nil }
            let image = NSWorkspace.shared.icon(forFile: url.path)
            // Twice the 20 pt avatar, so it stays sharp on Retina without keeping the full icns.
            image.size = NSSize(width: 40, height: 40)
            return image
        }.value

        if let resolved {
            icons.setObject(resolved, forKey: appID as NSString)
        } else {
            unresolved.setObject(1, forKey: appID as NSString)
        }
        return resolved
    }
}

struct SBHorizontalClipRail: View {
    let clips: [ClipPreviewSummary]
    let theme: SBTheme
    let emptyTitle: String
    let emptyDetail: String
    var cardWidth: CGFloat = SBPopupLayoutMetrics.cardWidth
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
    var onPrimaryAction: (String) -> Void = { _ in }
    var onOpenContextMenu: (String) -> Void = { _ in }
    var onPerformContextAction: (String) -> Void = { _ in }
    @State private var visibleClipIDs: Set<String> = []
    @State private var scrollMetrics = SBRailScrollMetrics()
    @State private var scrollPosition = ScrollPosition(x: 0)
    @State private var isHoveringRail = false
    @State private var lastClipIDs: [String] = []
    @State private var lastClipIDsChangeAt = Date.distantPast
    @Environment(\.sbPopupPresentationID) private var popupPresentationID

    private var clipIDs: [String] { clips.map(\.id) }

    // Animating every change to the rail stacked transitions on top of each
    // other when clips arrived in quick succession or hundreds were pruned at
    // once, leaving cards half faded and overlapping. Only a change of one or
    // two cards, not right after another change, is animated. The @State
    // values still hold the previous change while the body is evaluated.
    private var railAnimation: Animation? {
        let changedCount = Set(clipIDs).symmetricDifference(lastClipIDs).count
        let isBurst = Date().timeIntervalSince(lastClipIDsChangeAt) < 0.4
        guard isBurst == false else { return nil }
        // A filter or search swaps most cards; a quick fade reads better than
        // springing a whole row.
        return changedCount <= 2 ? SBMotion.rail : .easeOut(duration: 0.16)
    }

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
                .animation(railAnimation, value: clipIDs)
                .padding(.top, 5)
                .padding(.bottom, 2)
            }
            .contentMargins(.horizontal, theme.spacing.popupPadding, for: .scrollContent)
            .scrollPosition($scrollPosition)
            .onAppear {
                lastClipIDs = clipIDs
                scrollToSelectionIfNeeded(using: proxy, animated: false)
            }
            .onChange(of: clipIDs) { _, newIDs in
                lastClipIDs = newIDs
                lastClipIDsChangeAt = Date()
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

/// Edits a clip's note in place of the card footer. Return saves and Escape
/// closes without saving (the popup routes Escape here while it is open);
/// saving an empty note removes it.
private struct ClipNoteFooterEditor: View {
    let state: ClipNoteEditorState
    let theme: SBTheme
    @SBLocalizedCopy private var copy
    let onUpdateDraft: (String) -> Void
    let onSave: () -> Void
    let onCancel: () -> Void
    @FocusState private var isFocused: Bool

    // Styled like the popup's search field.
    var body: some View {
        HStack(spacing: theme.spacing.control6) {
            if state.isEditable {
                // The system placeholder draws almost invisibly in the
                // non-key popup panel, so it is drawn here instead.
                TextField("", text: Binding(
                    get: { state.draftText },
                    set: onUpdateDraft
                ))
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.palette.textPrimary)
                .focused($isFocused)
                .onSubmit(save)
                .overlay(alignment: .leading) {
                    if state.draftText.isEmpty {
                        Text(state.hasPersistedNote ? copy.text(.popupUpdateNote) : copy.text(.popupAddNote))
                            .font(theme.typography.chip)
                            .foregroundStyle(theme.palette.textTertiary)
                            .lineLimit(1)
                            .allowsHitTesting(false)
                    }
                }
                .onAppear {
                    isFocused = true
                    // Focusing selects the whole note; put the caret at the
                    // end so the first key press does not replace it.
                    DispatchQueue.main.async {
                        guard let editor = NSApp.keyWindow?.firstResponder as? NSTextView else { return }
                        editor.selectedRange = NSRange(location: (editor.string as NSString).length, length: 0)
                    }
                }
            } else {
                Text(copy.text(.popupNotesLocked))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.palette.textTertiary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, theme.spacing.control10)
        .frame(maxWidth: .infinity, minHeight: 26, maxHeight: 26)
        .background(theme.palette.subpanel.opacity(theme.headerControlFillOpacity))
        .clipShape(Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(theme.palette.border, lineWidth: theme.border.hairline)
        )
    }

    private func save() {
        guard state.isEditable, state.isDirty else { return }
        onSave()
        onCancel()
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

// A card shows a few lines of a clip. Handing a multi-megabyte string to `Text`
// makes CoreText lay out all of it, which costs hundreds of megabytes and
// seconds of CPU per card.
private let sbCardDisplayCharacterLimit = 1_000

private func sbCardDisplayText(_ text: String) -> String {
    text.utf8.count <= sbCardDisplayCharacterLimit
        ? text
        : String(text.prefix(sbCardDisplayCharacterLimit))
}
