import AppKit
import SwiftUI
import Combine

final class PopupPanelController {
    private var panel: NSPanel?
    private var hostingController: NSHostingController<PopupPanelRoot>?
    private var viewModel: PopupPanelViewModel?

    func present(using preset: PopupShellPreset = .compactDemo) {
        let model = PopupPanelViewModel(fixture: PopupShellFixtures.fixture(named: preset))
        present(viewModel: model)
    }

    func present(viewModel: PopupPanelViewModel) {
        let panel = ensurePanel(viewModel: viewModel)
        self.viewModel = viewModel
        hostingController?.rootView = PopupPanelRoot(viewModel: viewModel)
        panel.makeKeyAndOrderFront(nil)
        panel.center()
    }

    func closePanel() {
        panel?.orderOut(nil)
    }

    private func ensurePanel(viewModel: PopupPanelViewModel) -> NSPanel {
        if let panel {
            return panel
        }

        let rootView = PopupPanelRoot(viewModel: viewModel)
        let hostingController = NSHostingController(rootView: rootView)
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 980, height: 620),
            styleMask: [.titled, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.standardWindowButton(.closeButton)?.isHidden = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true
        panel.backgroundColor = .clear
        panel.isMovableByWindowBackground = true
        panel.contentViewController = hostingController

        self.panel = panel
        self.hostingController = hostingController
        return panel
    }
}

struct PopupPanelRoot: View {
    @ObservedObject var viewModel: PopupPanelViewModel

    var body: some View {
        PopupGridView(viewModel: viewModel)
            .background(
                LinearGradient(
                    colors: [
                        Color(red: 0.97, green: 0.95, blue: 0.92),
                        Color(red: 0.92, green: 0.89, blue: 0.84)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.16), radius: 24, y: 12)
            .padding(14)
    }
}

final class PopupPanelViewModel: ObservableObject, PopupShellRouting {
    @Published private(set) var title: String
    @Published private(set) var searchPlaceholder: String
    @Published private(set) var availabilityLabel: String
    @Published private(set) var captureSummary: String
    @Published private(set) var keyboardHint: String
    @Published private(set) var totalCount: Int
    @Published private(set) var filterOptions: [ClipboardFilter]

    @Published var searchQuery: String
    @Published var selectedFilter: ClipboardFilter
    @Published var selectedItemID: ClipboardItemID?
    @Published var contextMenuItemID: ClipboardItemID?
    @Published var activePasteMenuItemID: ClipboardItemID?
    @Published var editingNoteItemID: ClipboardItemID?
    @Published var selectedTransformOptionID: PasteTransformOptionID
    @Published var noteDraft: String

    private var items: [PopupCardRecord]
    private let initialEmptyMessage: String?

    init(fixture: PopupShellFixture) {
        let snapshot = fixture.snapshot
        title = snapshot.title
        searchPlaceholder = snapshot.searchField.placeholder
        availabilityLabel = snapshot.statusBar.availabilityLabel
        captureSummary = snapshot.statusBar.captureSummary
        keyboardHint = snapshot.statusBar.keyboardHint
        totalCount = (snapshot.pinnedRail?.items.count ?? 0) + snapshot.recentRail.items.count
        filterOptions = snapshot.filterPills.map(\.id)
        searchQuery = snapshot.searchField.query
        selectedFilter = snapshot.filterPills.first(where: \.isSelected)?.id ?? .all
        selectedItemID = snapshot.activePasteMenu?.itemID
            ?? snapshot.activeContextMenu?.itemID
            ?? snapshot.pinnedRail?.items.first(where: \.isSelected)?.itemID
            ?? snapshot.recentRail.items.first(where: \.isSelected)?.itemID
        contextMenuItemID = snapshot.activeContextMenu?.itemID
        activePasteMenuItemID = snapshot.activePasteMenu?.itemID
        editingNoteItemID = snapshot.pinnedRail?.items.first(where: \.isEditingNote)?.itemID
            ?? snapshot.recentRail.items.first(where: \.isEditingNote)?.itemID
        selectedTransformOptionID = snapshot.activePasteMenu?.options.first(where: \.isSelected)?.id ?? .pasteAsPlainText
        noteDraft = PopupPanelViewModel.initialNoteDraft(from: snapshot)
        items = PopupPanelViewModel.buildRecords(from: snapshot)
        initialEmptyMessage = snapshot.recentRail.emptyMessage
    }

