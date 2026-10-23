import SwiftUI

struct CompanionBridgeRootView: View {
    let snapshot: CompanionBridgeSnapshot
    let pendingStates: [String: CompanionPendingReceiveRow.State]

    init(
        snapshot: CompanionBridgeSnapshot = IOSCompanionBridgeMockFixtures.snapshot,
        pendingStates: [String: CompanionPendingReceiveRow.State] = [:]
    ) {
        self.snapshot = snapshot
        self.pendingStates = pendingStates
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: CompanionBridgeTheme.sectionGap) {
                    statusHeader
                    importActions
                    scopeNote
                    pendingSection
                    policyCallout
                }
                .padding(CompanionBridgeTheme.screenPadding)
            }
            .background(CompanionBridgeTheme.surfaceBase.ignoresSafeArea())
            .navigationTitle("iCloud Bridge")
        }
    }

    private var statusHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            CompanionStatusBadge(status: snapshot.accountStatus)

            Text("Paste on Mac, then paste on iPhone")
                .font(.companionScreenTitle)
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            Text("Bridge history stays local. SlipTray only carries one reviewed payload at a time.")
                .font(.companionBody)
                .foregroundStyle(CompanionBridgeTheme.textSecondary)
        }
    }

    private var importActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Import")
                .font(.companionSectionTitle)
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            CompanionActionRow(
                symbolName: "doc.on.clipboard",
                title: "Import current clipboard",
                detail: snapshot.isForegroundImportRequired ? "Foreground confirmation stays visible on iPhone." : "Import the current supported clipboard payload."
            )

            CompanionActionRow(
                symbolName: "square.and.arrow.up",
                title: "Share Sheet import",
                detail: "Send text, URL, or code into the same one-shot bridge flow."
            )

            CompanionActionRow(
                symbolName: "bolt.horizontal.circle",
                title: "Widget and Shortcuts",
                detail: "Launch the same import path without implying background capture."
            )
        }
    }

    private var scopeNote: some View {
        CompanionPolicyCallout(
            title: "Supported scope",
            message: "Text / URL / Code only. No history upload, no background clipboard capture, no settings sync.",
            tint: CompanionBridgeTheme.accentWarning
        )
    }

    private var pendingSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Pending receive")
                .font(.companionSectionTitle)
                .foregroundStyle(CompanionBridgeTheme.textPrimary)

            if snapshot.pendingInboundItems.isEmpty {
                CompanionEmptyStateBlock(
                    title: "Nothing waiting",
                    message: "Mac-published items appear here for review before SlipTray can set your iPhone clipboard."
                )
            } else {
                ForEach(snapshot.pendingInboundItems) { item in
                    CompanionPendingReceiveRow(
                        item: item,
                        state: pendingStates[item.id] ?? .fresh
                    )
                }
            }
        }
    }

    private var policyCallout: some View {
        CompanionPolicyCallout(
            title: "Local-first receive review",
            message: "SlipTray can set your iPhone clipboard only after visible confirmation. You still paste manually in the destination app."
        )
    }
}

#Preview {
    CompanionBridgeRootView(
        pendingStates: ["mac-paste-001": .expiringSoon]
    )
}
