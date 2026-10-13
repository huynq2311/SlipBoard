import SwiftUI

struct SBOverlayMenuAction: Identifiable, Hashable {
    let id: String
    var title: String
    var subtitle: String?
    var symbolName: String
    var shortcut: String?
    var tone: SBAccentTone
    var isEnabled: Bool

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        symbolName: String,
        shortcut: String? = nil,
        tone: SBAccentTone = .neutral,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.symbolName = symbolName
        self.shortcut = shortcut
        self.tone = tone
        self.isEnabled = isEnabled
    }
}

struct SBSecurityStatusCallout: View {
    let theme: SBTheme
    let title: String
    let detailText: String
    var symbolName: String = "lock"
    var tone: SBAccentTone = .neutral
    var badgeText: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacing.control8) {
            HStack(alignment: .top, spacing: theme.spacing.control8) {
                Image(systemName: symbolName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(toneColor)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .center, spacing: theme.spacing.control8) {
                        Text(title)
                            .font(theme.typography.rowPrimary)
                            .foregroundStyle(theme.palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: theme.spacing.control8)

                        if let badgeText, badgeText.isEmpty == false {
                            SBCountBadge(text: badgeText, theme: theme, tone: tone, compact: true)
                        }
                    }

                    Text(detailText)
                        .font(theme.typography.rowSecondary)
                        .foregroundStyle(theme.palette.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(theme.spacing.control12)
        .background(theme.accentBackground(for: tone))
        .clipShape(RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: theme.radius.panel, style: .continuous)
                .stroke(toneColor.opacity(theme.mode == .dark ? 0.45 : 0.35), lineWidth: theme.border.hairline)
        )
    }

    private var toneColor: Color {
        tone == .neutral ? theme.palette.textSecondary : theme.accent(for: tone)
    }
}

struct SBOverlayMenuShell<Header: View>: View {
    let theme: SBTheme
    let width: CGFloat
    let highlightedActionID: String?
    let actions: [SBOverlayMenuAction]
    var onSelectAction: (String) -> Void = { _ in }
    var onHoverAction: (String?) -> Void = { _ in }
    @ViewBuilder var header: Header