    var snapshot: PopupPanelSnapshot {
        let visibleItems = filteredItems
        let pinnedItems = visibleItems.filter(\.isPinned)
        let recentItems = visibleItems.filter { !$0.isPinned }

        return PopupPanelSnapshot(
            title: title,
            searchField: PopupSearchFieldState(
                query: searchQuery,
                placeholder: searchPlaceholder,
                isActive: true
            ),
            filterPills: filterOptions.map { filter in
                PopupFilterPillState(
                    id: filter,
                    title: popupFilterTitle(filter),
                    countLabel: popupFilterCountLabel(for: filter),
                    isSelected: filter == selectedFilter
                )
            },
            pinnedRail: pinnedItems.isEmpty ? nil : PopupRailSnapshot(
                id: .pinned,
                title: "Pinned",
                items: pinnedItems.map { $0.snapshot(selectedItemID: selectedItemID, editingNoteItemID: editingNoteItemID) },
                emptyMessage: nil
            ),
            recentRail: PopupRailSnapshot(
                id: .recent,
                title: "Recent",
                items: recentItems.map { $0.snapshot(selectedItemID: selectedItemID, editingNoteItemID: editingNoteItemID) },
                emptyMessage: recentItems.isEmpty ? emptyStateMessage : nil
            ),
            activeContextMenu: contextMenuItemID.flatMap(contextMenuSnapshot(for:)),
            activePasteMenu: activePasteMenuItemID.flatMap(pasteMenuSnapshot(for:)),
            statusBar: PopupStatusBarSnapshot(
                availabilityLabel: availabilityLabel,
                filterSummary: filterSummary,
                captureSummary: captureSummary,
                countSummary: "\(visibleItems.count) of \(max(totalCount, items.count)) items visible",
                keyboardHint: keyboardHint
            )
        )
    }

    func updateSearchQuery(_ query: String) {
        searchQuery = query
        dismissContextMenu()
    }

    func changeFilter(to filter: ClipboardFilter) {
        selectedFilter = filter
        dismissContextMenu()
    }

    func selectItem(id: ClipboardItemID?) {
        selectedItemID = id
        if activePasteMenuItemID != id {
            activePasteMenuItemID = nil
        }
    }

    func openPasteMenu(for itemID: ClipboardItemID) {
        selectedItemID = itemID
        activePasteMenuItemID = itemID
        contextMenuItemID = nil
    }

    func dismissPasteMenu() {
        activePasteMenuItemID = nil
    }

    func togglePin(for itemID: ClipboardItemID) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        items[index].isPinned.toggle()
        selectedItemID = itemID
    }

