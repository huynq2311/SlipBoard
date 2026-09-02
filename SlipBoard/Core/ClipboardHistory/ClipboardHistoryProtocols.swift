import Foundation

protocol ClipboardPasteboardMonitoring: AnyObject {
    var latestChangeCount: Int { get }
    var isRunning: Bool { get }
    var onSample: ((ClipboardCaptureSample) -> Void)? { get set }

    func start()
    func stop()
    func pollNow()
}

protocol ClipboardHistoryStoreQuerying {
    var snapshot: ClipboardHistorySnapshot { get }

    func item(for id: String) -> ClipboardHistoryItem?
    func items(in partition: ClipboardHistoryPartition) -> [ClipboardHistoryItem]
    func visibleItems() -> [ClipboardHistoryItem]
}

protocol ClipboardHistoryStoreMutating: AnyObject {
    @discardableResult
    func apply(_ sample: ClipboardCaptureSample) -> ClipboardHistorySnapshot

    @discardableResult
    func reset(with snapshot: ClipboardHistorySnapshot) -> ClipboardHistorySnapshot

    func setSearchQuery(_ query: String)
    func setActiveFilter(_ filter: ClipboardHistoryFilter)
    func selectItem(id: String?)
    func moveSelection(by delta: Int)
    func setPinned(_ isPinned: Bool, for itemID: String)
    func removeItem(id: String, selecting itemID: String?)
}

typealias ClipboardHistoryStoring = ClipboardHistoryStoreQuerying & ClipboardHistoryStoreMutating

protocol ClipboardHistoryRetentionBacking: ClipboardHistoryStoreQuerying, AnyObject {
    var retentionManagedClips: [RetentionManagedClip] { get }

    @discardableResult
    func replaceRetentionManagedClips(
        _ clips: [RetentionManagedClip],
        captureStatus: ClipboardCaptureStatus
    ) -> ClipboardHistorySnapshot
}

struct ClipboardHistoryProjection<PopupState, FilterOption, MenuBarSummary> {
    var popupState: PopupState
    var filterOptions: [FilterOption]
    var menuBarSummary: MenuBarSummary

    init(
        popupState: PopupState,
        filterOptions: [FilterOption],
        menuBarSummary: MenuBarSummary
    ) {
        self.popupState = popupState
        self.filterOptions = filterOptions
        self.menuBarSummary = menuBarSummary
    }
}

// Projection stays generic here so this prerequisite can typecheck without
// compiling the shared SwiftUI shell models in the same task.
protocol ClipboardHistoryProjecting {
    associatedtype PopupState
    associatedtype FilterOption
    associatedtype MenuBarSummary

    func project(_ snapshot: ClipboardHistorySnapshot) -> ClipboardHistoryProjection<PopupState, FilterOption, MenuBarSummary>
}

protocol ClipboardHistoryRuntimeProviding: AnyObject {
    associatedtype PopupState
    associatedtype FilterOption
    associatedtype MenuBarSummary

    var latestSnapshot: ClipboardHistorySnapshot { get }
    var retentionSnapshot: RetentionRuntimeSnapshot { get }
    var projection: ClipboardHistoryProjection<PopupState, FilterOption, MenuBarSummary> { get }
    var isMonitoring: Bool { get }

    func startMonitoring()
    func stopMonitoring()
    func refreshNow()
    func updateSearchQuery(_ query: String)
    func updateActiveFilter(_ filter: ClipboardHistoryFilter)
    func selectItem(id: String?)
    func moveSelection(by delta: Int)
    func setPinned(_ isPinned: Bool, for itemID: String)
    func deleteItem(id: String)
}

extension ClipboardHistoryRuntimeProviding {
    var popupState: PopupState {
        projection.popupState
    }

    var filterOptions: [FilterOption] {
        projection.filterOptions
    }

    var menuBarSummary: MenuBarSummary {
        projection.menuBarSummary
    }
}
