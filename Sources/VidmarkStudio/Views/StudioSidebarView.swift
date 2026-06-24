import SwiftUI

struct StudioSidebarView: View {
    @Binding var selection: StudioSection

    var body: some View {
        List(selection: $selection) {
            Section("Primary") {
                sidebarRow(.review)
                sidebarRow(.imageReview)
                sidebarRow(.episode)
            }

            Section("Workflow") {
                sidebarRow(.assembly)
                sidebarRow(.shorts)
                sidebarRow(.prompts)
                sidebarRow(.audio)
            }

            Section("Utilities") {
                sidebarRow(.diagnostics)
            }
        }
        .listStyle(.sidebar)
        .navigationSplitViewColumnWidth(min: 210, ideal: 235, max: 270)
    }

    private func sidebarRow(_ section: StudioSection) -> some View {
        HStack(spacing: 10) {
            Image(systemName: section.systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .lineLimit(1)
                Text(section.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .tag(section)
    }
}
