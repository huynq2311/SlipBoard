import SwiftUI

struct ClipboardCardView: View {
    let snapshot: PopupCardSnapshot
    let contextMenu: ClipboardContextMenuSnapshot?
    let noteDraft: String
    let onSelect: () -> Void
    let onPaste: () -> Void
    let onTogglePin: () -> Void
    let onBeginNoteEdit: () -> Void
    let onCancelNoteEdit: () -> Void
    let onUpdateNoteDraft: (String) -> Void
    let onSaveNote: () -> Void
    let onOpenPasteMenu: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            previewBody
            footer
        }
        .frame(width: 214, alignment: .topLeading)
        .frame(minHeight: 250, alignment: .topLeading)
        .padding(16)
        .background(cardBackground, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(snapshot.isSelected ? Color.accentColor.opacity(0.45) : Color.black.opacity(0.06), lineWidth: snapshot.isSelected ? 2 : 1)
        )
        .shadow(color: Color.black.opacity(snapshot.isSelected ? 0.14 : 0.08), radius: snapshot.isSelected ? 18 : 10, y: 8)
        .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onTapGesture(perform: onSelect)
        .contextMenu {
            if let contextMenu {
                ForEach(contextMenu.items) { item in
                    switch item.id {
                    case .paste:
                        Button(role: menuRole(for: item.role), action: onPaste) {
                            menuLabel(for: item)
                        }
                        .disabled(!item.isEnabled)
                    case .pasteTransforms:
                        Button(role: menuRole(for: item.role), action: onOpenPasteMenu) {
                            menuLabel(for: item)
                        }
                        .disabled(!item.isEnabled)
                    case .pin, .unpin:
                        Button(role: menuRole(for: item.role), action: onTogglePin) {
                            menuLabel(for: item)
                        }
                        .disabled(!item.isEnabled)
                    case .addNote, .editNote:
                        Button(role: menuRole(for: item.role), action: onBeginNoteEdit) {
                            menuLabel(for: item)
                        }
                        .disabled(!item.isEnabled)
                    case .deletePlaceholder:
                        Button(role: .destructive, action: onSelect) {
                            menuLabel(for: item)
                        }
                        .disabled(!item.isEnabled)
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(snapshot.sourceLabel)
                        .font(.system(size: 14, weight: .bold, design: .rounded))

                    HStack(spacing: 6) {
                        badge(snapshot.typeLabel, fill: Color.black.opacity(0.06), foreground: .primary)

                        if snapshot.isPinned {
                            badge("Pinned", fill: Color(red: 0.95, green: 0.76, blue: 0.46), foreground: .black)
                        }

                        if snapshot.noteSummary != nil {
                            badge("Note", fill: Color(red: 0.83, green: 0.90, blue: 0.78), foreground: .black)
                        }
                    }
                }

                Spacer(minLength: 12)

                Button(action: onTogglePin) {
                    Image(systemName: snapshot.isPinned ? "pin.fill" : "pin")
                        .foregroundStyle(snapshot.isPinned ? Color(red: 0.61, green: 0.36, blue: 0.12) : .secondary)
                        .padding(8)
                        .background(Color.black.opacity(0.04), in: Circle())
                }
                .buttonStyle(.plain)
            }

            if snapshot.isEditingNote {
                VStack(alignment: .leading, spacing: 8) {
                    TextField(
                        "Add a local note",
                        text: Binding(
                            get: { noteDraft },
                            set: onUpdateNoteDraft
                        )
                    )
                    .textFieldStyle(.roundedBorder)

                    HStack(spacing: 8) {
                        Button("Save", action: onSaveNote)
                            .buttonStyle(.borderedProminent)

                        Button("Cancel", action: onCancelNoteEdit)
                            .buttonStyle(.bordered)
                    }
                }
            } else if let noteSummary = snapshot.noteSummary {
                Button(action: onBeginNoteEdit) {
                    Text(noteSummary)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onBeginNoteEdit) {
                    Label("Add note", systemImage: "square.and.pencil")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var previewBody: some View {
        switch snapshot.preview {
        case let .text(value):
            previewTextBlock(value, accent: Color(red: 0.87, green: 0.92, blue: 0.98))
        case let .code(language, snippet):
            VStack(alignment: .leading, spacing: 10) {
                if let language {
                    Text(language.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                Text(snippet)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .lineLimit(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(Color(red: 0.14, green: 0.16, blue: 0.19), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .foregroundStyle(.white)
        case let .image(description):
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.80, green: 0.88, blue: 0.96),
                                Color(red: 0.93, green: 0.82, blue: 0.77)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(height: 88)
                    .overlay(
                        Image(systemName: "photo")
                            .font(.title2)
                            .foregroundStyle(.white.opacity(0.9))
                    )

                Text(description)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(3)
            }
        case let .file(name, detail):
            VStack(alignment: .leading, spacing: 10) {
                Label(name, systemImage: "doc")
                    .font(.system(size: 13, weight: .semibold, design: .rounded))

                Text(detail)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(Color(red: 0.95, green: 0.93, blue: 0.87), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case let .url(value):
            VStack(alignment: .leading, spacing: 10) {
                Label("URL", systemImage: "link")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Color(red: 0.11, green: 0.32, blue: 0.55))
                    .lineLimit(4)
            }
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(Color(red: 0.91, green: 0.95, blue: 0.99), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        case let .color(hex):
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color(hex: hex) ?? Color.gray)
                    .frame(height: 88)

                Text(hex)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(snapshot.captureTimeLabel)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button(action: onPaste) {
                    Label(snapshot.pasteLabel, systemImage: "arrowshape.turn.up.forward.fill")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)

                Button(action: onOpenPasteMenu) {
                    Image(systemName: "wand.and.stars")
                        .padding(10)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var cardBackground: some ShapeStyle {
        snapshot.isSelected
            ? AnyShapeStyle(Color.white.opacity(0.96))
            : AnyShapeStyle(Color.white.opacity(0.82))
    }

    private func badge(_ title: String, fill: Color, foreground: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .rounded))
            .foregroundStyle(foreground)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(fill, in: Capsule())
    }

    private func previewTextBlock(_ value: String, accent: Color) -> some View {
        Text(value)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .lineLimit(7)
            .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            .padding(14)
            .background(accent, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func menuLabel(for item: ClipboardContextMenuItem) -> some View {
        if let symbolName = item.symbolName {
            Label(item.title, systemImage: symbolName)
        } else {
            Text(item.title)
        }
    }

    private func menuRole(for role: PopupMenuItemRole) -> ButtonRole? {
        switch role {
        case .standard:
            return nil
        case .primary:
            return nil
        case .destructive:
            return .destructive
        }
    }
}

private extension Color {
    init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else {
            return nil
        }

        self.init(
            red: Double((value >> 16) & 0xFF) / 255.0,
            green: Double((value >> 8) & 0xFF) / 255.0,
            blue: Double(value & 0xFF) / 255.0
        )
    }
}

struct ClipboardCardView_Previews: PreviewProvider {
    static var previews: some View {
        let fixture = PopupShellFixtures.noteEditing.snapshot.recentRail.items.first!
        let menu = PopupShellFixtures.compactDemo.snapshot.activeContextMenu

        ClipboardCardView(
            snapshot: fixture,
            contextMenu: menu,
            noteDraft: fixture.noteSummary ?? "",
            onSelect: {},
            onPaste: {},
            onTogglePin: {},
            onBeginNoteEdit: {},
            onCancelNoteEdit: {},
            onUpdateNoteDraft: { _ in },
            onSaveNote: {},
            onOpenPasteMenu: {}
        )
        .padding()
        .background(Color(red: 0.93, green: 0.91, blue: 0.87))
        .previewLayout(.sizeThatFits)
    }
}