    init(
        theme: SBTheme,
        width: CGFloat,
        highlightedActionID: String? = nil,
        actions: [SBOverlayMenuAction],
        onSelectAction: @escaping (String) -> Void = { _ in },
        onHoverAction: @escaping (String?) -> Void = { _ in },
        @ViewBuilder header: () -> Header
    ) {
        self.theme = theme
        self.width = width
        self.highlightedActionID = highlightedActionID
        self.actions = actions
        self.onSelectAction = onSelectAction
        self.onHoverAction = onHoverAction
        self.header = header()
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: 0) {
                ForEach(actions) { action in
                    Button {
                        guard action.isEnabled else { return }
                        onSelectAction(action.id)
                    } label: {
                        SBListRow(
                            title: action.title,
                            detailText: action.subtitle,
                            accessoryText: action.shortcut,
                            badgeText: nil,
                            symbolName: action.symbolName,
                            theme: theme,
                            tone: action.tone,
                            isHighlighted: highlightedActionID == action.id
                        )
                        .opacity(action.isEnabled ? 1 : 0.46)
                    }
                    .buttonStyle(.plain)
                    .disabled(action.isEnabled == false)
                    .onHover { isHovering in
                        onHoverAction(isHovering ? action.id : nil)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(width: width, alignment: .topLeading)
        .sbSurface(.overlay, theme: theme)
    }
}

struct SBContextMenuShell: View {
    private static let pasteAsSupportedKinds: Set<ClipKind> = [.text, .richText, .code, .url]

    let theme: SBTheme
    @SBLocalizedCopy private var copy
    var highlightedActionID: String? = "paste"
    var isPinned: Bool = false
    var clipKind: ClipKind? = nil
    var onSelectAction: (String) -> Void = { _ in }
    var onHoverAction: (String?) -> Void = { _ in }

    private var actions: [SBOverlayMenuAction] {
        var actions = [
            SBOverlayMenuAction(id: "paste", title: copy.text(.actionPaste), symbolName: "doc.on.clipboard", shortcut: "↩")
        ]

        if let clipKind, Self.pasteAsSupportedKinds.contains(clipKind) {
            actions.append(
                SBOverlayMenuAction(id: "paste-as", title: copy.text(.actionPasteAs), subtitle: copy.text(.overlayOpenTransformPreview), symbolName: "arrowshape.turn.up.right", shortcut: "⌘↩")
            )
        }

        actions.append(contentsOf: [
            SBOverlayMenuAction(id: "copy", title: copy.text(.actionCopy), symbolName: "square.on.square", shortcut: "⌘C"),
            SBOverlayMenuAction(id: "pin", title: isPinned ? copy.text(.actionUnpin) : copy.text(.actionPin), symbolName: isPinned ? "pin.slash" : "pin", shortcut: "⌘P"),
            SBOverlayMenuAction(id: "add-note", title: copy.text(.popupAddNote), symbolName: "note.text"),
            SBOverlayMenuAction(id: "delete", title: copy.text(.actionDelete), symbolName: "trash", shortcut: "⌫", tone: .danger)
        ])

        return actions
    }

    var body: some View {
        SBOverlayMenuShell(
            theme: theme,
            width: 220,
            highlightedActionID: highlightedActionID,
            actions: actions,
            onSelectAction: onSelectAction,
            onHoverAction: onHoverAction
        ) {
            EmptyView()
        }
    }
}

struct SBPasteTransformMenuShell: View {
    private static let previewCharacterLimit = 600

    let theme: SBTheme
    @SBLocalizedCopy private var copy
    var highlightedActionID: String? = PasteActionID.plainText.id
    var previewState: PasteActionPreviewState = .empty
    var supportedActionIDs: Set<PasteActionID> = Set(PasteActionID.transformMenuOrder)
    var isExecuting: Bool = false
    var onHighlightAction: (PasteActionID) -> Void = { _ in }
    var onSelectAction: (PasteActionID) -> Void = { _ in }
    var onConfirm: () -> Void = {}
    var onCancel: () -> Void = {}

    private var actions: [SBOverlayMenuAction] {
        PasteActionID.transformMenuOrder.map { actionID in
            SBOverlayMenuAction(
                id: actionID.id,
                title: title(for: actionID),
                subtitle: subtitle(for: actionID),
                symbolName: symbolName(for: actionID),
                shortcut: shortcut(for: actionID),
                tone: highlightedActionID == actionID.id ? .primary : .neutral,
                isEnabled: supportedActionIDs.contains(actionID)
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            SBOverlayMenuShell(
                theme: theme,
                width: 260,
                highlightedActionID: highlightedActionID,
                actions: actions,
                // Hovering must not change the choice: the pointer crosses other
                // rows on its way from the chosen one to the Paste button.
                onSelectAction: { actionID in
                    guard let action = PasteActionID(rawValue: actionID) else { return }
                    onSelectAction(action)
                }
            ) {
                VStack(alignment: .leading, spacing: theme.spacing.control8) {
                    Text(copy.text(.actionPasteAs))
                        .font(theme.typography.uppercaseLabel)
                        .foregroundStyle(theme.palette.textTertiary)

                    previewBox
                }
                .padding(.horizontal, theme.spacing.control12)
                .padding(.top, theme.spacing.control10)
                .padding(.bottom, theme.spacing.control8)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(theme.palette.border)
                        .frame(height: theme.border.hairline)
                }
            }

            HStack {
                Button(action: onCancel) {
                    HStack(spacing: theme.spacing.control4) {
                        Image(systemName: "keyboard")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(theme.palette.textTertiary)

                        Text(copy.text(.overlayEscapeCancel))
                            .font(theme.typography.meta)
                            .foregroundStyle(theme.palette.textTertiary)
                    }
                }
                .buttonStyle(.plain)

                Spacer()

                Button(action: onConfirm) {
                    HStack(spacing: theme.spacing.control6) {
                        if isExecuting {
                            ProgressView()
                                .controlSize(.small)
                                .tint(.white)
                        }

                        Text(isExecuting ? copy.text(.popupExecutingPaste) : copy.text(.actionPaste))
                            .font(theme.typography.chip)
                            .foregroundStyle(Color.white)
                    }
                    .padding(.horizontal, theme.spacing.control10)
                    .padding(.vertical, theme.spacing.control6)
                    .background(theme.palette.accentPrimary)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isExecuting)
                .opacity(confirmEnabled ? 1 : 0.5)
            }
            .padding(.horizontal, theme.spacing.control12)
            .padding(.vertical, theme.spacing.control8)
            .background(theme.palette.canvas)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(theme.palette.border)
                    .frame(height: theme.border.hairline)
            }
        }
        .frame(width: 260, alignment: .topLeading)
        .sbSurface(.overlay, theme: theme)
    }

    @ViewBuilder
    private var previewBox: some View {
        let previewText = resolvedPreviewText
        let usesMono = previewState.kind == .text

        VStack(alignment: .leading, spacing: theme.spacing.control6) {
            Text(copy.text(.overlayPreviewHeading))
                .font(theme.typography.meta)
                .foregroundStyle(theme.palette.textSecondary)
                .lineLimit(1)

            Text(previewText)
                .font(usesMono ? theme.typography.monoMeta : theme.typography.meta)
                .foregroundStyle(previewColor)
                .lineLimit(4)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, minHeight: 64, alignment: .topLeading)
                .padding(theme.spacing.control8)
                .background(theme.palette.subpanel)
                .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .stroke(theme.palette.border, lineWidth: theme.border.hairline)
                )

            if previewState.statusText?.isEmpty == false {
                Text(localizedStatusText)
                    .font(theme.typography.meta)
                    .foregroundStyle(previewState.kind == .unsupported ? theme.accent(for: .warning) : theme.palette.textTertiary)
            }
        }
    }

    private var confirmEnabled: Bool {
        guard let highlightedActionID, let actionID = PasteActionID(rawValue: highlightedActionID) else {
            return false
        }

        return supportedActionIDs.contains(actionID) && isExecuting == false
    }

    /// The transformer's status lines are English; this picks the localized
    /// line for the highlighted action instead.
    private var localizedStatusText: String {
        guard previewState.kind != .unsupported else {
            return copy.text(.overlayStatusUnsupported)
        }
        let actionID = highlightedActionID.flatMap(PasteActionID.init(rawValue:))?.resolvedTransformID ?? .original
        switch actionID {
        case .original, .pasteAndClose, .pasteAndKeepOpen:
            return copy.text(.overlayStatusOriginal)
        case .plainText:
            return copy.text(.overlayStatusPlainText)
        case .markdown:
            return copy.text(.overlayStatusMarkdown)
        case .stripUnicodeAccent:
            return copy.text(.overlayStatusStripUnicode)
        case .uppercase:
            return copy.text(.overlayStatusUppercase)
        case .lowercase:
            return copy.text(.overlayStatusLowercase)
        }
    }

    private var resolvedPreviewText: String {
        let previewText: String
        if previewState.previewText.isEmpty == false {
            previewText = previewState.previewText
        } else if previewState.kind == .empty {
            previewText = copy.text(.overlayEmptyResult)
        } else {
            previewText = copy.text(.popupTransformUnavailable)
        }

        guard previewText.count > Self.previewCharacterLimit else {
            return previewText
        }

        return String(previewText.prefix(Self.previewCharacterLimit)) + "…"
    }

    private var previewColor: Color {
        switch previewState.kind {
        case .text:
            return theme.palette.textSecondary
        case .empty:
            return theme.palette.textTertiary
        case .unsupported:
            return theme.accent(for: .warning)
        }
    }

    private func title(for actionID: PasteActionID) -> String {
        switch actionID {
        case .plainText:
            return copy.text(.overlayPlainText)
        case .markdown:
            return copy.text(.overlayMarkdownDescription)
        case .stripUnicodeAccent:
            return copy.text(.overlayStripUnicodeDescription)
        case .uppercase:
            return copy.text(.overlayUppercaseDescription)
        case .lowercase:
            return copy.text(.overlayLowercaseDescription)
        case .original, .pasteAndClose, .pasteAndKeepOpen:
            return actionID.rawValue
        }
    }

    private func subtitle(for actionID: PasteActionID) -> String {
        switch actionID {
        case .plainText:
            return copy.text(.overlayRemoveRichFormatting)
        case .markdown:
            return copy.text(.overlayConvertMarkdown)
        case .stripUnicodeAccent:
            return copy.text(.overlayStripUnicode)
        case .uppercase:
            return copy.text(.overlayUppercase)
        case .lowercase:
            return copy.text(.overlayLowercase)
        case .original, .pasteAndClose, .pasteAndKeepOpen:
            return ""
        }
    }

    private func symbolName(for actionID: PasteActionID) -> String {
        switch actionID {
        case .plainText:
            return "textformat"
        case .markdown:
            return "chevron.left.forwardslash.chevron.right"
        case .stripUnicodeAccent:
            return "eraser"
        case .uppercase:
            return "textformat.size.larger"
        case .lowercase:
            return "textformat.size.smaller"
        case .original, .pasteAndClose, .pasteAndKeepOpen:
            return "doc.on.clipboard"
        }
    }

    private func shortcut(for actionID: PasteActionID) -> String {
        switch actionID {
        case .plainText:
            return "↩"
        case .markdown:
            return "⌘1"
        case .stripUnicodeAccent:
            return "⌘2"
        case .uppercase:
            return "⌘3"
        case .lowercase:
            return "⌘4"
        case .original, .pasteAndClose, .pasteAndKeepOpen:
            return ""
        }
    }
}
