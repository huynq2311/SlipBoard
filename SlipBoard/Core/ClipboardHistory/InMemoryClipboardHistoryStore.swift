import Foundation

final class InMemoryClipboardHistoryStore: ClipboardHistoryStoring, ClipboardHistoryRetentionBacking {
    /// Neighbours closer than this are spaced out before a clip is put
    /// between them.
    private static let minimumRecentGap: TimeInterval = 0.002

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
            pinnedItem.richTextRTFData = candidate.richTextRTFData

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
            recentItem.richTextRTFData = candidate.richTextRTFData
            // Copied again, so it goes back to the top.
            recentItem.recentSortAt = nil

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

    func setActiveSource(_ sourceID: String?) {
        snapshot.activeSourceID = sourceID
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
                // A newly pinned clip opens the pinned rail.
                item.pinnedAt = Date()
                snapshot.pinnedItems.append(item)
            } else {
                snapshot.recentItems.append(item)
            }
        }

        snapshot = normalizedSnapshot(from: snapshot)
    }

    /// Pins the clip if it is not pinned yet and puts it right after
    /// `previousID` in the pinned rail, or first when that is nil.
    func placePinnedItem(id: String, after previousID: String?) {
        guard id != previousID else { return }
        if snapshot.pinnedItems.contains(where: { $0.id == id }) == false {
            setPinned(true, for: id)
        }

        var items = snapshot.pinnedItems
        guard let fromIndex = items.firstIndex(where: { $0.id == id }) else { return }
        let item = items.remove(at: fromIndex)
        let toIndex = previousID.flatMap { previousID in
            items.firstIndex(where: { $0.id == previousID }).map { $0 + 1 }
        } ?? 0
        items.insert(item, at: toIndex)
        let newest = items.compactMap(\.pinnedAt).max() ?? Date()
        for index in items.indices {
            items[index].pinnedAt = newest.addingTimeInterval(-Double(index))
        }
        snapshot.pinnedItems = items
        snapshot = normalizedSnapshot(from: snapshot)
    }

    /// Unpins the clip if it is pinned and moves it right after `previousID`
    /// in the recent rail, or first when that is nil. Only `recentSortAt`
    /// changes; the copy time that retention expires clips by stays put.
    func placeRecentItem(id: String, after previousID: String?) {
        guard id != previousID else { return }
        if snapshot.pinnedItems.contains(where: { $0.id == id }) {
            setPinned(false, for: id)
        }
        guard let index = snapshot.recentItems.firstIndex(where: { $0.id == id }) else { return }

        var items = snapshot.recentItems
        var item = items.remove(at: index)
        let previousIndex = previousID.flatMap { previousID in items.firstIndex { $0.id == previousID } }
        let olderIndex = previousIndex.map { $0 + 1 } ?? 0
        func neighbourKeys() -> (newer: Date?, older: Date?) {
            (
                previousIndex.map { recentSortKey(items[$0]) },
                items.indices.contains(olderIndex) ? recentSortKey(items[olderIndex]) : nil
            )
        }

        var keys = neighbourKeys()
        // Halving the same gap again and again runs out of precision, and
        // equal neighbours leave no gap at all: space the rail out first.
        if let newer = keys.newer, let older = keys.older,
           newer.timeIntervalSince(older) < Self.minimumRecentGap {
            let newest = recentSortKey(items[0])
            for itemIndex in items.indices {
                items[itemIndex].recentSortAt = newest.addingTimeInterval(-Double(itemIndex))
            }
            keys = neighbourKeys()
        }

        switch (keys.newer, keys.older) {
        case let (newer?, older?):
            item.recentSortAt = Date(timeIntervalSinceReferenceDate: (newer.timeIntervalSinceReferenceDate + older.timeIntervalSinceReferenceDate) / 2)
        case let (newer?, nil):
            item.recentSortAt = newer.addingTimeInterval(-1)
        case let (nil, older?):
            item.recentSortAt = max(Date(), older.addingTimeInterval(Self.minimumRecentGap))
        case (nil, nil):
            item.recentSortAt = Date()
        }
        items.append(item)
        snapshot.recentItems = items
        snapshot = normalizedSnapshot(from: snapshot)
    }

    func removeItem(id: String, selecting itemID: String?) {
        snapshot.pinnedItems.removeAll(where: { $0.id == id })
        snapshot.recentItems.removeAll(where: { $0.id == id })
        snapshot.selectedItemID = itemID
        snapshot = normalizedSnapshot(from: snapshot)
    }

    func touchItem(id: String, at date: Date) {
        if let index = snapshot.pinnedItems.firstIndex(where: { $0.id == id }) {
            snapshot.pinnedItems[index].lastCopiedAt = date
        } else if let index = snapshot.recentItems.firstIndex(where: { $0.id == id }) {
            snapshot.recentItems[index].lastCopiedAt = date
            snapshot.recentItems[index].recentSortAt = nil
        } else {
            return
        }

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
        // A source whose clips were all deleted or pruned must not leave the
        // popup filtered down to nothing.
        if let activeSourceID = normalized.activeSourceID,
           normalized.allItems.contains(where: { $0.sourceID == activeSourceID }) == false {
            normalized.activeSourceID = nil
        }
        normalized.pinnedItems = normalized.pinnedItems
            .map { item in
                var updatedItem = item
                updatedItem.isPinned = true
                // Clips pinned before the rail could be reordered keep their
                // copy-time order.
                updatedItem.pinnedAt = item.pinnedAt ?? item.lastCopiedAt
                updatedItem.recentSortAt = nil
                return updatedItem
            }
            .sorted(by: sortByPinnedDescending)
        normalized.recentItems = normalized.recentItems
            .map { item in
                var updatedItem = item
                updatedItem.isPinned = false
                updatedItem.pinnedAt = nil
                return updatedItem
            }
            .sorted(by: sortByRecentDescending)

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
            richTextAvailable: sample.richTextAvailable,
            richTextRTFData: sample.richTextRTFData
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

    private func recentSortKey(_ item: ClipboardHistoryItem) -> Date {
        item.recentSortAt ?? item.lastCopiedAt
    }

    private func sortByRecentDescending(_ lhs: ClipboardHistoryItem, _ rhs: ClipboardHistoryItem) -> Bool {
        let lhsKey = recentSortKey(lhs)
        let rhsKey = recentSortKey(rhs)
        if lhsKey == rhsKey {
            return sortByLastCopiedDescending(lhs, rhs)
        }

        return lhsKey > rhsKey
    }

    private func sortByPinnedDescending(_ lhs: ClipboardHistoryItem, _ rhs: ClipboardHistoryItem) -> Bool {
        if lhs.pinnedAt == rhs.pinnedAt {
            return sortByLastCopiedDescending(lhs, rhs)
        }

        return (lhs.pinnedAt ?? .distantPast) > (rhs.pinnedAt ?? .distantPast)
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
            pinnedAt: item.isPinned ? item.pinnedAt : nil,
            recentSortAt: item.isPinned ? nil : item.recentSortAt,
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
            pinnedAt: clip.pinnedAt,
            recentSortAt: clip.recentSortAt,
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
