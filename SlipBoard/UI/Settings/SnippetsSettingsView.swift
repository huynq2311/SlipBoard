import SwiftUI

/// Represents a simple visual snippet template item.
struct SnippetItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let trigger: String
    let content: String
}

/// Renders visual snippet libraries and inline template placeholder previews.
public struct SnippetsSettingsView<Store: SettingsStoreProtocol>: View {
    @ObservedObject public var settings: Store
    @State private var selectedSnippet: SnippetItem?
    @State private var snippets: [SnippetItem] = []
    
    public init(settings: Store) {
        self.settings = settings
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Text Snippets")
                .font(.system(.title2, design: .rounded))
                .fontWeight(.bold)
                .foregroundColor(Theme.textPrimary)
            
            Divider()
                .background(Theme.borderSecondary)
            
            HStack(spacing: 16) {
                // Left Column: List of Snippets
                VStack(alignment: .leading, spacing: 10) {
                    Text("Snippet Library")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(snippets) { snippet in
                                SnippetListItem(snippet: snippet, isSelected: selectedSnippet?.id == snippet.id) {
                                    selectedSnippet = snippet
                                }
                            }
                        }
                    }
                    .frame(width: 220)
                }
                
                // Right Column: Snippet Template Preview
                VStack(alignment: .leading, spacing: 10) {
                    Text("Template Editor Preview")
                        .font(.headline)
                        .foregroundColor(Theme.textPrimary)
                    
                    if let selected = selectedSnippet {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(selected.name)
                                    .fontWeight(.bold)
                                    .foregroundColor(Theme.textPrimary)
                                Spacer()
                                MonospacedBadge(selected.trigger, textColor: Theme.accent, backgroundColor: Theme.accentBg)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(selected.content)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundColor(Theme.textPrimary)
                                    .lineSpacing(4)
                                    .padding(14)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                            }
                            .frame(height: 180)
                            .background(Theme.bgTertiary)
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Theme.borderSecondary.opacity(0.8), lineWidth: 1)
                            )
                            
                            HStack {
                                Text("Tip: Use double brackets `{{variable}}` to prompt for input during paste.")
                                    .font(.caption2)
                                    .foregroundColor(Theme.textSecondary)
                                    .lineLimit(2)
                                Spacer()
                                Button("Copy Template") {
                                    // Visual trigger only for mock app
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(Theme.accent)
                            }
                        }
                        .padding(16)
                        .background(Theme.bgSecondary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
                        )
                        .transition(.opacity)
                    } else {
                        VStack {
                            Image(systemName: "curlybraces")
                                .font(.system(size: 40))
                                .foregroundColor(Theme.textTertiary)
                                .padding(.top, 40)
                            Text("Select a snippet template to edit and preview.")
                                .font(.caption)
                                .foregroundColor(Theme.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(24)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Theme.bgSecondary)
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Theme.borderSecondary.opacity(0.5), lineWidth: 1)
                        )
                    }
                }
            }
            .onAppear {
                loadMockSnippets()
            }
            
            Spacer()
        }
        .padding(24)
        .background(Theme.bgPrimary)
    }
    
    private func loadMockSnippets() {
        snippets = [
            SnippetItem(name: "Auth API Header", trigger: ";auth", content: "Authorization: Bearer {{token}}\nContent-Type: application/json\nAccept: application/json"),
            SnippetItem(name: "PR Template Prefix", trigger: ";gitpr", content: "## Summary of Changes\n\n- Fixes #{{issue_id}}\n- Verified build: yes\n\n## Reviewers\n@{{reviewer_username}}"),
            SnippetItem(name: "React Code Shell", trigger: ";react", content: "import React from 'react';\n\nexport const {{ComponentName}} = () => {\n  return (\n    <div>{{ComponentName}} Component</div>\n  );\n};"),
            SnippetItem(name: "Support Signoff", trigger: ";bye", content: "Thank you for reaching out!\n\nBest regards,\n{{my_name}}\nSlipBoard Customer Engineering Team")
        ]
        
        // Auto select first
        if selectedSnippet == nil {
            selectedSnippet = snippets.first
        }
    }
}

/// Helper view for rendering the left column list items.
struct SnippetListItem: View {
    let snippet: SnippetItem
    let isSelected: Bool
    let onClick: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(snippet.name)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Theme.textPrimary)
                Text(snippet.trigger)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundColor(isSelected ? .white.opacity(0.8) : Theme.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? Theme.accent : Theme.bgSecondary)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(isSelected ? Theme.accent.opacity(0.3) : Theme.borderSecondary.opacity(0.4), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture(perform: onClick)
    }
}