    func updateNote(for itemID: ClipboardItemID, note: String?) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        items[index].noteSummary = trimmedNote?.isEmpty == true ? nil : trimmedNote
        editingNoteItemID = nil
        noteDraft = ""
        selectedItemID = itemID
    }

    func openContextMenu(for itemID: ClipboardItemID) {
        selectedItemID = itemID
        contextMenuItemID = itemID
    }

    func dismissContextMenu() {
        contextMenuItemID = nil
    }

    func selectPasteTransformOption(_ optionID: PasteTransformOptionID, for itemID: ClipboardItemID) {
        selectedItemID = itemID
        activePasteMenuItemID = itemID
        selectedTransformOptionID = optionID
    }

    func beginInlineNoteEdit(for itemID: ClipboardItemID) {
        selectedItemID = itemID
        contextMenuItemID = nil
        activePasteMenuItemID = nil
        editingNoteItemID = itemID
        noteDraft = items.first(where: { $0.id == itemID })?.noteSummary ?? ""
    }

    func cancelInlineNoteEdit(for itemID: ClipboardItemID) {
        if editingNoteItemID == itemID {
            editingNoteItemID = nil
            noteDraft = ""
        }
    }

    func saveInlineNote(for itemID: ClipboardItemID) {
        updateNote(for: itemID, note: noteDraft)
    }

    func updateInlineNoteDraft(_ draft: String) {
        noteDraft = draft
    }

    func contextMenuSnapshot(for itemID: ClipboardItemID) -> ClipboardContextMenuSnapshot? {
        guard let item = items.first(where: { $0.id == itemID }) else {
            return nil
        }

        return ClipboardContextMenuSnapshot(
            itemID: itemID,
            items: [
                ClipboardContextMenuItem(
                    id: .paste,
                    title: item.pasteLabel,
                    symbolName: "arrowshape.turn.up.forward",
                    role: .primary,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: .pasteTransforms,
                    title: "Paste with Transform",
                    symbolName: "wand.and.stars",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: item.isPinned ? .unpin : .pin,
                    title: item.isPinned ? "Unpin" : "Pin",
                    symbolName: item.isPinned ? "pin.slash" : "pin",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: item.noteSummary == nil ? .addNote : .editNote,
                    title: item.noteSummary == nil ? "Add Note" : "Edit Note",
                    symbolName: "note.text",
                    role: .standard,
                    isEnabled: true
                ),
                ClipboardContextMenuItem(
                    id: .deletePlaceholder,
                    title: "Delete from Mock List",
                    symbolName: "trash",
                    role: .destructive,
                    isEnabled: true
                )
            ]
        )
    }

    func performPrimaryPaste(for itemID: ClipboardItemID) {
        selectedItemID = itemID
        dismissPasteMenu()
        dismissContextMenu()
    }

    private var filteredItems: [PopupCardRecord] {
        items.filter { item in
            filterMatches(item) && queryMatches(item)
        }
    }

    private func filterMatches(_ item: PopupCardRecord) -> Bool {
        selectedFilter == .all || selectedFilter == item.filter
    }

    private func queryMatches(_ item: PopupCardRecord) -> Bool {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return true
        }

        let loweredQuery = trimmedQuery.lowercased()
        let haystacks = [
            item.sourceLabel,
            item.typeLabel,
            item.noteSummary ?? "",
            item.previewSearchText
        ]

        return haystacks.joined(separator: " ").lowercased().contains(loweredQuery)
    }

    private func popupFilterCountLabel(for filter: ClipboardFilter) -> String? {
        let count = filter == .all
            ? items.count
            : items.filter { $0.filter == filter }.count

        return count == 0 ? nil : "\(count)"
    }

    private var filterSummary: String {
        let filterLabel = "Filter: \(popupFilterTitle(selectedFilter))"
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedQuery.isEmpty ? filterLabel : "\(filterLabel) | Search: \(trimmedQuery)"
    }

    private var emptyStateMessage: String {
        let trimmedQuery = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedQuery.isEmpty {
            return "No \(popupFilterTitle(selectedFilter).lowercased()) clips match \"\(trimmedQuery)\"."
        }

        if selectedFilter != .all {
            return "No \(popupFilterTitle(selectedFilter).lowercased()) clips are available right now."
        }

        return initialEmptyMessage ?? "Nothing has been captured yet."
    }

    private func pasteMenuSnapshot(for itemID: ClipboardItemID) -> PasteTransformMenuSnapshot? {
        guard items.contains(where: { $0.id == itemID }) else {
            return nil
        }

        return PasteTransformMenuSnapshot(
            itemID: itemID,
            previewText: items.first(where: { $0.id == itemID })?.previewSearchText ?? "",
            options: [
                PasteTransformOptionState(
                    id: .pasteAsPlainText,
                    title: "Paste as Plain Text",
                    detail: "Strip formatting and keep line breaks intact.",
                    isSelected: selectedTransformOptionID == .pasteAsPlainText
                ),
                PasteTransformOptionState(
                    id: .cleanRichText,
                    title: "Clean Rich Text",
                    detail: "Normalize smart quotes, dashes, and lists.",
                    isSelected: selectedTransformOptionID == .cleanRichText
                ),
                PasteTransformOptionState(
                    id: .preserveCodeFormatting,
                    title: "Preserve Code Formatting",
                    detail: "Keep indentation and monospaced whitespace.",
                    isSelected: selectedTransformOptionID == .preserveCodeFormatting
                ),
                PasteTransformOptionState(
                    id: .trimWhitespace,
                    title: "Trim Surrounding Whitespace",
                    detail: "Remove leading and trailing whitespace before paste.",
                    isSelected: selectedTransformOptionID == .trimWhitespace
                )
            ],
            primaryActionLabel: "Paste and Close"
        )
    }

    private static func buildRecords(from snapshot: PopupPanelSnapshot) -> [PopupCardRecord] {
        var records: [PopupCardRecord] = []
        var seenIDs = Set<ClipboardItemID>()
        var order = 0

        for card in snapshot.pinnedRail?.items ?? [] {
            seenIDs.insert(card.itemID)
            records.append(PopupCardRecord(snapshot: card, order: order))
            order += 1
        }

        for card in snapshot.recentRail.items where !seenIDs.contains(card.itemID) {
            records.append(PopupCardRecord(snapshot: card, order: order))
            order += 1
        }

        return records
    }

    private static func initialNoteDraft(from snapshot: PopupPanelSnapshot) -> String {
        let editingCard = (snapshot.pinnedRail?.items ?? []) + snapshot.recentRail.items
        return editingCard.first(where: \.isEditingNote)?.noteSummary ?? ""
    }
}

