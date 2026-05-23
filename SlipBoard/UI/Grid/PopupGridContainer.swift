import SwiftUI
import AppKit
import Combine

public struct PopupGridContainer: View {
    @ObservedObject public var engine: MockHistoryEngine
    @ObservedObject public var settings: MockSettingsStore
    @ObservedObject var securityManager = SecurityManager.shared
    
    @State private var selectedItem: ClipItem?
    @State private var activePasteAsItem: ClipItem?
    @State private var isExposeBlurred: Bool = false
    @State private var showPasteAs = false
    
    @State private var editingNoteItem: ClipItem?
    @State private var showNoteEditor = false
    @State private var noteText = ""
    
    @State private var editingTagItem: ClipItem?
    @State private var showTagEditor = false
    @State private var tagsText = ""
    
    @State private var editingFolderItem: ClipItem?
    @State private var showFolderEditor = false
    @State private var folderText = ""
    
    @State private var toastMessage: String? = nil
    @State private var eventMonitor: Any? = nil
    
    public init(engine: MockHistoryEngine, settings: MockSettingsStore) {
        self.engine = engine
        self.settings = settings
    }
    
    public var body: some View {
        ZStack {
            if securityManager.isLocked {
                AppLockScreenView(onUnlock: {
                    self.validateSelection()
                })
            } else {
                // Main Glassmorphic Backdrop
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.bgPrimary.opacity(0.85))
                    .background(
                        SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.borderPrimary.opacity(0.4), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.3), radius: 20, x: 0, y: 10)
                
                VStack(spacing: 0) {
                // 1. Top Filtering Bar
                TopFilterBar(
                    activeFilter: Binding(
                        get: { engine.activeFilter },
                        set: {
                            engine.activeFilter = $0
                            validateSelection()
                        }
                    ),
                    searchQuery: Binding(
                        get: { engine.searchQuery },
                        set: {
                            engine.searchQuery = $0
                            validateSelection()
                        }
                    ),
                    itemsCount: { type in
                        if let type = type {
                            return engine.items.filter { $0.contentType == type }.count
                        } else {
                            return engine.items.count
                        }
                    }
                )
                .padding(.top, 10)
                
                Divider()
                    .foregroundColor(Theme.borderSecondary.opacity(0.4))
                    .padding(.horizontal, 14)
                
                // 2. Main Scroll Area (Rows or Empty States)
                VStack(spacing: 12) {
                    if engine.items.isEmpty {
                        // Fully Empty State
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.on.clipboard")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.textSecondary)
                            
                            Text("Clipboard is empty")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                            
                            Text("Copy items from any application to populate your history.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)
                            
                            // Visual Shortcut Guides
                            VStack(alignment: .leading, spacing: 6) {
                                ShortcutRow(keys: ["⌘", "⇧", "V"], desc: "Toggle SlipBoard Overlay")
                                ShortcutRow(keys: ["Tab"], desc: "Cycle Content Filter Category")
                                ShortcutRow(keys: ["←", "→", "↑", "↓"], desc: "Navigate selection grid")
                                ShortcutRow(keys: ["Enter"], desc: "Paste active clipboard item")
                            }
                            .padding(12)
                            .background(Theme.bgSecondary.opacity(0.6))
                            .cornerRadius(10)
                            .padding(.top, 10)
                        }
                        Spacer()
                    } else if engine.pinnedItems.isEmpty && engine.recentItems.isEmpty {
                        // No Results matching filter/search query
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 32))
                                .foregroundColor(Theme.textSecondary)
                            
                            Text("No matches found")
                                .font(.system(size: 14, weight: .semibold, design: .rounded))
                                .foregroundColor(Theme.textSecondary)
                            
                            Text("No items match '\(engine.searchQuery)' with selected filter.")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textTertiary)
                                .multilineTextAlignment(.center)
                            
                            Button(action: {
                                withAnimation {
                                    engine.searchQuery = ""
                                    engine.activeFilter = nil
                                    validateSelection()
                                }
                            }) {
                                Text("Clear Search & Filter")
                                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Theme.accent.cornerRadius(8))
                            }
                            .buttonStyle(.plain)
                            .padding(.top, 8)
                        }
                        Spacer()
                    } else {
                        // Grid Scroll Views
                        ScrollView(.vertical, showsIndicators: true) {
                            VStack(spacing: 16) {
                                // Pinned Section
                                if !engine.pinnedItems.isEmpty {
                                    HistoryScrollRow(
                                        title: "Pinned Items",
                                        items: engine.pinnedItems,
                                        selectedItem: selectedItem,
                                        onSelect: { item in
                                            selectedItem = item
                                        }
                                    )
                                    .contextMenu {
                                        if let selected = selectedItem {
                                            cardContextMenu(for: selected)
                                        }
                                    }
                                    .popover(isPresented: Binding(
                                        get: { showPasteAs && activePasteAsItem?.isPinned == true },
                                        set: { if !$0 { showPasteAs = false } }
                                    ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                                        if let pasteItem = activePasteAsItem {
                                            PasteAsPopover(item: pasteItem) { transformedText in
                                                showPasteAs = false
                                                pasteItemText(transformedText)
                                            }
                                        }
                                    }
                                }
                                
                                // Recent Section
                                if !engine.recentItems.isEmpty {
                                    HistoryScrollRow(
                                        title: "Recent History",
                                        items: engine.recentItems,
                                        selectedItem: selectedItem,
                                        onSelect: { item in
                                            selectedItem = item
                                        }
                                    )
                                    .contextMenu {
                                        if let selected = selectedItem {
                                            cardContextMenu(for: selected)
                                        }
                                    }
                                    .popover(isPresented: Binding(
                                        get: { showPasteAs && activePasteAsItem?.isPinned == false },
                                        set: { if !$0 { showPasteAs = false } }
                                    ), attachmentAnchor: .rect(.bounds), arrowEdge: .top) {
                                        if let pasteItem = activePasteAsItem {
                                            PasteAsPopover(item: pasteItem) { transformedText in
                                                showPasteAs = false
                                                pasteItemText(transformedText)
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.vertical, 12)
                        }
                    }
                }
                .frame(maxHeight: .infinity)
                
                // 3. Bottom Glassmorphic Status Bar
                BottomStatusBar(
                    totalItems: engine.pinnedItems.count + engine.recentItems.count,
                    activeFilter: engine.activeFilter
                )
                .cornerRadius(16, corners: [.bottomLeft, .bottomRight])
            }
            
            // Note Editor Popover View
            if showNoteEditor, let editingItem = editingNoteItem {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showNoteEditor = false
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ADD ANNOTATION NOTE")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                        Button(action: { showNoteEditor = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextEditor(text: $noteText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .frame(height: 80)
                        .padding(6)
                        .background(Theme.bgSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.borderSecondary.opacity(0.6), lineWidth: 0.5)
                        )
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            engine.saveNote(for: editingItem, note: noteText)
                            showNoteEditor = false
                            showToast("Note saved successfully")
                        }) {
                            Text("Save Note")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Theme.accent.cornerRadius(6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .frame(width: 280)
                .background(
                    Theme.bgPrimary
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.borderPrimary, lineWidth: 1)
                )
                .zIndex(90)
            }
            
            // Tag Editor Popover View
            if showTagEditor, let editingItem = editingTagItem {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showTagEditor = false
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ADD TAGS")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                        Button(action: { showTagEditor = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextField("e.g. Work, receipts, code", text: $tagsText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .padding(6)
                        .background(Theme.bgSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.borderSecondary.opacity(0.6), lineWidth: 0.5)
                        )
                        .textFieldStyle(.plain)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            if let index = engine.items.firstIndex(where: { $0.id == editingItem.id }) {
                                let newTags = tagsText.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                                engine.items[index].tags = newTags
                            }
                            showTagEditor = false
                            showToast("Tags updated successfully")
                        }) {
                            Text("Save Tags")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Theme.accent.cornerRadius(6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .frame(width: 280)
                .background(
                    Theme.bgPrimary
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.borderPrimary, lineWidth: 1)
                )
                .zIndex(91)
            }
            
            // Folder Editor Popover View
            if showFolderEditor, let editingItem = editingFolderItem {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showFolderEditor = false
                    }
                
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("ASSIGN TO FOLDER")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(Theme.textTertiary)
                        Spacer()
                        Button(action: { showFolderEditor = false }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(Theme.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    
                    TextField("e.g. Projects, Personal", text: $folderText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .padding(6)
                        .background(Theme.bgSecondary)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Theme.borderSecondary.opacity(0.6), lineWidth: 0.5)
                        )
                        .textFieldStyle(.plain)
                    
                    HStack {
                        Spacer()
                        Button(action: {
                            engine.assignFolder(to: editingItem, folder: folderText.isEmpty ? nil : folderText)
                            showFolderEditor = false
                            showToast(folderText.isEmpty ? "Removed folder assignment" : "Assigned folder")
                        }) {
                            Text("Assign Folder")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 6)
                                .background(Theme.accent.cornerRadius(6))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
                .frame(width: 280)
                .background(
                    Theme.bgPrimary
                        .cornerRadius(12)
                        .shadow(color: Color.black.opacity(0.3), radius: 15, x: 0, y: 8)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.borderPrimary, lineWidth: 1)
                )
                .zIndex(92)
            }
            
            
            // 4. Toast Notification
            if let toastMsg = toastMessage {
                VStack {
                    Text(toastMsg)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.85).cornerRadius(20))
                        .shadow(color: Color.black.opacity(0.3), radius: 6, x: 0, y: 3)
                        .padding(.top, 16)
                        .transition(.move(edge: .top).combined(with: .opacity))
                    
                    Spacer()
                }
                .zIndex(100)
            }
            }
            
            // Exposé Privacy Blur View
            if isExposeBlurred && settings.hidePreviewsInMissionControl {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.clear)
                    .background(
                        SlipVisualEffectBlur(material: .hudWindow, blendingMode: .withinWindow)
                    )
                    .cornerRadius(16)
                    .zIndex(101)
            }
        }
        .frame(width: 800, height: 400)
        .onAppear {
            validateSelection()
            setupKeyboardMonitor()
            if settings.lockSlipboard && !securityManager.isLocked {
                securityManager.resetInactivityTimer()
            }
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            if settings.hidePreviewsInMissionControl {
                isExposeBlurred = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isExposeBlurred = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { notification in
            if let window = notification.object as? NSWindow, window.className.contains("PopupPanel") || window == NSApp.keyWindow {
                if settings.hidePreviewsInMissionControl {
                    isExposeBlurred = true
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in
            isExposeBlurred = false
        }
    }
    
    // MARK: - Context Menu Actions
    @ViewBuilder
    private func cardContextMenu(for item: ClipItem) -> some View {
        Button(action: { pasteItem(item) }) {
            Label("Paste", systemImage: "doc.on.clipboard")
        }
        
        Button(action: {
            activePasteAsItem = item
            showPasteAs = true
        }) {
            Label("Paste as...", systemImage: "doc.on.doc")
        }
        
        Divider()
        
        Button(action: {
            let pb = NSPasteboard.general
            pb.clearContents()
            pb.setString(item.contentString, forType: .string)
            showToast("Copied to clipboard")
        }) {
            Label("Copy to Clipboard", systemImage: "doc.on.doc.fill")
        }
        
        Button(action: {
            engine.pinItem(item)
            validateSelection()
            showToast(item.isPinned ? "Unpinned item" : "Pinned item")
        }) {
            Label(item.isPinned ? "Unpin Item" : "Pin Item", systemImage: item.isPinned ? "pin.slash.fill" : "pin.fill")
        }
        
        Button(action: {
            editingNoteItem = item
            noteText = item.note ?? ""
            showNoteEditor = true
        }) {
            Label(item.note != nil ? "Edit Note..." : "Add Note...", systemImage: "pencil.line")
        }
        
        Button(action: {
            editingTagItem = item
            tagsText = item.tags.joined(separator: ", ")
            showTagEditor = true
        }) {
            Label("Add Tag...", systemImage: "tag")
        }
        
        Menu("Assign Folder...") {
            Button(action: {
                editingFolderItem = item
                folderText = item.folder ?? ""
                showFolderEditor = true
            }) {
                Label("New Folder...", systemImage: "folder.badge.plus")
            }
            
            if item.folder != nil {
                Button(action: {
                    engine.assignFolder(to: item, folder: nil)
                    showToast("Removed folder assignment")
                }) {
                    Label("Remove from Folder", systemImage: "folder.badge.minus")
                }
            }
            
            let existingFolders = Array(Set(engine.items.compactMap { $0.folder })).sorted()
            if !existingFolders.isEmpty {
                Divider()
                ForEach(existingFolders, id: \.self) { folder in
                    Button(action: {
                        engine.assignFolder(to: item, folder: folder)
                        showToast("Assigned to folder '\(folder)'")
                    }) {
                        if item.folder == folder {
                            Label(folder, systemImage: "checkmark")
                        } else {
                            Text(folder)
                        }
                    }
                }
            }
        }
        
        Divider()
        
        Button(action: {
            engine.deleteItem(item)
            validateSelection()
            showToast("Deleted item from history")
        }) {
            Label("Delete", systemImage: "trash")
        }
    }
    
    // MARK: - Keyboard Handling
    private func setupKeyboardMonitor() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if self.handleKeyEvent(event) {
                return nil // handled, consume
            }
            return event
        }
    }
    
    private func removeKeyboardMonitor() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        if securityManager.isLocked {
            if event.keyCode == 53 { // Escape
                NSApp.keyWindow?.orderOut(nil)
                return true
            }
            return false
        }
        
        // Prevent key events when popovers or sheets are open
        if showNoteEditor || showPasteAs || showTagEditor || showFolderEditor {
            if event.keyCode == 53 { // Esc to close popovers
                showNoteEditor = false
                showPasteAs = false
                showTagEditor = false
                showFolderEditor = false
                return true
            }
            return false
        }
        
        switch event.keyCode {
        case 53: // Escape
            NSApp.keyWindow?.orderOut(nil)
            return true
            
        case 123: // Arrow Left
            selectPrev()
            return true
            
        case 124: // Arrow Right
            selectNext()
            return true
            
        case 126: // Arrow Up
            selectRowAbove()
            return true
            
        case 125: // Arrow Down
            selectRowBelow()
            return true
            
        case 48: // Tab
            let isShift = event.modifierFlags.contains(.shift)
            cycleFilter(reverse: isShift)
            return true
            
        case 36: // Enter
            if event.modifierFlags.contains(.command) {
                if let selected = selectedItem {
                    activePasteAsItem = selected
                    showPasteAs = true
                }
            } else {
                if let selected = selectedItem {
                    pasteItem(selected)
                }
            }
            return true
            
        case 35: // P key (Command + P)
            if event.modifierFlags.contains(.command) {
                if let selected = selectedItem {
                    engine.pinItem(selected)
                    validateSelection()
                    showToast(selected.isPinned ? "Unpinned item" : "Pinned item")
                }
                return true
            }
            
        case 45: // N key (Command + N)
            if event.modifierFlags.contains(.command) {
                if let selected = selectedItem {
                    editingNoteItem = selected
                    noteText = selected.note ?? ""
                    showNoteEditor = true
                }
                return true
            }
            
        default:
            break
        }
        return false
    }
    
    private func selectNext() {
        guard let current = selectedItem else {
            selectFirst()
            return
        }
        if current.isPinned {
            let items = engine.pinnedItems
            if let idx = items.firstIndex(where: { $0.id == current.id }), idx < items.count - 1 {
                selectedItem = items[idx + 1]
            }
        } else {
            let items = engine.recentItems
            if let idx = items.firstIndex(where: { $0.id == current.id }), idx < items.count - 1 {
                selectedItem = items[idx + 1]
            }
        }
    }
    
    private func selectPrev() {
        guard let current = selectedItem else {
            selectFirst()
            return
        }
        if current.isPinned {
            let items = engine.pinnedItems
            if let idx = items.firstIndex(where: { $0.id == current.id }), idx > 0 {
                selectedItem = items[idx - 1]
            }
        } else {
            let items = engine.recentItems
            if let idx = items.firstIndex(where: { $0.id == current.id }), idx > 0 {
                selectedItem = items[idx - 1]
            }
        }
    }
    
    private func selectRowBelow() {
        guard let current = selectedItem else {
            selectFirst()
            return
        }
        if current.isPinned {
            let recents = engine.recentItems
            if !recents.isEmpty {
                let pinned = engine.pinnedItems
                let idx = pinned.firstIndex(where: { $0.id == current.id }) ?? 0
                let targetIdx = min(idx, recents.count - 1)
                selectedItem = recents[targetIdx]
            }
        }
    }
    
    private func selectRowAbove() {
        guard let current = selectedItem else {
            selectFirst()
            return
        }
        if !current.isPinned {
            let pinned = engine.pinnedItems
            if !pinned.isEmpty {
                let recents = engine.recentItems
                let idx = recents.firstIndex(where: { $0.id == current.id }) ?? 0
                let targetIdx = min(idx, pinned.count - 1)
                selectedItem = pinned[targetIdx]
            }
        }
    }
    
    private func cycleFilter(reverse: Bool) {
        let cases: [ClipType?] = [nil] + ClipType.allCases
        guard let idx = cases.firstIndex(of: engine.activeFilter) else { return }
        let newIdx: Int
        if reverse {
            newIdx = idx == 0 ? cases.count - 1 : idx - 1
        } else {
            newIdx = idx == cases.count - 1 ? 0 : idx + 1
        }
        engine.activeFilter = cases[newIdx]
        validateSelection()
        showToast("Switched filter to \(cases[newIdx]?.rawValue ?? "All")")
    }
    
    private func selectFirst() {
        if let firstPinned = engine.pinnedItems.first {
            selectedItem = firstPinned
        } else if let firstRecent = engine.recentItems.first {
            selectedItem = firstRecent
        } else {
            selectedItem = nil
        }
    }
    
    private func validateSelection() {
        let visible = engine.pinnedItems + engine.recentItems
        if visible.isEmpty {
            selectedItem = nil
        } else if let current = selectedItem {
            if !visible.contains(where: { $0.id == current.id }) {
                selectFirst()
            }
        } else {
            selectFirst()
        }
    }
    
    // MARK: - Actions
    private func pasteItem(_ item: ClipItem) {
        engine.selectItem(item)
        showToast("Pasted: \(item.contentString.prefix(15))...")
        if !NSEvent.modifierFlags.contains(.option) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.keyWindow?.orderOut(nil)
            }
        }
    }
    
    private func pasteItemText(_ text: String) {
        print("Pasting transformed text: \(text)")
        
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(text, forType: .string)
        
        showToast("Pasted transformed value")
        if !NSEvent.modifierFlags.contains(.option) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                NSApp.keyWindow?.orderOut(nil)
            }
        }
    }
    
    private func showToast(_ message: String) {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            withAnimation(.easeOut(duration: 0.2)) {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }
}

