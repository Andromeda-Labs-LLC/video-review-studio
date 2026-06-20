import AVFoundation
import SwiftUI

struct ReviewView: View {
    @ObservedObject var store: StudioStore
    @StateObject private var clock = PlayerClock()
    @State private var player = AVPlayer()
    @State private var showRevisionPicker = false
    @State private var isTheaterMode = false
    @State private var fullScreenTrigger = 0
    @State private var shuttleDirection = ShuttleDirection.paused
    @State private var shuttleRate: Float = 1

    var body: some View {
        HStack(spacing: 0) {
            reviewDeck
                .padding(22)

            if !isTheaterMode {
                Divider()
                revisionPanel
                    .frame(width: 430)
                    .padding(18)
            }
        }
        .background(StudioTheme.background)
        .onAppear(perform: loadMaster)
        .onChange(of: store.masterVideoURL) {
            loadMaster()
        }
        .sheet(isPresented: $showRevisionPicker) {
            RevisionTypePickerSheet(
                timecode: clock.currentTime,
                onChoose: { type in
                    store.addReviewMark(ReviewMark(timecodeSeconds: clock.currentTime, revisionType: type))
                    showRevisionPicker = false
                }
            )
        }
    }

    private var reviewDeck: some View {
        VStack(alignment: .leading, spacing: 16) {
            reviewHeader
            videoSurface
            transportControls
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var reviewHeader: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Review")
                    .font(.system(size: 24, weight: .semibold))
                Text("Pause on a trouble spot, press Mark, choose the revision type, then submit the edit packet.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                store.chooseEpisodeFolder()
            } label: {
                Label("Episode", systemImage: "folder")
            }

            Button {
                store.chooseMasterVideo()
            } label: {
                Label("Master", systemImage: "film")
            }
            .keyboardShortcut("o")

            Button {
                isTheaterMode.toggle()
            } label: {
                Label(
                    isTheaterMode ? "Show Marks" : "Theater",
                    systemImage: isTheaterMode ? "sidebar.right" : "rectangle.inset.filled"
                )
            }
            .disabled(store.masterVideoURL == nil)
        }
    }

