import Foundation

protocol MenuBarShellProviding {
    var menuBarSummaryState: MenuBarSummaryState { get set }
}

extension MenuBarShellProviding {
    var menuBarBadgeText: String {
        menuBarSummaryState.badgeText
    }
}