// MARK: - Subviews
struct ShortcutRow: View {
    let keys: [String]
    let desc: String
    
    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                ForEach(keys, id: \.self) { key in
                    Text(key)
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.bgTertiary)
                        .cornerRadius(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Theme.borderSecondary, lineWidth: 0.5)
                        )
                }
            }
            
            Text(desc)
                .font(.system(size: 9))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

// MARK: - Rounded Corner Ext
extension View {
    public func cornerRadius(_ radius: CGFloat, corners: RectCorner) -> some View {
        clipShape(RoundedCornerShape(radius: radius, corners: corners))
    }
}

struct RoundedCornerShape: Shape {
    var radius: CGFloat = .infinity
    var corners: RectCorner = .allCorners
    
    func path(in rect: CGRect) -> Path {
        let cgPath = CGMutablePath()
        
        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0
        
        cgPath.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft), radius: topLeft, startAngle: CGFloat.pi, endAngle: CGFloat.pi * 1.5, clockwise: false)
        cgPath.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight), radius: topRight, startAngle: CGFloat.pi * 1.5, endAngle: 0, clockwise: false)
        cgPath.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight), radius: bottomRight, startAngle: 0, endAngle: CGFloat.pi * 0.5, clockwise: false)
        cgPath.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft), radius: bottomLeft, startAngle: CGFloat.pi * 0.5, endAngle: CGFloat.pi, clockwise: false)
        
        cgPath.closeSubpath()
        return Path(cgPath)
    }
}

public struct RectCorner: OptionSet, Sendable {
    public let rawValue: Int
    
    public init(rawValue: Int) {
        self.rawValue = rawValue
    }
    
    public static let topLeft = RectCorner(rawValue: 1 << 0)
    public static let topRight = RectCorner(rawValue: 1 << 1)
    public static let bottomLeft = RectCorner(rawValue: 1 << 2)
    public static let bottomRight = RectCorner(rawValue: 1 << 3)
    public static let allCorners: RectCorner = [.topLeft, .topRight, .bottomLeft, .bottomRight]
}