struct PopupCardRecord: Identifiable, Equatable {
    let id: ClipboardItemID
    let sourceLabel: String
    let typeLabel: String
    let filter: ClipboardFilter
    let preview: ClipboardPreview
    let captureTimeLabel: String
    let pasteLabel: String
    let order: Int
    var isPinned: Bool
    var noteSummary: String?

    init(snapshot: PopupCardSnapshot, order: Int) {
        id = snapshot.itemID
        sourceLabel = snapshot.sourceLabel
        typeLabel = snapshot.typeLabel
        filter = popupFilter(for: snapshot.preview)
        preview = snapshot.preview
        captureTimeLabel = snapshot.captureTimeLabel
        pasteLabel = snapshot.pasteLabel
        self.order = order
        isPinned = snapshot.isPinned
        noteSummary = snapshot.noteSummary
    }

    func snapshot(selectedItemID: ClipboardItemID?, editingNoteItemID: ClipboardItemID?) -> PopupCardSnapshot {
        PopupCardSnapshot(
            itemID: id,
            sourceLabel: sourceLabel,
            typeLabel: typeLabel,
            isPinned: isPinned,
            noteSummary: noteSummary,
            preview: preview,
            captureTimeLabel: captureTimeLabel,
            pasteLabel: pasteLabel,
            isSelected: id == selectedItemID,
            isEditingNote: id == editingNoteItemID
        )
    }

    var previewSearchText: String {
        switch preview {
        case let .text(value):
            return value
        case let .code(language, snippet):
            return [language ?? "", snippet].joined(separator: " ")
        case let .image(description):
            return description
        case let .file(name, detail):
            return "\(name) \(detail)"
        case let .url(value):
            return value
        case let .color(hex):
            return hex
        }
    }
}

private func popupFilter(for preview: ClipboardPreview) -> ClipboardFilter {
    switch preview {
    case .text:
        return .text
    case .code:
        return .code
    case .image:
        return .image
    case .file:
        return .file
    case .url:
        return .url
    case .color:
        return .color
    }
}

func popupFilterTitle(_ filter: ClipboardFilter) -> String {
    switch filter {
    case .all:
        return "All"
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
    }
}

struct PopupPanelRoot_Previews: PreviewProvider {
    static var previews: some View {
        PopupPanelRoot(viewModel: PopupPanelViewModel(fixture: PopupShellFixtures.compactDemo))
            .frame(width: 980, height: 620)
            .previewDisplayName("Popup Shell")
    }
}
