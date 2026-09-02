import Foundation

final class InMemoryClipboardHistoryStore: ClipboardHistoryStoring, ClipboardHistoryRetentionBacking {
    private(set) var snapshot: ClipboardHistorySnapshot

    init(snapshot: ClipboardHistorySnapshot = ClipboardHistorySnapshot()) {
        self.snapshot = snapshot
        self.snapshot = normalizedSnapshot(from: snapshot)
    }

    func item(for id: String) -> ClipboardHistoryItem? {
        snapshot.allItems.first(where: { $0.id == id })
    }

    func items(in partition: ClipboardHistoryPartition) -> [ClipboardHistoryItem] {
        switch partition {
        case .pinned:
            return snapshot.pinnedItems
        case .recent:
            return snapshot.recentItems
        }
    }

    func visibleItems() -> [ClipboardHistoryItem] {
        snapshot.visibleItems
    }

    @discardableResult
    func apply(_ sample: ClipboardCaptureSample) -> ClipboardHistorySnapshot {
        guard let candidate = makeItem(from: sample) else {
            snapshot.captureStatus = .unsupportedSampleIgnored(
                reason: "Clipboard sample could not be normalized for the in-memory store.",
                lastChangeCount: sample.changeCount
            )
            snapshot = normalizedSnapshot(from: snapshot)
            return snapshot
        }

        let dedupeKey = candidate.dedupeKey
        let selectedDuplicateWasChosen = snapshot.selectedItemID.flatMap { selectedID in
            snapshot.allItems.first(where: { $0.id == selectedID })?.dedupeKey
        } == dedupeKey

        if let pinnedIndex = snapshot.pinnedItems.firstIndex(where: { $0.dedupeKey == dedupeKey }) {
            var pinnedItem = snapshot.pinnedItems.remove(at: pinnedIndex)
            pinnedItem.lastCopiedAt = sample.capturedAt
            pinnedItem.capturedAt = min(pinnedItem.capturedAt, sample.capturedAt)
            pinnedItem.primaryText = candidate.primaryText
            pinnedItem.secondaryText = candidate.secondaryText
            pinnedItem.metadataText = candidate.metadataText
            pinnedItem.secondaryBadgeText = candidate.secondaryBadgeText
            pinnedItem.previewStyle = candidate.previewStyle
            pinnedItem.sourceApp = candidate.sourceApp
            pinnedItem.filePaths = candidate.filePaths
            pinnedItem.colorSwatches = candidate.colorSwatches
            pinnedItem.richTextAvailable = candidate.richTextAvailable

            snapshot.recentItems.removeAll(where: { $0.dedupeKey == dedupeKey })
            snapshot.pinnedItems.append(pinnedItem)
        } else if let recentIndex = snapshot.recentItems.firstIndex(where: { $0.dedupeKey == dedupeKey }) {
            var recentItem = snapshot.recentItems.remove(at: recentIndex)
            recentItem.lastCopiedAt = sample.capturedAt
            recentItem.capturedAt = sample.capturedAt
            recentItem.primaryText = candidate.primaryText
            recentItem.secondaryText = candidate.secondaryText
            recentItem.metadataText = candidate.metadataText
            recentItem.secondaryBadgeText = candidate.secondaryBadgeText
            recentItem.previewStyle = candidate.previewStyle
            recentItem.sourceApp = candidate.sourceApp
            recentItem.filePaths = candidate.filePaths
            recentItem.colorSwatches = candidate.colorSwatches
            recentItem.richTextAvailable = candidate.richTextAvailable

            snapshot.recentItems.insert(recentItem, at: 0)
        } else {
            snapshot.recentItems.insert(candidate, at: 0)
        }

        snapshot.captureStatus = .active(latestCaptureAt: sample.capturedAt)

        if selectedDuplicateWasChosen {
            let preferredItem = snapshot.pinnedItems.first(where: { $0.dedupeKey == dedupeKey })
                ?? snapshot.recentItems.first(where: { $0.dedupeKey == dedupeKey })
            snapshot.selectedItemID = preferredItem?.id
        }

        snapshot = normalizedSnapshot(from: snapshot)
        return snapshot
    }

    @discardableResult
    func reset(with snapshot: ClipboardHistorySnapshot) -> ClipboardHistorySnapshot {
        self.snapshot = normalizedSnapshot(from: snapshot)
        return self.snapshot
    }

