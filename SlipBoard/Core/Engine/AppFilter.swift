import Foundation

// MARK: - AppFilter

/// Decides whether a clipboard event from a given source application should
/// be captured, based on the user's exclusion list and current pause state.
///
/// All logic is a pure function of the inputs — no mutable state, no I/O.
enum AppFilter {

    // MARK: - Public Interface

    /// Evaluate whether a clipboard event should be captured.
    ///
    /// - Parameters:
    ///   - context: The source-application identity from the pasteboard snapshot.
    ///   - config: The current filter configuration (exclusion list + pause state).
    ///   - referenceDate: The date to use as "now" for timed-pause comparisons (injectable for testing).
    /// - Returns: `.capture` or `.skip(reason:)`.
    static func evaluate(
        _ context: SourceAppContext,
        config: AppFilterConfig,
        referenceDate: Date = Date()
    ) -> CaptureDecision {

        // Rule 1: check app exclusion list (case-insensitive bundle ID match).
        if let bundleID = context.bundleID {
            let lowercasedID = bundleID.lowercased()
            let isExcluded = config.excludedBundleIDs.contains { excluded in
                excluded.lowercased() == lowercasedID
            }
            if isExcluded {
                return .skip(reason: .appExcluded)
            }
        }

        // Rule 2: check pause state.
        switch config.pauseState {
        case .active:
            break // not paused — continue to capture
        case .pausedIndefinitely:
            return .skip(reason: .paused)
        case .pausedUntil(let until):
            if referenceDate < until {
                return .skip(reason: .paused)
            }
            // Pause period has elapsed — capture is allowed again.
        }

        return .capture
    }

    // MARK: - Convenience

    /// Returns `true` when the event should be captured.
    static func shouldCapture(
        _ context: SourceAppContext,
        config: AppFilterConfig,
        referenceDate: Date = Date()
    ) -> Bool {
        evaluate(context, config: config, referenceDate: referenceDate) == .capture
    }
}
