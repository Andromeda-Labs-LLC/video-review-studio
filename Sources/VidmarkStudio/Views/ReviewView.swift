import AppKit
import AVFoundation
import SwiftUI

struct ReviewView: View {
    @ObservedObject var store: StudioStore
    @StateObject private var clock = PlayerClock()
    @State private var player = AVPlayer()
    @State private var showRevisionPicker = false
    @State private var isTheaterMode = false
    @State private var fullScreenTrigger = 0
    @State private var isPlaying = false
    @State private var frameStepTarget: CMTime?
    @State private var frameDuration = CMTime(value: 1, timescale: 24)
    @State private var showNewReviewConfirmation = false

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
        .confirmationDialog(
            "Start a new review?",
            isPresented: $showNewReviewConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start New Review", role: .destructive) {
                store.startNewReview()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the visible revision cards and removes generated review packet and assembly setting files for the selected episode. Media files are left untouched.")
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
                showNewReviewConfirmation = true
            } label: {
                Label("New Review", systemImage: "arrow.counterclockwise")
            }
            .disabled(store.reviewMarks.isEmpty && store.episodeFolderURL == nil)

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
                subtitle: "-1 FR",
                systemImage: "backward.frame.fill",
                action: stepBackwardOneFrame
            )
            .keyboardShortcut("j", modifiers: [])

            shuttleButton(
                title: "K",
                subtitle: isPlaying ? "PAUSE" : "PLAY",
                systemImage: isPlaying ? "pause.fill" : "play.fill",
                action: togglePlayback
            )
            .keyboardShortcut("k", modifiers: [])

            shuttleButton(
                title: "L",
                subtitle: "+1 FR",
                systemImage: "forward.frame.fill",
                action: stepForwardOneFrame
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
                                audioLibraryURL: store.audioLibraryURL,
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
        isPlaying ? "Playing" : "Paused - J/L step one frame"
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
            frameStepTarget = nil
            player.replaceCurrentItem(with: nil)
            return
        }
        let item = AVPlayerItem(url: url)
        item.preferredForwardBufferDuration = 1
        player.automaticallyWaitsToMinimizeStalling = false
        player.replaceCurrentItem(with: item)
        refreshFrameDuration(for: item)
        frameStepTarget = nil
        clock.attach(to: player)
        pausePlayback()
    }

    private func openRevisionPicker() {
        pausePlayback()
        showRevisionPicker = true
    }

    private func pausePlayback() {
        player.pause()
        isPlaying = false
        let currentSeconds = player.currentTime().seconds
        if currentSeconds.isFinite {
            clock.currentTime = currentSeconds
        }
    }

    private func togglePlayback() {
        frameStepTarget = nil
        if isPlaying {
            pausePlayback()
        } else {
            player.playImmediately(atRate: 1)
            isPlaying = true
        }
    }

    private func stepBackwardOneFrame() {
        stepOneFrame(direction: -1)
    }

    private func stepForwardOneFrame() {
        stepOneFrame(direction: 1)
    }

    private func stepOneFrame(direction: Int32) {
        guard store.masterVideoURL != nil else { return }
        pausePlayback()

        let baseTime = frameStepTarget ?? player.currentTime()
        let delta = CMTimeMultiply(frameDuration, multiplier: direction)
        let duration = player.currentItem?.duration
        var target = CMTimeAdd(baseTime, delta)

        if target < .zero {
            target = .zero
        }

        if let duration, duration.isNumeric, target > duration {
            target = duration
        }

        frameStepTarget = target
        clock.currentTime = target.seconds.isFinite ? target.seconds : clock.currentTime
        let targetSeconds = target.seconds
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            guard finished else { return }
            Task { @MainActor in
                if self.frameStepTarget?.seconds == targetSeconds {
                    self.frameStepTarget = nil
                }
                self.clock.currentTime = targetSeconds.isFinite ? targetSeconds : self.clock.currentTime
            }
        }
    }

    private func step(seconds: Double) {
        let destination = max(0, clock.currentTime + seconds)
        seek(to: destination)
        pausePlayback()
    }

    private func seek(to seconds: Double) {
        frameStepTarget = nil
        let target = CMTime(seconds: seconds, preferredTimescale: 600)
        player.seek(to: target, toleranceBefore: .zero, toleranceAfter: .zero)
        clock.currentTime = seconds
    }

    private func refreshFrameDuration(for item: AVPlayerItem) {
        frameDuration = CMTime(value: 1, timescale: 24)
        Task {
            do {
                let tracks = try await item.asset.loadTracks(withMediaType: .video)
                guard let videoTrack = tracks.first else { return }
                let nominalFrameRate = try await videoTrack.load(.nominalFrameRate)
                let fps = nominalFrameRate > 0 ? Double(nominalFrameRate) : 24
                let detectedFrameDuration = CMTime(seconds: 1 / fps, preferredTimescale: 600)
                await MainActor.run {
                    guard player.currentItem === item else { return }
                    frameDuration = detectedFrameDuration
                }
            } catch {
                await MainActor.run {
                    guard player.currentItem === item else { return }
                    frameDuration = CMTime(value: 1, timescale: 24)
                }
            }
        }
    }
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
    var audioLibraryURL: URL
    var onSeek: (Double) -> Void
    var onDelete: () -> Void
    @State private var showSFXPicker = false

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
        .sheet(isPresented: $showSFXPicker) {
            SFXPickerSheet(
                libraryURL: audioLibraryURL,
                selectedPath: mark.replacementSFXPath,
                onChoose: { url in
                    mark.replacementSFXPath = url.path
                    showSFXPicker = false
                }
            )
        }
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
            VStack(alignment: .leading, spacing: 10) {
                Text("Volume adjustment: \(mark.volumeDeltaDb, specifier: "%.1f") dB")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Slider(value: $mark.volumeDeltaDb, in: -18...6, step: 0.5)

                Button {
                    showSFXPicker = true
                } label: {
                    Label("Swap SFX", systemImage: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(YellowPillButtonStyle())

                VStack(alignment: .leading, spacing: 6) {
                    Text(mark.replacementSFXPath.isEmpty ? "No replacement SFX selected" : URL(fileURLWithPath: mark.replacementSFXPath).lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(mark.replacementSFXPath.isEmpty ? .secondary : StudioTheme.gold)
                        .lineLimit(2)
                        .textSelection(.enabled)

                    TextField("SFX swap note, target sound, or mix instruction", text: $mark.sfxNote, axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .lineLimit(2...4)
                }
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

private struct SFXCandidate: Identifiable, Equatable {
    let url: URL
    let relativePath: String

    var id: String { url.path }
    var fileName: String { url.lastPathComponent }
}

struct SFXPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let libraryURL: URL
    var selectedPath: String
    var onChoose: (URL) -> Void

    @State private var candidates: [SFXCandidate] = []
    @State private var selectedURL: URL?
    @State private var query = ""
    @State private var loadMessage = "Scanning sound effects..."
    @State private var previewPlayer: AVPlayer?
    @State private var previewingURL: URL?

    private var filteredCandidates: [SFXCandidate] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return candidates }
        return candidates.filter {
            $0.relativePath.localizedCaseInsensitiveContains(trimmed)
            || $0.fileName.localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Swap SFX")
                        .font(.system(size: 28, weight: .semibold))
                    Text(libraryURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }

                Spacer()

                Button {
                    stopPreview()
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
            }

            HStack(spacing: 10) {
                TextField("Search filename, folder, mood, or tag", text: $query)
                    .textFieldStyle(.roundedBorder)

                Button {
                    loadCandidates()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }

                Button {
                    NSWorkspace.shared.open(libraryURL)
                } label: {
                    Label("Open Folder", systemImage: "folder")
                }
            }

            if filteredCandidates.isEmpty {
                ContentUnavailableView(
                    "No SFX Found",
                    systemImage: "waveform.slash",
                    description: Text(loadMessage)
                )
                .frame(maxWidth: .infinity, minHeight: 280)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(filteredCandidates) { candidate in
                            sfxRow(candidate)
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(minHeight: 320)
                .background(.black.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            HStack {
                if let selectedURL {
                    Text(selectedURL.lastPathComponent)
                        .font(.caption)
                        .foregroundStyle(StudioTheme.gold)
                        .lineLimit(1)
                } else {
                    Text("Select a sound effect, preview it, then use it on this mark.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Cancel") {
                    stopPreview()
                    dismiss()
                }

                Button {
                    guard let selectedURL else { return }
                    stopPreview()
                    onChoose(selectedURL)
                } label: {
                    Text("Use Selected SFX")
                        .fontWeight(.bold)
                }
                .buttonStyle(YellowPillButtonStyle())
                .disabled(selectedURL == nil)
            }
        }
        .padding(24)
        .frame(width: 820, height: 620)
        .background(StudioTheme.background)
        .onAppear {
            if selectedURL == nil, !selectedPath.isEmpty {
                selectedURL = URL(fileURLWithPath: selectedPath)
            }
            loadCandidates()
        }
        .onDisappear(perform: stopPreview)
    }

    private func sfxRow(_ candidate: SFXCandidate) -> some View {
        HStack(spacing: 10) {
            Button {
                selectedURL = candidate.url
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: selectedURL == candidate.url ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(selectedURL == candidate.url ? StudioTheme.gold : .secondary)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(candidate.fileName)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(candidate.relativePath)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                togglePreview(candidate.url)
            } label: {
                Image(systemName: previewingURL == candidate.url ? "stop.fill" : "play.fill")
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.bordered)
            .help(previewingURL == candidate.url ? "Stop preview" : "Play preview")
        }
        .padding(10)
        .background(selectedURL == candidate.url ? StudioTheme.gold.opacity(0.14) : .white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func loadCandidates() {
        let audioExtensions: Set<String> = [
            "aif", "aiff", "caf", "flac", "m4a", "mp3", "mp4", "ogg", "wav"
        ]
        guard FileManager.default.fileExists(atPath: libraryURL.path) else {
            candidates = []
            loadMessage = "The selected audio library folder does not exist yet."
            return
        }

        let enumerator = FileManager.default.enumerator(
            at: libraryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )

        let loaded = (enumerator?.compactMap { item -> SFXCandidate? in
            guard let url = item as? URL else { return nil }
            let ext = url.pathExtension.lowercased()
            guard audioExtensions.contains(ext) else { return nil }
            let values = try? url.resourceValues(forKeys: [.isRegularFileKey])
            guard values?.isRegularFile == true else { return nil }
            return SFXCandidate(url: url, relativePath: relativePath(for: url))
        } ?? [])
        .sorted { $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending }

        candidates = loaded
        loadMessage = loaded.isEmpty ? "No supported audio files were found in this library." : "\(loaded.count) sound effect files found."
    }

    private func relativePath(for url: URL) -> String {
        let root = libraryURL.standardizedFileURL.path
        let path = url.standardizedFileURL.path
        guard path.hasPrefix(root) else { return url.lastPathComponent }
        return String(path.dropFirst(root.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private func togglePreview(_ url: URL) {
        if previewingURL == url {
            stopPreview()
            return
        }

        stopPreview()
        selectedURL = url
        let player = AVPlayer(url: url)
        previewPlayer = player
        previewingURL = url
        player.play()
    }

    private func stopPreview() {
        previewPlayer?.pause()
        previewPlayer = nil
        previewingURL = nil
    }
}

struct YellowPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(configuration.isPressed ? StudioTheme.gold.opacity(0.72) : StudioTheme.gold)
            .foregroundStyle(.black)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .opacity(configuration.isPressed ? 0.9 : 1)
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
            forInterval: CMTime(seconds: 0.10, preferredTimescale: 600),
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
