import AppKit
import SwiftUI

struct ImageReviewView: View {
    @ObservedObject var store: StudioStore

    @State private var candidateSets: [ImageCandidateSet] = []
    @State private var selectedSetIndex = 0
    @State private var selectedCandidateID: UUID?
    @State private var previewCandidate: ImageCandidate?
    @State private var lastSavedSetKey: String?

    private var activeSet: ImageCandidateSet? {
        guard candidateSets.indices.contains(selectedSetIndex) else { return nil }
        return candidateSets[selectedSetIndex]
    }

    private var selectedCandidate: ImageCandidate? {
        guard let activeSet, let selectedCandidateID else { return nil }
        return activeSet.candidates.first { $0.id == selectedCandidateID }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()

            if store.imageCandidatesFolderURL == nil {
                emptyState(
                    title: "Choose A Candidate Folder",
                    message: "Pick an episode, then open that episode's images/source-stills/candidates folder."
                )
            } else if candidateSets.isEmpty {
                emptyState(
                    title: "No Candidate Sets Found",
                    message: "This folder needs image files grouped by shot number, or loose image files that can be reviewed in batches of five."
                )
            } else {
                reviewSurface
            }
        }
        .background(StudioTheme.background)
        .onAppear {
            if store.imageCandidatesFolderURL == nil {
                store.loadDefaultImageCandidatesFolder()
            }
            loadCandidates()
        }
        .onChange(of: store.imageCandidatesFolderURL) { _, _ in
            loadCandidates()
        }
        .sheet(item: $previewCandidate) { candidate in
            CandidatePreview(candidate: candidate)
        }
    }

    private var toolbar: some View {
        HStack(spacing: 12) {
            Button {
                store.chooseEpisodeFolder()
                store.loadDefaultImageCandidatesFolder()
                loadCandidates()
            } label: {
                Label("Episode", systemImage: "folder")
            }

            Button {
                store.chooseImageCandidatesFolder()
                loadCandidates()
            } label: {
                Label("Candidates", systemImage: "photo.stack")
            }
            .keyboardShortcut("o")

            Button {
                openFinalFolder()
            } label: {
                Label("Open Final", systemImage: "checkmark.rectangle.stack")
            }
            .disabled(store.episodeFolderURL == nil)

            Spacer()

            if let activeSet {
                Text("\(activeSet.title)  ·  \(selectedSetIndex + 1) of \(candidateSets.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.bar)
    }

    private var reviewSurface: some View {
        VStack(spacing: 0) {
            if let activeSet {
                GeometryReader { geometry in
                    let columnCount = geometry.size.width > 1420 ? 3 : 2
                    let columns = Array(
                        repeating: GridItem(.flexible(minimum: 320), spacing: 14),
                        count: columnCount
                    )

                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 14) {
                            ForEach(activeSet.candidates) { candidate in
                                CandidateCard(
                                    candidate: candidate,
                                    isSelected: selectedCandidateID == candidate.id
                                )
                                .onTapGesture {
                                    selectedCandidateID = candidate.id
                                }
                                .onTapGesture(count: 2) {
                                    previewCandidate = candidate
                                }
                            }
                        }
                        .padding(18)
                    }
                }
            }

            Divider()
            actionBar
        }
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                moveSet(by: -1)
            } label: {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(selectedSetIndex == 0)

            Button {
                moveSet(by: 1)
            } label: {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(selectedSetIndex >= candidateSets.count - 1)

            Spacer()

            if let selectedCandidate {
                Text("Selected \(selectedCandidate.label)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            } else {
                Text("Select A-E")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Button {
                submitWinner()
            } label: {
                Label(lastSavedSetKey == activeSet?.key ? "Saved" : "Submit Winner", systemImage: lastSavedSetKey == activeSet?.key ? "checkmark.circle.fill" : "arrow.down.doc.fill")
                    .font(.system(size: 15, weight: .bold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
            }
            .buttonStyle(.borderedProminent)
            .tint(StudioTheme.gold)
            .disabled(selectedCandidate == nil || activeSet == nil)
        }
        .padding(16)
        .background(.bar)
    }

    private func emptyState(title: String, message: String) -> some View {
        VStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 56, weight: .light))
                .foregroundStyle(.secondary)
            Text(title)
                .font(.system(size: 24, weight: .semibold))
            Text(message)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 560)
            Button {
                store.chooseImageCandidatesFolder()
                loadCandidates()
            } label: {
                Label("Choose Candidates", systemImage: "photo.stack")
            }
            .buttonStyle(.borderedProminent)
            .tint(StudioTheme.gold)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }

    private func loadCandidates() {
        guard let folder = store.imageCandidatesFolderURL else {
            candidateSets = []
            selectedCandidateID = nil
            return
        }

        do {
            candidateSets = try ImageCandidateScanner.scan(folder: folder)
            selectedSetIndex = min(selectedSetIndex, max(candidateSets.count - 1, 0))
            selectedCandidateID = activeSet?.candidates.first?.id
            lastSavedSetKey = nil
            store.status = candidateSets.isEmpty
                ? "No image candidate sets found."
                : "Loaded \(candidateSets.count) image candidate set\(candidateSets.count == 1 ? "" : "s")."
        } catch {
            candidateSets = []
            selectedCandidateID = nil
            store.status = "Could not load image candidates: \(error.localizedDescription)"
        }
    }

    private func moveSet(by offset: Int) {
        let nextIndex = min(max(selectedSetIndex + offset, 0), max(candidateSets.count - 1, 0))
        selectedSetIndex = nextIndex
        selectedCandidateID = activeSet?.candidates.first?.id
        lastSavedSetKey = nil
    }

    private func submitWinner() {
        guard let activeSet, let selectedCandidate, let episodeFolder = store.episodeFolderURL else {
            store.status = "Choose an episode and candidate first."
            return
        }

        let finalFolder = episodeFolder
            .appendingPathComponent("images/source-stills/Final", isDirectory: true)
        let targetExtension = selectedCandidate.url.pathExtension.isEmpty ? "png" : selectedCandidate.url.pathExtension
        let finalURL = finalFolder
            .appendingPathComponent("\(activeSet.key)_final")
            .appendingPathExtension(targetExtension)

        do {
            try FileManager.default.createDirectory(at: finalFolder, withIntermediateDirectories: true)
            try removePreviousFinals(for: activeSet.key, in: finalFolder)
            try FileManager.default.copyItem(at: selectedCandidate.url, to: finalURL)
            try saveDecision(
                set: activeSet,
                candidate: selectedCandidate,
                finalURL: finalURL,
                finalFolder: finalFolder
            )
            lastSavedSetKey = activeSet.key
            store.status = "Saved \(activeSet.title) winner \(selectedCandidate.label) to Final."
            moveSet(by: 1)
        } catch {
            store.status = "Could not save image review winner: \(error.localizedDescription)"
        }
    }

    private func removePreviousFinals(for setKey: String, in finalFolder: URL) throws {
        let existing = try? FileManager.default.contentsOfDirectory(
            at: finalFolder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        for file in existing ?? [] {
            if file.deletingPathExtension().lastPathComponent == "\(setKey)_final" {
                try FileManager.default.removeItem(at: file)
            }
        }
    }

    private func saveDecision(
        set: ImageCandidateSet,
        candidate: ImageCandidate,
        finalURL: URL,
        finalFolder: URL
    ) throws {
        let logURL = finalFolder.appendingPathComponent("image-review-decisions.json")
        let now = ISO8601DateFormatter().string(from: Date())
        var record: ImageReviewDecisionRecord

        if let data = try? Data(contentsOf: logURL),
           let decoded = try? JSONDecoder().decode(ImageReviewDecisionRecord.self, from: data) {
            record = decoded
        } else {
            record = ImageReviewDecisionRecord(
                episodeID: store.sidecar.episodeID,
                workingTitle: store.sidecar.workingTitle,
                candidatesFolder: store.imageCandidatesFolderURL?.path ?? "",
                finalFolder: finalFolder.path,
                updatedAt: now,
                decisions: []
            )
        }

        record.episodeID = store.sidecar.episodeID
        record.workingTitle = store.sidecar.workingTitle
        record.candidatesFolder = store.imageCandidatesFolderURL?.path ?? ""
        record.finalFolder = finalFolder.path
        record.updatedAt = now
        record.decisions.removeAll { $0.setKey == set.key }
        record.decisions.append(
            ImageReviewDecision(
                setKey: set.key,
                setTitle: set.title,
                selectedLabel: candidate.label,
                sourcePath: candidate.url.path,
                finalPath: finalURL.path,
                decidedAt: now
            )
        )
        record.decisions.sort { $0.setKey < $1.setKey }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(record).write(to: logURL)
    }

    private func openFinalFolder() {
        guard let episodeFolder = store.episodeFolderURL else { return }
        let finalFolder = episodeFolder
            .appendingPathComponent("images/source-stills/Final", isDirectory: true)
        try? FileManager.default.createDirectory(at: finalFolder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(finalFolder)
    }
}

private struct CandidateCard: View {
    var candidate: ImageCandidate
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                CandidateImage(url: candidate.url)
                    .aspectRatio(16 / 9, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .background(Color.black.opacity(0.35))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Text(candidate.label)
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(StudioTheme.gold)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                    .padding(10)

                if isSelected {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 30, weight: .bold))
                                .foregroundStyle(StudioTheme.gold)
                                .shadow(radius: 4)
                                .padding(10)
                        }
                        Spacer()
                    }
                }
            }

            Text(candidate.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(10)
        .background(isSelected ? StudioTheme.gold.opacity(0.14) : Color.white.opacity(0.045))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(isSelected ? StudioTheme.gold : Color.white.opacity(0.10), lineWidth: isSelected ? 3 : 1)
        }
    }
}