    func setSearchQuery(_ query: String) {
        snapshot.searchQuery = query
        snapshot = normalizedSnapshot(from: snapshot)
    }

    func setActiveFilter(_ filter: ClipboardHistoryFilter) {
        snapshot.activeFilter = filter
        snapshot = normalizedSnapshot(from: snapshot)
    }

    func selectItem(id: String?) {
        guard let id else {
            snapshot.selectedItemID = nil
            return
        }

        snapshot.selectedItemID = snapshot.visibleItems.contains(where: { $0.id == id }) ? id : snapshot.selectedItemID
        snapshot = normalizedSnapshot(from: snapshot)
    }

    func moveSelection(by delta: Int) {
        let visibleItems = snapshot.visibleItems
        guard visibleItems.isEmpty == false else {
            snapshot.selectedItemID = nil
            return
        }

        guard delta != 0 else {
            snapshot.selectedItemID = visibleItems.first?.id
            return
        }

        guard let selectedItemID = snapshot.selectedItemID,
              let currentIndex = visibleItems.firstIndex(where: { $0.id == selectedItemID }) else {
            snapshot.selectedItemID = delta > 0 ? visibleItems.first?.id : visibleItems.last?.id
            return
        }

        let nextIndex = max(0, min(visibleItems.count - 1, currentIndex + delta))
        snapshot.selectedItemID = visibleItems[nextIndex].id
    }

    func setPinned(_ isPinned: Bool, for itemID: String) {
        if let pinnedIndex = snapshot.pinnedItems.firstIndex(where: { $0.id == itemID }) {
            var item = snapshot.pinnedItems.remove(at: pinnedIndex)
            item.isPinned = isPinned

            if isPinned {
                snapshot.pinnedItems.append(item)
            } else {
                snapshot.recentItems.append(item)
            }
        } else if let recentIndex = snapshot.recentItems.firstIndex(where: { $0.id == itemID }) {
            var item = snapshot.recentItems.remove(at: recentIndex)
            item.isPinned = isPinned

            if isPinned {
                snapshot.pinnedItems.append(item)
            } else {
                snapshot.recentItems.append(item)
            }
        }

        snapshot = normalizedSnapshot(from: snapshot)
    }

    func removeItem(id: String, selecting itemID: String?) {
        snapshot.pinnedItems.removeAll(where: { $0.id == id })
        snapshot.recentItems.removeAll(where: { $0.id == id })
        snapshot.selectedItemID = itemID
        snapshot = normalizedSnapshot(from: snapshot)
    }

    var retentionManagedClips: [RetentionManagedClip] {
        snapshot.allItems.map(makeManagedClip)
    }

    @discardableResult
    func replaceRetentionManagedClips(
        _ clips: [RetentionManagedClip],
        captureStatus: ClipboardCaptureStatus
    ) -> ClipboardHistorySnapshot {
        var nextSnapshot = snapshot
        nextSnapshot.captureStatus = captureStatus
        nextSnapshot.pinnedItems = clips
            .filter(\.isPinned)
            .map(makeHistoryItem)
        nextSnapshot.recentItems = clips
            .filter { $0.isPinned == false }
            .map(makeHistoryItem)
        snapshot = normalizedSnapshot(from: nextSnapshot)
        return snapshot
    }

    private func normalizedSnapshot(from snapshot: ClipboardHistorySnapshot) -> ClipboardHistorySnapshot {
        var normalized = snapshot
        normalized.pinnedItems = normalized.pinnedItems
            .map { item in
                var updatedItem = item
                updatedItem.isPinned = true
                return updatedItem
            }
            .sorted(by: sortByLastCopiedDescending)
        normalized.recentItems = normalized.recentItems
            .map { item in
                var updatedItem = item
                updatedItem.isPinned = false
                return updatedItem
            }
            .sorted(by: sortByLastCopiedDescending)

        if let selectedID = normalized.selectedItemID,
           normalized.visibleItems.contains(where: { $0.id == selectedID }) == false {
            normalized.selectedItemID = normalized.visibleItems.first?.id
        } else if normalized.selectedItemID == nil {
            normalized.selectedItemID = normalized.visibleItems.first?.id
        }

        return normalized
    }

