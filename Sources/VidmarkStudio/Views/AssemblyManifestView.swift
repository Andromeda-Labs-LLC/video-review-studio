import SwiftUI

struct AssemblyManifestView: View {
    @ObservedObject var store: StudioStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                StudioPanel(
                    title: "Three-Minute Master",
                    subtitle: "The default reviewed product is a 16:9 master before vertical cuts are derived."
                ) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 14) {
                            numericField("Width", value: $store.assembly.width)
                            numericField("Height", value: $store.assembly.height)
                            numericField("FPS", value: $store.assembly.fps)
                        }
                        HStack(spacing: 14) {
                            numericField("Target seconds", value: $store.assembly.targetDurationSeconds)
                            numericField("Min modules", value: $store.assembly.moduleCountMin)
                            numericField("Max modules", value: $store.assembly.moduleCountMax)
                        }
                    }
                }

                StudioPanel(title: "Review-Gated Publishing", subtitle: "Upload stays blocked until the package is approved.") {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Export reviewer notes marks before retakes", systemImage: "scope")
                        Label("Export assembly settings for agents", systemImage: "doc.badge.gearshape")
                        Label("Run FFmpeg assembly locally with hard visual cuts", systemImage: "film.stack")
                        Label("Run Reframer only after the master passes QA", systemImage: "rectangle.portrait.on.rectangle.portrait")
                    }
                    .foregroundStyle(.secondary)

                    HStack {
                        Button {
                            store.exportReviewPackage()
                        } label: {
                            Label("Export Review Marks", systemImage: "square.and.arrow.down")
                        }
                        .disabled(store.reviewMarks.isEmpty)

                        Button {
                            store.exportAssemblySettings()
                        } label: {
                            Label("Export Assembly Settings", systemImage: "doc.badge.gearshape")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()
                    }
                    .padding(.top, 8)
                }

                StudioPanel(title: "FFmpeg Role", subtitle: "Invisible finishing, not flashy editing.") {
                    Text("""
                    Use FFmpeg for clean concat, retake replacement by timecode, hard audio cuts, loudness normalization, thumbnail frame extraction, contact sheets, draft exports, and Shorts crop handoff.

                    Do not use it to add visual stylization. No video filters, no crossfades, no fake camera motion, no speed ramps. A small speed correction is only allowed when a reviewer mark requests it.
                    """)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                }
            }
            .padding(20)
        }
    }

    private func numericField(_ title: String, value: Binding<Int>) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            TextField(title, value: value, formatter: NumberFormatter.integer)
                .textFieldStyle(.roundedBorder)
                .frame(width: 110)
        }
    }
}
