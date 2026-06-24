import SwiftUI

struct ContentView: View {
    @StateObject private var store = StudioStore()
    @StateObject private var reframerRunner = ReframerRunner()
    @StateObject private var diagnosticRunner = DiagnosticRunner()

    var body: some View {
        NavigationSplitView {
            StudioSidebarView(selection: $store.selectedSection)
        } detail: {
            VStack(spacing: 0) {
                StudioHeaderView(store: store)
                Divider()
                selectedDetail
                Divider()
                StudioStatusBar(text: store.status)
            }
            .background(StudioTheme.background)
        }
    }

    @ViewBuilder
    private var selectedDetail: some View {
        switch store.selectedSection {
        case .episode:
            EpisodeSetupView(store: store)
        case .prompts:
            PromptBuilderView(store: store)
        case .review:
            ReviewView(store: store)
        case .imageReview:
            ImageReviewView(store: store)
        case .audio:
            AudioRulesView(store: store)
        case .assembly:
            AssemblyManifestView(store: store)
        case .shorts:
            ShortsReframerView(store: store, runner: reframerRunner)
        case .diagnostics:
            DiagnosticsView(runner: diagnosticRunner)
        }
    }
}

enum StudioTheme {
    static let background = LinearGradient(
        colors: [
            Color(nsColor: .windowBackgroundColor),
            Color(nsColor: .controlBackgroundColor).opacity(0.82)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    static let accent = Color(red: 0.47, green: 0.72, blue: 0.85)
    static let gold = Color(red: 0.95, green: 0.72, blue: 0.29)
    static let red = Color(red: 0.84, green: 0.27, blue: 0.25)
    static let green = Color(red: 0.18, green: 0.42, blue: 0.34)
}

struct StudioHeaderView: View {
    @ObservedObject var store: StudioStore

    var body: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 42, height: 42)
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text("VIDMARK STUDIO")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Video review, timecode notes, assembly manifests, and Shorts reframing.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.chooseEpisodeFolder()
            } label: {
                Label("Episode", systemImage: "folder")
            }

            Button {
                if store.selectedSection == .imageReview {
                    store.chooseImageCandidatesFolder()
                } else {
                    store.chooseMasterVideo()
                }
            } label: {
                if store.selectedSection == .imageReview {
                    Label("Candidates", systemImage: "photo.stack")
                } else {
                    Label("Master", systemImage: "film")
                }
            }
            .keyboardShortcut("o")
        }
        .padding(20)
    }
}

struct StudioStatusBar: View {
    var text: String

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(StudioTheme.green)
                .frame(width: 8, height: 8)
            Text(text)
                .lineLimit(1)
                .foregroundStyle(.secondary)
            Spacer()
            Text("Hard video cuts. Hard audio cuts. Review before publish.")
                .foregroundStyle(.tertiary)
        }
        .font(.caption)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
    }
}

struct StudioPanel<Content: View>: View {
    var title: String
    var subtitle: String?
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 17, weight: .semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            content
        }
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.quaternary)
        )
    }
}