    private func makeItem(from sample: ClipboardCaptureSample) -> ClipboardHistoryItem? {
        let normalizedText = sample.normalizedText?.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedHash = sample.normalizedHash ?? normalizedText.map { fallback in
            String(fallback.hashValue, radix: 16)
        }

        guard let normalizedHash else {
            return nil
        }

        let descriptor = itemDescriptor(for: sample, normalizedText: normalizedText)

        return ClipboardHistoryItem(
            id: "clip-\(sample.changeCount)-\(normalizedHash.prefix(8))",
            capturedAt: sample.capturedAt,
            lastCopiedAt: sample.capturedAt,
            kind: sample.kind,
            normalizedHash: normalizedHash,
            primaryText: descriptor.primaryText,
            secondaryText: descriptor.secondaryText,
            metadataText: sample.sourceApp.displayName,
            secondaryBadgeText: descriptor.secondaryBadgeText,
            previewStyle: descriptor.previewStyle,
            sourceApp: sample.sourceApp,
            isPinned: false,
            filePaths: sample.filePaths,
            colorSwatches: descriptor.colorSwatches,
            richTextAvailable: sample.richTextAvailable
        )
    }

    private func itemDescriptor(
        for sample: ClipboardCaptureSample,
        normalizedText: String?
    ) -> (
        primaryText: String,
        secondaryText: String?,
        secondaryBadgeText: String?,
        previewStyle: ClipboardHistoryPreviewStyle,
        colorSwatches: [String]
    ) {
        switch sample.kind {
        case .text:
            return (
                primaryText: normalizedText ?? "Text Clip",
                secondaryText: nil,
                secondaryBadgeText: "text",
                previewStyle: .text,
                colorSwatches: []
            )
        case .code:
            return (
                primaryText: normalizedText ?? "Code Clip",
                secondaryText: nil,
                secondaryBadgeText: "code",
                previewStyle: .code(languageHint: languageHint(for: normalizedText)),
                colorSwatches: []
            )
        case .image:
            let descriptor = sample.normalizedText ?? sample.rawString ?? "Image copied from \(sample.sourceApp.displayName)"
            return (
                primaryText: "Image",
                secondaryText: descriptor,
                secondaryBadgeText: "image",
                previewStyle: .image,
                colorSwatches: []
            )
        case .file:
            let fileName = sample.filePaths.first.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "File"
            let subtitle: String?
            if sample.filePaths.count > 1 {
                subtitle = "\(sample.filePaths.count) files"
            } else {
                subtitle = sample.filePaths.first
            }

            let fileExtensionValue: String?
            if let firstPath = sample.filePaths.first {
                fileExtensionValue = fileExtension(for: firstPath)
            } else {
                fileExtensionValue = nil
            }

            return (
                primaryText: fileName,
                secondaryText: subtitle,
                secondaryBadgeText: fileExtensionValue,
                previewStyle: .file(fileExtension: fileExtensionValue),
                colorSwatches: []
            )
        case .url:
            let text = sample.rawURL?.absoluteString ?? normalizedText ?? "URL"
            return (
                primaryText: text,
                secondaryText: sample.rawURL?.host,
                secondaryBadgeText: "url",
                previewStyle: .url,
                colorSwatches: []
            )
        case .color:
            let colorText = normalizedText ?? sample.rawString ?? "Color"
            return (
                primaryText: colorText,
                secondaryText: "Clipboard color swatch",
                secondaryBadgeText: "color",
                previewStyle: .color(swatches: [colorText]),
                colorSwatches: [colorText]
            )
        case .richText:
            return (
                primaryText: normalizedText ?? "Rich Text Clip",
                secondaryText: nil,
                secondaryBadgeText: "rtf",
                previewStyle: .richText,
                colorSwatches: []
            )
        }
    }

    private func sortByLastCopiedDescending(_ lhs: ClipboardHistoryItem, _ rhs: ClipboardHistoryItem) -> Bool {
        if lhs.lastCopiedAt == rhs.lastCopiedAt {
            return lhs.id > rhs.id
        }

        return lhs.lastCopiedAt > rhs.lastCopiedAt
    }

    private func languageHint(for text: String?) -> String? {
        guard let text else { return nil }
        let lowercased = text.lowercased()

        if lowercased.contains("import swiftui") || lowercased.contains("let ") || lowercased.contains("func ") {
            return "swift"
        }
        if lowercased.contains("select ") || lowercased.contains("insert ") || lowercased.contains("update ") {
            return "sql"
        }
        if lowercased.contains("curl ") || lowercased.contains("#!/bin/") {
            return "sh"
        }

        return nil
    }

    private func fileExtension(for path: String) -> String? {
        let ext = URL(fileURLWithPath: path).pathExtension
        return ext.isEmpty ? nil : ext.uppercased()
    }