    private var videoSurface: some View {
        ZStack {
            if store.masterVideoURL == nil {
                ContentUnavailableView(
                    "No Master Selected",
                    systemImage: "film",
                    description: Text("Choose the episode master to begin review.")
                )
                .foregroundStyle(.secondary)
            } else {
                NativeVideoPlayerView(player: player, fullScreenTrigger: fullScreenTrigger)
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .background(.black)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        )
        .shadow(color: .black.opacity(0.32), radius: 24, y: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .frame(minHeight: isTheaterMode ? 700 : 560, alignment: .top)
    }

    private var transportControls: some View {
        HStack(spacing: 10) {
            shuttleButton(
                title: "J",
                subtitle: shuttleDirection == .reverse ? "\(Int(shuttleRate))x" : "REV",
                systemImage: "backward.fill",
                action: shuttleReverse
            )
            .keyboardShortcut("j", modifiers: [])

            shuttleButton(
                title: "K",
                subtitle: "PAUSE",
                systemImage: "pause.fill",
                action: pausePlayback
            )
            .keyboardShortcut("k", modifiers: [])

            shuttleButton(
                title: "L",
                subtitle: shuttleDirection == .forward ? "\(Int(shuttleRate))x" : "FWD",
                systemImage: "forward.fill",
                action: shuttleForward
            )
            .keyboardShortcut("l", modifiers: [])

            Divider()
                .frame(height: 34)
                .padding(.horizontal, 4)

            Button {
                step(seconds: -5)
            } label: {
                Label("-5s", systemImage: "gobackward.5")
            }
            .disabled(store.masterVideoURL == nil)

            Button {
                openRevisionPicker()
            } label: {
                Label("Mark \(TimecodeFormatter.string(clock.currentTime))", systemImage: "mappin.and.ellipse")
                    .font(.system(size: 15, weight: .semibold))
            }
            .buttonStyle(MarkButtonStyle())
            .keyboardShortcut("m", modifiers: [])
            .disabled(store.masterVideoURL == nil)

            Button {
                step(seconds: 5)
            } label: {
                Label("+5s", systemImage: "goforward.5")
            }
            .disabled(store.masterVideoURL == nil)

            Button {
                fullScreenTrigger += 1
            } label: {
                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            .disabled(store.masterVideoURL == nil)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(TimecodeFormatter.string(clock.currentTime))
                    .font(.system(size: 22, weight: .semibold, design: .monospaced))
                    .foregroundStyle(StudioTheme.gold)
                Text(shuttleLabel)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }

    private var revisionPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Revision List")
                        .font(.system(size: 18, weight: .semibold))
                    Text("\(store.reviewMarks.count) open request\(store.reviewMarks.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    openRevisionPicker()
                } label: {
                    Label("Mark", systemImage: "plus")
                }
                .buttonStyle(.borderedProminent)
                .disabled(store.masterVideoURL == nil)
            }

            if store.reviewMarks.isEmpty {
                ContentUnavailableView(
                    "No Marks Yet",
                    systemImage: "checkmark.seal",
                    description: Text("Pause on an issue and press Mark.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach($store.reviewMarks) { $mark in
                            ReviewRevisionCard(
                                mark: $mark,
                                currentTime: clock.currentTime,
                                onSeek: seek,
                                onDelete: {
                                    store.deleteReviewMark(id: mark.id)
                                }
                            )
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            Button {
                store.submitReviewPackage()
            } label: {
                Text("SUBMIT")
                    .font(.system(size: 16, weight: .bold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(SubmitButtonStyle())
            .disabled(store.reviewMarks.isEmpty)
        }
    }

    private var shuttleLabel: String {
        switch shuttleDirection {
        case .paused: "Paused"
        case .forward: "Forward shuttle \(Int(shuttleRate))x"
        case .reverse: "Reverse shuttle \(Int(shuttleRate))x"
        }
    }

    private func shuttleButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                HStack(spacing: 5) {
                    Image(systemName: systemImage)
                    Text(title)
                        .font(.system(.body, design: .monospaced).weight(.bold))
                }
                Text(subtitle)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .frame(minWidth: 64)
        }
        .disabled(store.masterVideoURL == nil)
    }

    private func loadMaster() {
        guard let url = store.masterVideoURL else {
            pausePlayback()
            player.replaceCurrentItem(with: nil)
            return
        }
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        clock.attach(to: player)
        pausePlayback()
    }

    private func openRevisionPicker() {
        pausePlayback()
        showRevisionPicker = true
    }

    private func shuttleReverse() {
        if shuttleDirection == .reverse {
            shuttleRate = min(shuttleRate * 2, 4)
        } else {
            shuttleDirection = .reverse
            shuttleRate = 1
        }
        player.playImmediately(atRate: -shuttleRate)
    }

    private func pausePlayback() {
        player.pause()
        shuttleDirection = .paused
        shuttleRate = 1
    }

    private func shuttleForward() {
        if shuttleDirection == .forward {
            shuttleRate = min(shuttleRate * 2, 4)
        } else {
            shuttleDirection = .forward
            shuttleRate = 1
        }
        player.playImmediately(atRate: shuttleRate)
    }

    private func step(seconds: Double) {
        let destination = max(0, clock.currentTime + seconds)
        seek(to: destination)
        pausePlayback()
    }

    private func seek(to seconds: Double) {
        player.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
}

private enum ShuttleDirection {
    case paused
    case forward
    case reverse
}

struct RevisionTypePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    var timecode: Double
    var onChoose: (ReviewRevisionType) -> Void

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mark Revision")
                        .font(.system(size: 28, weight: .semibold))
                    Text("Choose the exact edit request for \(TimecodeFormatter.string(timecode)).")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ReviewRevisionType.allCases) { type in
                    Button {
                        onChoose(type)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: type.systemImage)
                                .font(.system(size: 22, weight: .semibold))
                                .foregroundStyle(StudioTheme.gold)
                                .frame(width: 30)

                            VStack(alignment: .leading, spacing: 5) {
                                Text(type.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Text(type.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                        .background(.regularMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(.white.opacity(0.10))
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(24)
        .frame(width: 760)
        .background(StudioTheme.background)
    }
}

struct ReviewRevisionCard: View {
    @Binding var mark: ReviewMark
    var currentTime: Double
    var onSeek: (Double) -> Void
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            cardHeader
            dynamicToolset
            noteField
        }
        .padding(14)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.10))
        )
    }

    private var cardHeader: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: mark.revisionType.systemImage)
                .foregroundStyle(StudioTheme.gold)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 3) {
                Text(mark.revisionType.title)
                    .font(.system(size: 15, weight: .semibold))
                Button {
                    onSeek(mark.timecodeSeconds)
                } label: {
                    Text(TimecodeFormatter.string(mark.timecodeSeconds))
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .foregroundStyle(StudioTheme.accent)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private var dynamicToolset: some View {
        switch mark.revisionType {
        case .videoProblem:
            Label("Agent should inspect this moment for visual artifacts, bad motion, malformed geometry, or framing problems.", systemImage: "eye")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .audioProblem:
            VStack(alignment: .leading, spacing: 6) {
                Text("Volume adjustment: \(mark.volumeDeltaDb, specifier: "%.1f") dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $mark.volumeDeltaDb, in: -18...6, step: 0.5)
            }
        case .speedRamp:
            VStack(alignment: .leading, spacing: 6) {
                Text("Playback speed target: \(mark.speedPercent)%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(
                    value: Binding(
                        get: { Double(mark.speedPercent) },
                        set: { mark.speedPercent = Int($0.rounded()) }
                    ),
                    in: 50...200,
                    step: 5
                )
            }
        case .trimClipStart, .trimClipEnd:
            trimControls
        case .titleFix:
            TextField("Replacement title or callout text", text: $mark.replacementTitle)
                .textFieldStyle(.roundedBorder)
        case .removeClip:
            Label("This mark requests deleting the source clip from the final assembly.", systemImage: "trash")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var trimControls: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                timePill("In", seconds: mark.trimInSeconds)
                Spacer()
                Button("Set In") {
                    mark.trimInSeconds = currentTime
                }
            }
            HStack {
                timePill("Out", seconds: mark.trimOutSeconds)
                Spacer()
                Button("Set Out") {
                    mark.trimOutSeconds = currentTime
                }
            }
        }
        .font(.caption)
    }

    private func timePill(_ label: String, seconds: Double?) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(seconds.map(TimecodeFormatter.string) ?? "--:--:--")
                .font(.system(.caption, design: .monospaced).weight(.semibold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(.black.opacity(0.20))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var noteField: some View {
        TextEditor(text: $mark.note)
            .frame(minHeight: 70)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(.black.opacity(0.18))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(alignment: .topLeading) {
                if mark.note.isEmpty {
                    Text("Notes / instructions")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
    }
}

struct MarkButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(configuration.isPressed ? StudioTheme.gold.opacity(0.72) : StudioTheme.gold)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct SubmitButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .background(configuration.isPressed ? StudioTheme.gold.opacity(0.72) : StudioTheme.gold)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
    }
}

@MainActor
final class PlayerClock: ObservableObject {
    @Published var currentTime: Double = 0
    private var observerHandle: Any?
    private weak var player: AVPlayer?

    func attach(to player: AVPlayer) {
        detach()
        self.player = player
        observerHandle = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.20, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor in
                self?.currentTime = time.seconds.isFinite ? time.seconds : 0
            }
        }
    }

    func detach() {
        if let observerHandle, let player {
            player.removeTimeObserver(observerHandle)
        }
        observerHandle = nil
        player = nil
    }
}
