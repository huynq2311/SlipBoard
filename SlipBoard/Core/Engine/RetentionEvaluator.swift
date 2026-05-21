import Foundation

// MARK: - RetentionEvaluator

/// Evaluates whether a clipboard item should be kept or automatically removed
/// based on the user's configured retention rules.
///
/// All logic is a pure function of the inputs — no mutable state, no I/O.
/// Call once per item during a retention sweep.
enum RetentionEvaluator {

    // MARK: - Public Interface

    /// Evaluate whether a single item should be kept or removed.
    ///
    /// - Parameters:
    ///   - item: A lightweight snapshot of the item's retention-relevant metadata.
    ///   - config: The user's current retention configuration.
    ///   - referenceDate: The date to use as "now" for age comparisons (injectable for testing).
    /// - Returns: `.keep`, `.removeByAge`, or `.removeByCount`.
    static func evaluate(
        _ item: ItemRetentionSnapshot,
        config: RetentionConfig,
        referenceDate: Date = Date()
    ) -> RetentionVerdict {

        // Rule 1: pinned items are always kept, regardless of age or rank.
        if item.isPinned {
            return .keep
        }

        // Rule 2: item exceeds the configured item-count limit.
        // rankIndex is zero-based, so rankIndex >= maxItemCount means it is beyond the limit.
        if item.rankIndex >= config.maxItemCount {
            return .removeByCount
        }

        // Rule 3: item is older than the TTL threshold.
        if case .days(let days) = config.ttlPolicy {
            let ageSeconds = referenceDate.timeIntervalSince(item.createdAt)
            let ttlSeconds = Double(days) * 86_400
            if ageSeconds > ttlSeconds {
                return .removeByAge
            }
        }

        return .keep
    }

    // MARK: - Batch Evaluation

    /// Evaluate a collection of items and return only those eligible for removal.
    ///
    /// - Parameters:
    ///   - items: All items in the retention sweep, sorted by `last_copied_at` descending
    ///            so that `rankIndex` values are already meaningful.
    ///   - config: The user's current retention configuration.
    ///   - referenceDate: The date to use as "now".
    /// - Returns: An array of item IDs that should be deleted.
    static func itemsToRemove(
        from items: [ItemRetentionSnapshot],
        config: RetentionConfig,
        referenceDate: Date = Date()
    ) -> [String] {
        items.compactMap { item -> String? in
            let verdict = evaluate(item, config: config, referenceDate: referenceDate)
            switch verdict {
            case .keep:
                return nil
            case .removeByAge, .removeByCount:
                return item.itemID
            }
        }
    }
}