    private func makeManagedClip(from item: ClipboardHistoryItem) -> RetentionManagedClip {
        RetentionManagedClip(
            id: item.id,
            normalizedHash: item.normalizedHash,
            kind: retentionKind(for: item.kind),
            capturedAt: item.capturedAt,
            lastCopiedAt: item.lastCopiedAt,
            isPinned: item.isPinned,
            pinnedAt: item.isPinned ? item.lastCopiedAt : nil,
            titleText: item.primaryText,
            secondaryText: item.secondaryText,
            metadataText: item.metadataText,
            secondaryBadgeText: item.secondaryBadgeText,
            sourceAppBundleID: item.sourceApp.bundleID,
            sourceAppDisplayName: item.sourceApp.displayName,
            sourceAppSymbolName: item.sourceApp.symbolName,
            sourceAppAccentToken: item.sourceApp.accentToken,
            previewStyleKey: previewStyleKey(for: item.previewStyle),
            previewStyleHint: previewStyleHint(for: item.previewStyle),
            filePaths: item.filePaths,
            colorSwatches: item.colorSwatches,
            richTextAvailable: item.richTextAvailable,
            estimatedByteSize: estimatedByteSize(for: item),
            assetCacheKey: assetCacheKey(for: item)
        )
    }

    private func makeHistoryItem(from clip: RetentionManagedClip) -> ClipboardHistoryItem {
        ClipboardHistoryItem(
            id: clip.id,
            capturedAt: clip.capturedAt,
            lastCopiedAt: clip.lastCopiedAt,
            kind: clipboardKind(for: clip.kind),
            normalizedHash: clip.normalizedHash,
            primaryText: clip.titleText,
            secondaryText: clip.secondaryText,
            metadataText: clip.metadataText,
            secondaryBadgeText: clip.secondaryBadgeText,
            previewStyle: makePreviewStyle(from: clip),
            sourceApp: ClipboardSourceAppSummary(
                bundleID: clip.sourceAppBundleID,
                displayName: clip.sourceAppDisplayName,
                symbolName: clip.sourceAppSymbolName,
                accentToken: clip.sourceAppAccentToken
            ),
            isPinned: clip.isPinned,
            filePaths: clip.filePaths,
            colorSwatches: clip.colorSwatches,
            richTextAvailable: clip.richTextAvailable
        )
    }

    private func retentionKind(for kind: ClipboardHistoryKind) -> RetentionClipKind {
        switch kind {
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
        case .richText:
            return .richText
        }
    }

    private func clipboardKind(for kind: RetentionClipKind) -> ClipboardHistoryKind {
        switch kind {
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
        case .richText:
            return .richText
        }
    }

    private func makePreviewStyle(from clip: RetentionManagedClip) -> ClipboardHistoryPreviewStyle {
        switch clip.previewStyleKey {
        case "code":
            return .code(languageHint: clip.previewStyleHint)
        case "image":
            return .image
        case "file":
            return .file(fileExtension: clip.previewStyleHint)
        case "url":
            return .url
        case "color":
            return .color(swatches: clip.colorSwatches)
        case "richText":
            return .richText
        default:
            return .text
        }
    }

    private func previewStyleKey(for style: ClipboardHistoryPreviewStyle) -> String {
        switch style {
        case .text:
            return "text"
        case .code:
            return "code"
        case .image:
            return "image"
        case .file:
            return "file"
        case .url:
            return "url"
        case .color:
            return "color"
        case .richText:
            return "richText"
        }
    }

    private func previewStyleHint(for style: ClipboardHistoryPreviewStyle) -> String? {
        switch style {
        case .code(let languageHint):
            return languageHint
        case .file(let fileExtension):
            return fileExtension
        default:
            return nil
        }
    }

    private func estimatedByteSize(for item: ClipboardHistoryItem) -> Int64 {
        let textBytes = Int64(item.primaryText.utf8.count)
            + Int64((item.secondaryText ?? "").utf8.count)
            + Int64(item.filePaths.joined(separator: "\n").utf8.count)
            + Int64(item.colorSwatches.joined(separator: ",").utf8.count)
        return max(textBytes, 512)
    }

    private func assetCacheKey(for item: ClipboardHistoryItem) -> String? {
        switch item.kind {
        case .image, .file, .richText:
            return "asset-\(item.id)"
        case .text, .code, .url, .color:
            return nil
        }
    }
}