private struct CandidateImage: View {
    var url: URL

    var body: some View {
        if let image = NSImage(contentsOf: url) {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
        } else {
            ZStack {
                Color.black.opacity(0.35)
                Image(systemName: "exclamationmark.triangle")
                    .font(.largeTitle)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CandidatePreview: View {
    var candidate: ImageCandidate

    var body: some View {
        VStack(spacing: 12) {
            CandidateImage(url: candidate.url)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
            Text(candidate.fileName)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(16)
        .frame(minWidth: 900, minHeight: 620)
        .background(StudioTheme.background)
    }
}

private struct ImageCandidateSet: Identifiable {
    var id: String { key }
    var key: String
    var title: String
    var candidates: [ImageCandidate]
}

private struct ImageCandidate: Identifiable {
    let id = UUID()
    var label: String
    var url: URL

    var fileName: String {
        url.lastPathComponent
    }
}

private struct ImageReviewDecisionRecord: Codable {
    var episodeID: String
    var workingTitle: String
    var candidatesFolder: String
    var finalFolder: String
    var updatedAt: String
    var decisions: [ImageReviewDecision]
}

private struct ImageReviewDecision: Codable {
    var setKey: String
    var setTitle: String
    var selectedLabel: String
    var sourcePath: String
    var finalPath: String
    var decidedAt: String
}

private enum ImageCandidateScanner {
    private static let imageExtensions: Set<String> = [
        "png", "jpg", "jpeg", "heic", "heif", "tif", "tiff", "webp"
    ]

    static func scan(folder: URL) throws -> [ImageCandidateSet] {
        let files = try FileManager.default.contentsOfDirectory(
            at: folder,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }

        guard !files.isEmpty else { return [] }

        let keyedFiles = files.compactMap { file -> (String, URL)? in
            guard let key = shotKey(for: file) else { return nil }
            return (key, file)
        }

        if keyedFiles.count >= files.count / 2 {
            return groupKeyedFiles(keyedFiles)
        }

        return groupLooseFiles(files)
    }

    private static func groupKeyedFiles(_ keyedFiles: [(String, URL)]) -> [ImageCandidateSet] {
        var order: [String] = []
        var groups: [String: [URL]] = [:]

        for (key, file) in keyedFiles {
            if groups[key] == nil {
                order.append(key)
            }
            groups[key, default: []].append(file)
        }

        return order.map { key in
            let files = (groups[key] ?? [])
                .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            return ImageCandidateSet(
                key: key,
                title: title(for: key),
                candidates: files.enumerated().map { index, url in
                    ImageCandidate(label: optionLabel(for: url, fallbackIndex: index), url: url)
                }
            )
        }
    }

    private static func groupLooseFiles(_ files: [URL]) -> [ImageCandidateSet] {
        var sets: [ImageCandidateSet] = []
        var start = 0
        var setNumber = 1

        while start < files.count {
            let chunk = Array(files[start..<min(start + 5, files.count)])
            let key = String(format: "set-%02d", setNumber)
            sets.append(
                ImageCandidateSet(
                    key: key,
                    title: "Set \(setNumber)",
                    candidates: chunk.enumerated().map { index, url in
                        ImageCandidate(label: optionLabel(for: url, fallbackIndex: index), url: url)
                    }
                )
            )
            start += 5
            setNumber += 1
        }

        return sets
    }

    private static func shotKey(for url: URL) -> String? {
        let name = url.deletingPathExtension().lastPathComponent
        if let key = firstCapture(in: name, pattern: #"([A-Za-z]{2,}-\d{3,}_\d{2})"#) {
            return key.uppercased()
        }
        if let number = firstCapture(in: name, pattern: #"(?i)(?:shot|still|image|frame)[-_\s]?(\d{1,2})"#) {
            return String(format: "shot-%02d", Int(number) ?? 0)
        }
        return nil
    }

    private static func optionLabel(for url: URL, fallbackIndex: Int) -> String {
        let name = url.deletingPathExtension().lastPathComponent
        if let label = firstCapture(in: name, pattern: #"(?i)(?:option|variant|candidate|version)[-_\s]?([A-Z])"#) {
            return label.uppercased()
        }
        let unicode = UnicodeScalar(65 + max(0, min(fallbackIndex, 25))) ?? UnicodeScalar("A")
        return String(Character(unicode))
    }

    private static func title(for key: String) -> String {
        if let shot = firstCapture(in: key, pattern: #"_(\d{2})$"#) {
            return "Shot \(shot)"
        }
        if let shot = firstCapture(in: key, pattern: #"shot-(\d{2})"#) {
            return "Shot \(shot)"
        }
        return key
    }

    private static func firstCapture(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges > 1,
              let captureRange = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[captureRange])
    }
}
