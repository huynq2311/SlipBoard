import AppKit
import SwiftUI

private enum SBClipThumbnailCache {
    static let shared = NSCache<NSString, NSImage>()
    static let assetStore = ClipboardImageAssetStore()
}

struct SBClipCardShell: View {
    let clip: ClipPreviewSummary
    let theme: SBTheme
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

    var body: some View {
        GeometryReader { proxy in
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .frame(height: 30)
                    .background(theme.accentBackground(for: badgeTone))

                bodyContent
                    .padding(10)
                    .frame(
                        maxWidth: .infinity,
                        minHeight: 0,
                        maxHeight: max(0, proxy.size.height - 30),
                        alignment: .topLeading
                    )
                    .clipped()
            }
        }
        .frame(width: 248, height: height, alignment: .topLeading)
        .sbSurface(.card, theme: theme, emphasized: isSelected)
        .overlay(alignment: .top) {
            if isSelected {
                RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                    .fill(theme.palette.accentPrimary)
                    .frame(height: 2)
                    .padding(.horizontal, 0.5)
            }
        }
        .contentShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
        .onTapGesture {
            onSelect()
        }
        .onTapGesture(count: 2) {
            onSelect()
            onPrimaryAction()
        }
        .simultaneousGesture(
            TapGesture(count: 1)
                .modifiers(.control)
                .onEnded(onOpenContextMenu)
        )
        .contextMenu {
            Button("Paste") {
                onSelect()
                onPerformContextAction("paste")
            }
            Button("Paste As…") {
                onSelect()
                onPerformContextAction("paste-as")
            }
            Divider()
            Button("Copy Again") {
                onSelect()
                onPerformContextAction("copy")
            }
            Button(clip.isPinned ? "Unpin Item" : "Pin Item") {
                onSelect()
                onPerformContextAction("pin")
            }
            Button("Add Note…") {
                onSelect()
                onPerformContextAction("add-note")
            }
            Divider()
            Button("Delete", role: .destructive) {
                onSelect()
                onPerformContextAction("delete")
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: theme.spacing.control6) {
            HStack(spacing: 6) {
                Text(clipKindLabel)
                    .font(theme.typography.chip)
                    .foregroundStyle(theme.palette.textPrimary)
                    .lineLimit(1)

                Text(clip.createdLabel)
                    .font(theme.typography.monoMeta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineLimit(1)
            }

            Spacer(minLength: theme.spacing.control4)

            Text(clip.sourceApp.displayName)
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)

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
            .accessibilityLabel("Clip from \(clip.sourceApp.displayName)")

            if clip.isPinned {
                Image(systemName: "pin.fill")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(theme.accent(for: .danger))
            }
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            if isPreviewRedacted {
                redactedBody
            } else {
                switch clip.previewStyle {
                case .text:
                    textBody(font: theme.typography.rowPrimary, color: theme.palette.textPrimary)
                case let .code(languageHint):
                    VStack(alignment: .leading, spacing: theme.spacing.control6) {
                        if let languageHint, languageHint.isEmpty == false {
                            Text(languageHint.uppercased())
                                .font(theme.typography.uppercaseLabel)
                                .foregroundStyle(theme.palette.textTertiary)
                        }
                        textBody(font: theme.typography.monoMeta, color: theme.accent(for: .info))
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
                case let .file(fileExtension):
                    HStack(spacing: theme.spacing.control8) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundStyle(theme.accent(for: .warning))

                        VStack(alignment: .leading, spacing: 2) {
                            Text(clip.titleText)
                                .font(theme.typography.meta)
                                .foregroundStyle(theme.palette.textPrimary)
                                .lineLimit(1)

                            Text(fileExtension?.uppercased() ?? clip.metadataText)
                                .font(theme.typography.uppercaseLabel)
                                .foregroundStyle(theme.palette.textTertiary)
                                .lineLimit(1)
                        }
                    }

                    if let bodyText = clip.bodyText, bodyText.isEmpty == false {
                        Text(bodyText)
                            .font(theme.typography.meta)
                            .foregroundStyle(theme.palette.textSecondary)
                            .lineLimit(min(bodyLineLimit, 4))
                    }
                case .url:
                    textBody(font: theme.typography.meta, color: theme.accent(for: .primary))
                case let .color(swatches):
                    HStack(spacing: 3) {
                        ForEach(swatches, id: \.self) { swatch in
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(Color(sbHex: swatch) ?? theme.palette.raised)
                                .frame(width: 14, height: 14)
                        }
                    }
                    textBody(font: theme.typography.monoMeta, color: theme.palette.textSecondary)
                case .richText:
                    textBody(font: theme.typography.rowSecondary, color: theme.palette.textPrimary)
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

    private var thumbnailImage: NSImage? {
        guard clip.kind == .image else { return nil }

        let cacheKey = clip.id as NSString
        if let cached = SBClipThumbnailCache.shared.object(forKey: cacheKey) {
            return cached
        }

        guard let data = SBClipThumbnailCache.assetStore.data(for: clip.id),
              let decoded = NSImage(data: data) else { return nil }
        SBClipThumbnailCache.shared.setObject(decoded, forKey: cacheKey)
        return decoded
    }

    private var badgeTone: SBAccentTone {
        switch clip.kind {
        case .text, .richText:
            return .neutral
        case .code:
            return .info
        case .image:
            return .success
        case .file:
            return .warning
        case .url:
            return .primary
        case .color:
            return .danger
        }
    }

    private func textBody(font: Font, color: Color) -> some View {
        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            Text(clip.titleText)
                .font(font)
                .foregroundStyle(color)
                .lineLimit(clip.kind == .url ? 2 : bodyLineLimit)

            if let bodyText = clip.bodyText, bodyText.isEmpty == false {
                Text(bodyText)
                    .font(theme.typography.meta)
                    .foregroundStyle(theme.palette.textSecondary)
                    .lineLimit(max(2, bodyLineLimit - 2))
            }
        }
    }

    // Rough line-count the taller card's preview area can hold, so text/code
    // previews actually use the extra height instead of leaving it blank.
    private var bodyLineLimit: Int {
        let bodyAreaHeight = height - 30 - 20
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
            return "Text"
        case .code:
            return "Code"
        case .image:
            return "Image"
        case .file:
            return "File"
        case .url:
            return "URL"
        case .color:
            return "Color"
        case .richText:
            return "Rich Text"
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
                    title: securitySnapshot?.lockState.revealsProtectedContent == false ? "LOCKED" : "PRIVATE",
                    theme: theme,
                    tone: redactionTone
                )

                Text(securitySnapshot?.lockState.revealsProtectedContent == false ? "Unlock required" : "Preview hidden")
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
            return "Protected previews stay hidden in this shell."
        }

        if securitySnapshot.lockState.revealsProtectedContent == false {
            return "SlipBoard is locked, so clip previews and note bodies stay hidden until unlock succeeds."
        }

        return "Privacy mode is redacting this preview on the existing shell surface."
    }
}

struct SBHorizontalClipRail: View {
    let clips: [ClipPreviewSummary]
    let theme: SBTheme
    let emptyTitle: String
    let emptyDetail: String
    var cardHeight: CGFloat = 128
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
                .padding(.horizontal, theme.spacing.popupPadding)
                .padding(.top, 5)
                .padding(.bottom, 2)
            }
            .onAppear {
                scrollToSelectionIfNeeded(using: proxy, animated: false)
            }
            .onChange(of: selectedClipID) { _, _ in
                scrollToSelectionIfNeeded(using: proxy, animated: true)
            }
        }
    }

    private func scrollToSelectionIfNeeded(using proxy: ScrollViewProxy, animated: Bool) {
        guard let selectedClipID,
              clips.contains(where: { $0.id == selectedClipID }),
              visibleClipIDs.contains(selectedClipID) == false else {
            return
        }

        if animated {
            withAnimation(.easeOut(duration: 0.16)) {
                proxy.scrollTo(selectedClipID, anchor: .center)
            }
        } else {
            proxy.scrollTo(selectedClipID, anchor: .center)
        }
    }
}

private struct ClipNoteEditorInline: View {
    let state: ClipNoteEditorState
    let theme: SBTheme
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
                    state.hasPersistedNote ? "Update note" : "Add note",
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
                    Text("Notes stay hidden while search is locked.")
                        .font(theme.typography.keyboard)
                        .foregroundStyle(theme.palette.textTertiary)
                        .lineLimit(2)
                } else {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(.plain)
                        .font(theme.typography.keyboard)
                        .foregroundStyle(theme.palette.textSecondary)

                    Spacer(minLength: theme.spacing.control6)

                    Button("Save", action: onSave)
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
