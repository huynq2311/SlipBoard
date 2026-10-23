import Foundation

protocol ClipShellProviding {
    var popupShellState: PopupShellViewState { get set }
    var popupFilterOptions: [PopupFilterOption] { get }
}

extension ClipShellProviding {
    var allClipPreviews: [ClipPreviewSummary] {
        popupShellState.allClips
    }

    func clipPreview(for id: String?) -> ClipPreviewSummary? {
        guard let id else { return nil }
        return allClipPreviews.first(where: { $0.id == id })
    }

    var selectedClipPreview: ClipPreviewSummary? {
        clipPreview(for: popupShellState.selectedClipID)
    }
}
