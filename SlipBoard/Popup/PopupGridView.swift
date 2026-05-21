import SwiftUI

struct PopupGridView: View {
    @ObservedObject var viewModel: PopupPanelViewModel

    var body: some View {
        let snapshot = viewModel.snapshot

        VStack(alignment: .leading, spacing: 18) {
            PopupSearchFilterBar(viewModel: viewModel, snapshot: snapshot)

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 22) {
                    if let pinnedRail = snapshot.pinnedRail {
                        PopupRailSection(
                            rail: pinnedRail,
                            viewModel: viewModel
                        )
                    }

                    PopupRailSection(
                        rail: snapshot.recentRail,
                        viewModel: viewModel
                    )
                }
                .padding(.vertical, 2)
            }

            PopupStatusBar(snapshot: snapshot.statusBar)
        }
        .frame(width: 952, height: 592, alignment: .topLeading)
        .padding(22)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(Color.white.opacity(0.72))

                RoundedRectangle(cornerRadius: 26, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        )
        .overlay(alignment: .topTrailing) {
            if let pasteMenu = snapshot.activePasteMenu {
                PasteTransformMenuSurface(
                    snapshot: pasteMenu,
                    onSelect: { optionID in
                        viewModel.selectPasteTransformOption(optionID, for: pasteMenu.itemID)
                    },
                    onPrimaryAction: {
                        viewModel.performPrimaryPaste(for: pasteMenu.itemID)
                    },
                    onClose: {
                        viewModel.dismissPasteMenu()
                    }
                )
                .padding(.top, 74)
                .padding(.trailing, 14)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }
}

private struct PopupSearchFilterBar: View {
    @ObservedObject var viewModel: PopupPanelViewModel
    let snapshot: PopupPanelSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)

                    TextField(
                        snapshot.searchField.placeholder,
                        text: Binding(
                            get: { viewModel.searchQuery },
                            set: { viewModel.updateSearchQuery($0) }
                        )
                    )
                    .textFieldStyle(.plain)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.88), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Text(snapshot.title)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.black.opacity(0.06), in: Capsule())
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(snapshot.filterPills) { pill in
                        Button {
                            viewModel.changeFilter(to: pill.id)
                        } label: {
                            PopupFilterPill(snapshot: pill)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct PopupFilterPill: View {
    let snapshot: PopupFilterPillState

    var body: some View {
        HStack(spacing: 8) {
            Text(snapshot.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))

            if let countLabel = snapshot.countLabel {
                Text(countLabel)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Color.black.opacity(snapshot.isSelected ? 0.16 : 0.08), in: Capsule())
            }
        }
        .foregroundStyle(snapshot.isSelected ? Color.white : Color.primary)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            snapshot.isSelected
                ? Color(red: 0.19, green: 0.22, blue: 0.26)
                : Color.white.opacity(0.82),
            in: Capsule()
        )
    }
}

private struct PopupRailSection: View {
    let rail: PopupRailSnapshot
    @ObservedObject var viewModel: PopupPanelViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(rail.title)
                    .font(.system(size: 18, weight: .bold, design: .rounded))

                Spacer()

                Text("\(rail.items.count) items")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            if rail.items.isEmpty, let emptyMessage = rail.emptyMessage {
                PopupEmptyRailCard(message: emptyMessage)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(alignment: .top, spacing: 16) {
                        ForEach(rail.items) { card in
                            ClipboardCardView(
                                snapshot: card,
                                contextMenu: viewModel.contextMenuSnapshot(for: card.itemID),
                                noteDraft: viewModel.editingNoteItemID == card.itemID ? viewModel.noteDraft : (card.noteSummary ?? ""),
                                onSelect: {
                                    viewModel.selectItem(id: card.itemID)
                                },
                                onPaste: {
                                    viewModel.performPrimaryPaste(for: card.itemID)
                                },
                                onTogglePin: {
                                    viewModel.togglePin(for: card.itemID)
                                },
                                onBeginNoteEdit: {
                                    viewModel.beginInlineNoteEdit(for: card.itemID)
                                },
                                onCancelNoteEdit: {
                                    viewModel.cancelInlineNoteEdit(for: card.itemID)
                                },
                                onUpdateNoteDraft: { draft in
                                    viewModel.updateInlineNoteDraft(draft)
                                },
                                onSaveNote: {
                                    viewModel.saveInlineNote(for: card.itemID)
                                },
                                onOpenPasteMenu: {
                                    viewModel.openPasteMenu(for: card.itemID)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}

private struct PopupEmptyRailCard: View {
    let message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: "tray")
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(message)
                .font(.system(size: 14, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .leading)
        .padding(20)
        .background(Color.white.opacity(0.78), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct PasteTransformMenuSurface: View {
    let snapshot: PasteTransformMenuSnapshot
    let onSelect: (PasteTransformOptionID) -> Void
    let onPrimaryAction: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Paste Transforms")
                    .font(.system(size: 15, weight: .bold, design: .rounded))

                Spacer()

                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .padding(7)
                        .background(Color.black.opacity(0.06), in: Circle())
                }
                .buttonStyle(.plain)
            }

            Text(snapshot.previewText)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
                .lineLimit(3)

            VStack(spacing: 8) {
                ForEach(snapshot.options) { option in
                    Button {
                        onSelect(option.id)
                    } label: {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: option.isSelected ? "largecircle.fill.circle" : "circle")
                                .foregroundStyle(option.isSelected ? Color.accentColor : .secondary)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(option.title)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                                Text(option.detail)
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer(minLength: 0)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(option.isSelected ? 0.96 : 0.74), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(.plain)
                }
            }

            Button(action: onPrimaryAction) {
                Text(snapshot.primaryActionLabel)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color(red: 0.21, green: 0.29, blue: 0.36), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(width: 290)
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.12), radius: 18, y: 10)
    }
}

private struct PopupStatusBar: View {
    let snapshot: PopupStatusBarSnapshot

    var body: some View {
        HStack(spacing: 12) {
            statusChip(snapshot.availabilityLabel)
            statusChip(snapshot.filterSummary)
            statusChip(snapshot.captureSummary)

            Spacer(minLength: 12)

            Text(snapshot.countSummary)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            Text(snapshot.keyboardHint)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    private func statusChip(_ label: String) -> some View {
        Text(label)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color.white.opacity(0.76), in: Capsule())
    }
}
