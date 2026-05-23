import SwiftUI

public struct CardImagePlaceholder: View {
    public init() {}
    public var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        gradient: Gradient(colors: [Theme.bgTertiary, Theme.bgSecondary]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            Image(systemName: "photo")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

public struct CardFileRow: View {
    public let name: String
    
    public init(name: String) {
        self.name = name
    }
    
    public var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "doc.fill")
                .font(.system(size: 14))
                .foregroundColor(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                Text("File binary")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.bgTertiary)
        .cornerRadius(6)
    }
}

public struct ClipCardView: View {
    public let item: ClipItem
    public let isSelected: Bool
    
    public init(item: ClipItem, isSelected: Bool) {
        self.item = item
        self.isSelected = isSelected
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Source & Type Badge
            HStack(spacing: 5) {
                if let note = item.note, !note.isEmpty {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 5, height: 5)
                        Text(note)
                            .font(.system(size: 10).italic())
                            .foregroundColor(Theme.accent)
                            .lineLimit(1)
                    }
                } else {
                    HStack(spacing: 4) {
                        Image(systemName: item.sourceAppIcon)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textSecondary)
                        Text(item.sourceApp)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textSecondary)
                    }
                }
                Spacer()
                Text(item.contentType.rawValue)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
            
            // Content renderers
            VStack {
                switch item.contentType {
                case .text:
                    Text(item.contentString)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textPrimary)
                        .lineLimit(4)
                case .code:
                    Text(item.contentString)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(Theme.accent)
                        .lineLimit(4)
                case .image:
                    CardImagePlaceholder()
                case .file:
                    CardFileRow(name: item.contentString)
                case .url:
                    Text(item.contentString)
                        .font(.system(size: 10))
                        .foregroundColor(Theme.accent)
                        .lineLimit(4)
                }
            }
            .frame(maxHeight: .infinity, alignment: .leading)
            
            // Footer: Timestamp
            HStack {
                if item.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundColor(Color.red)
                }
                Spacer()
                Text(item.formattedTime)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(Theme.textTertiary)
            }
        }
        .padding(10)
        .frame(width: 188, height: 140)
        .background(Theme.bgSecondary)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Theme.accent : Theme.borderSecondary, lineWidth: isSelected ? 1.5 : 0.5)
        )
        .overlay(
            VStack {
                if isSelected {
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(height: 2)
                    Spacer()
                }
            }
        )
    }
}
