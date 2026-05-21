import SwiftUI

struct SettingsSectionsView: View {
    let sections: [SettingsShellSection]

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            ForEach(sections) { section in
                SettingsSection(section: section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}

struct SettingsSection: View {
    let section: SettingsShellSection

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(section.title)
                .font(.title3.weight(.semibold))

            if let helperText = section.helperText {
                Text(helperText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 0) {
                ForEach(Array(section.rows.enumerated()), id: \.offset) { index, row in
                    SettingsRowRenderer(row: row)

                    if index < section.rows.count - 1 {
                        Divider()
                            .padding(.leading, 18)
                    }
                }
            }
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }
}

private struct SettingsRowRenderer: View {
    let row: SettingsShellRow

    var body: some View {
        switch row {
        case let .toggle(toggleRow):
            SettingsToggleRow(row: toggleRow)
        case let .value(valueRow):
            SettingsValueRow(row: valueRow)
        case let .segmented(segmentedRow):
            SettingsSegmentedRow(row: segmentedRow)
        case let .slider(sliderRow):
            SettingsSliderRow(row: sliderRow)
        case let .action(actionRow):
            SettingsActionRow(row: actionRow)
        case let .list(listRow):
            SettingsListRow(row: listRow)
        case let .callout(calloutRow):
            SettingsCalloutRow(row: calloutRow)
        }
    }
}

struct SettingsToggleRow: View {
    let row: SettingsShellToggleRow
    @State private var isOn: Bool

    init(row: SettingsShellToggleRow) {
        self.row = row
        _isOn = State(initialValue: row.isOn)
    }

    var body: some View {
        SettingsRowLayout(title: row.title, detail: row.detail) {
            Toggle("", isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
        }
    }
}

struct SettingsValueRow: View {
    let row: SettingsShellValueRow

    var body: some View {
        SettingsRowLayout(title: row.title, detail: row.detail) {
            Text(row.value)
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
        }
    }
}

struct SettingsSegmentedRow: View {
    let row: SettingsShellSegmentedRow
    @State private var selectedID: String

    init(row: SettingsShellSegmentedRow) {
        self.row = row
        _selectedID = State(initialValue: row.options.first(where: \.isSelected)?.id ?? row.options.first?.id ?? "")
    }

    var body: some View {
        SettingsRowLayout(title: row.title, detail: row.detail, alignment: .top) {
            Picker(row.title, selection: $selectedID) {
                ForEach(row.options) { option in
                    Text(option.title).tag(option.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .frame(width: 260)
        }
    }
}

struct SettingsSliderRow: View {
    let row: SettingsShellSliderRow
    @State private var value: Double

    init(row: SettingsShellSliderRow) {
        self.row = row
        _value = State(initialValue: row.value)
    }

    var body: some View {
        SettingsRowLayout(title: row.title, detail: row.detail, alignment: .top) {
            VStack(alignment: .trailing, spacing: 8) {
                Slider(value: $value, in: row.range, step: row.step)
                    .frame(width: 240)

                Text(valueLabel)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var valueLabel: String {
        if row.valueLabel.contains("items") {
            return "\(Int(value.rounded())) items"
        }

        return String(Int(value.rounded()))
    }
}

struct SettingsActionRow: View {
    let row: SettingsShellActionRow

    var body: some View {
        SettingsRowLayout(title: row.title, detail: row.detail) {
            switch row.role {
            case .standard:
                Button(row.buttonTitle) {}
                    .buttonStyle(.borderedProminent)
                    .disabled(!row.isEnabled)
            case .quiet:
                Button(row.buttonTitle) {}
                    .buttonStyle(.bordered)
                    .disabled(!row.isEnabled)
            case .destructive:
                Button(row.buttonTitle) {}
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                    .disabled(!row.isEnabled)
            }
        }
    }
}

struct SettingsListRow: View {
    let row: SettingsShellListRow

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            SettingsRowHeader(title: row.title, detail: row.detail)

            if row.items.isEmpty {
                Text(row.emptyStateTitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(row.items.enumerated()), id: \.element.id) { index, item in
                        HStack(alignment: .center, spacing: 12) {
                            if let symbolName = item.symbolName {
                                Image(systemName: symbolName)
                                    .frame(width: 18)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .font(.body.weight(.medium))

                                if let detail = item.detail {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }

                            Spacer()

                            if let accessoryLabel = item.accessoryLabel {
                                Text(accessoryLabel)
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)

                        if index < row.items.count - 1 {
                            Divider()
                        }
                    }
                }
            }

            if let actionTitle = row.actionTitle {
                Button(actionTitle) {}
                    .buttonStyle(.bordered)
            }
        }
        .padding(18)
    }
}

struct SettingsCalloutRow: View {
    let row: SettingsShellCalloutRow

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.style == .warning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                .foregroundStyle(row.style == .warning ? Color.orange : Color.accentColor)

            VStack(alignment: .leading, spacing: 6) {
                Text(row.title)
                    .font(.body.weight(.semibold))

                Text(row.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .padding(18)
    }

    private var backgroundColor: Color {
        row.style == .warning ? Color.orange.opacity(0.12) : Color.accentColor.opacity(0.10)
    }
}

private struct SettingsRowLayout<Trailing: View>: View {
    let title: String
    let detail: String?
    let alignment: VerticalAlignment
    @ViewBuilder let trailing: Trailing

    init(
        title: String,
        detail: String?,
        alignment: VerticalAlignment = .center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.title = title
        self.detail = detail
        self.alignment = alignment
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: alignment, spacing: 20) {
            SettingsRowHeader(title: title, detail: detail)

            Spacer(minLength: 12)

            trailing
        }
        .padding(18)
    }
}

private struct SettingsRowHeader: View {
    let title: String
    let detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.body.weight(.medium))

            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
