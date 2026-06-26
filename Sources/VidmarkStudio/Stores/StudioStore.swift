import AppKit
import Foundation

@MainActor
final class StudioStore: ObservableObject {
    @Published var selectedSection: StudioSection = .review
    @Published var sidecar = EpisodeSidecar()
    @Published var assembly = AssemblySettings()
    @Published var episodeFolderURL: URL?
    @Published var masterVideoURL: URL?
    @Published var imageCandidatesFolderURL: URL?
    @Published var audioLibraryURL: URL = ProjectPaths.audioLibraryRoot
    @Published var reviewMarks: [ReviewMark] = []
    @Published var reviewFrameRate: Double = 24
    @Published var status = "Ready."

    var generatedPrompt: String {
        sidecar.episodePrompt
    }

    var episodeRootForDisplay: String {
        episodeFolderURL?.path ?? "No episode folder selected"
    }

    var reviewMetadataSummary: String {
        let episode = "\(sidecar.episodeID) · \(sidecar.workingTitle)"
        guard let masterVideoURL else { return episode }
        return "\(episode) · \(masterVideoURL.lastPathComponent)"
    }

    func createEpisodeFolder() {
        let root = ProjectPaths.videosRoot
            .appendingPathComponent(sidecar.folderName, isDirectory: true)

        let folders = [
            "images/source-stills/candidates",
            "images/source-stills/Final",
            "video-generations/drafts",
            "video-generations/approved",
            "masters/drafts",
            "masters/final",
            "masters/shorts",
            "audio/stems",
            "audio/mix",
            "assembly/manifests",
            "shorts/reframer-candidates",
            "shorts/approved",
            "thumbnails/candidates",
            "metadata",
            "prompts",
            "qa/reviewer-notes"
        ]

        do {
            for folder in folders {
                try FileManager.default.createDirectory(
                    at: root.appendingPathComponent(folder, isDirectory: true),
                    withIntermediateDirectories: true
                )
            }
            episodeFolderURL = root
            try saveSidecar()
            status = "Episode folder created."
        } catch {
            status = "Could not create episode folder: \(error.localizedDescription)"
        }
    }

    func saveSidecar() throws {
        syncMetadataFromSelection()
        guard let episodeFolderURL else {
            status = "Choose or create an episode folder first."
            return
        }
        let promptDir = episodeFolderURL.appendingPathComponent("prompts", isDirectory: true)
        try FileManager.default.createDirectory(at: promptDir, withIntermediateDirectories: true)
        let jsonURL = promptDir.appendingPathComponent("\(sidecar.episodeID)_episode-sidecar.json")
        let promptURL = promptDir.appendingPathComponent("\(sidecar.episodeID)_master-plus-sidecar-prompt.md")
        try Self.encoder.encode(sidecar).write(to: jsonURL)
        try ("# Master Plus Episode Sidecar Prompt\n\n" + generatedPrompt + "\n")
            .write(to: promptURL, atomically: true, encoding: .utf8)
        status = "Saved sidecar and prompt."
    }

    func exportReviewPackage() {
        do {
            _ = try writeReviewPackage()
            status = "Exported reviewer notes package."
        } catch {
            status = "Could not export review package: \(error.localizedDescription)"
        }
    }

    func submitReviewPackage() {
        do {
            let result = try writeReviewPackage()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(result.markdown, forType: .string)
            status = "Submitted revision packet. It is saved and copied to the clipboard."
        } catch {
            status = "Could not submit review package: \(error.localizedDescription)"
        }
    }

    func startNewReview() {
        reviewMarks.removeAll()
        removeGeneratedReviewOutputs()
        sidecar = EpisodeSidecar()
        assembly = AssemblySettings()
        episodeFolderURL = nil
        masterVideoURL = nil
        imageCandidatesFolderURL = nil
        reviewFrameRate = 24
        selectedSection = .review
        status = "Started a clean review. Project state, selected master, marks, and generated packets were cleared."
    }

    private func writeReviewPackage() throws -> (jsonURL: URL, markdownURL: URL, markdown: String) {
        syncMetadataFromSelection()
        guard let episodeFolderURL else {
            status = "Choose or create an episode folder first."
            throw StudioStoreError.missingEpisodeFolder
        }
        let reviewDir = episodeFolderURL.appendingPathComponent("qa/reviewer-notes", isDirectory: true)
        try FileManager.default.createDirectory(at: reviewDir, withIntermediateDirectories: true)
        let package = ReviewPackage(
            episodeID: sidecar.episodeID,
            workingTitle: sidecar.workingTitle,
            masterVideo: masterVideoURL?.path ?? "",
            timecodeFrameRate: reviewFrameRate,
            generatedAt: Date(),
            reviewMarks: reviewMarks.sorted { $0.timecodeSeconds < $1.timecodeSeconds },
            assemblySettings: assembly
        )
        let jsonURL = reviewDir.appendingPathComponent("\(sidecar.episodeID)_review-marks.json")
        let mdURL = reviewDir.appendingPathComponent("\(sidecar.episodeID)_review-marks.md")
        try Self.encoder.encode(package).write(to: jsonURL)
        try package.markdown.write(to: mdURL, atomically: true, encoding: .utf8)
        return (jsonURL, mdURL, package.markdown)
    }

    func exportAssemblySettings() {
        guard let episodeFolderURL else {
            status = "Choose or create an episode folder first."
            return
        }
        let manifestDir = episodeFolderURL.appendingPathComponent("assembly/manifests", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: manifestDir, withIntermediateDirectories: true)
            let manifest = StudioAssemblyManifest(
                episodeID: sidecar.episodeID,
                workingTitle: sidecar.workingTitle,
                masterVideo: masterVideoURL?.path ?? "",
                audioLibrary: audioLibraryURL.path,
                settings: assembly,
                reviewMarks: reviewMarks.sorted { $0.timecodeSeconds < $1.timecodeSeconds }
            )
            let jsonURL = manifestDir.appendingPathComponent("\(sidecar.episodeID)_studio-assembly-settings.json")
            try Self.encoder.encode(manifest).write(to: jsonURL)
            status = "Exported assembly settings."
        } catch {
            status = "Could not export assembly settings: \(error.localizedDescription)"
        }
    }

    func addReviewMark(_ mark: ReviewMark) {
        reviewMarks.append(mark)
        reviewMarks.sort { $0.timecodeSeconds < $1.timecodeSeconds }
        status = "Added mark at \(TimecodeFormatter.string(mark.timecodeSeconds))."
    }

    func deleteReviewMarks(at offsets: IndexSet) {
        reviewMarks.remove(atOffsets: offsets)
    }

    func deleteReviewMark(id: ReviewMark.ID) {
        reviewMarks.removeAll { $0.id == id }
        status = "Removed revision mark."
    }

    func chooseEpisodeFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Episode Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        try? FileManager.default.createDirectory(at: ProjectPaths.videosRoot, withIntermediateDirectories: true)
        panel.directoryURL = ProjectPaths.videosRoot
        if panel.runModal() == .OK, let url = panel.url {
            episodeFolderURL = url
            syncMetadataFromSelection()
            status = "Selected episode folder: \(sidecar.episodeID)."
        }
    }

    func chooseMasterVideo() {
        let panel = NSOpenPanel()
        panel.title = "Choose Master Video"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.directoryURL = defaultMasterFolder() ?? episodeFolderURL ?? ProjectPaths.videosRoot
        if panel.runModal() == .OK, let url = panel.url {
            masterVideoURL = url
            if episodeFolderURL == nil {
                episodeFolderURL = ProjectPaths.inferEpisodeFolder(from: url)
            }
            syncMetadataFromSelection()
            status = "Selected master video for \(sidecar.episodeID)."
        }
    }

    func chooseImageCandidatesFolder() {
        let panel = NSOpenPanel()
        panel.title = "Choose Image Candidates Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = defaultImageCandidatesFolder() ?? episodeFolderURL ?? ProjectPaths.videosRoot
        if panel.runModal() == .OK, let url = panel.url {
            imageCandidatesFolderURL = url
            if episodeFolderURL == nil {
                episodeFolderURL = ProjectPaths.inferEpisodeFolder(from: url)
            }
            syncMetadataFromSelection()
            status = "Selected image candidates folder."
        }
    }

    func loadDefaultImageCandidatesFolder() {
        guard let folder = defaultImageCandidatesFolder() else {
            status = "Choose an episode folder first."
            return
        }
        imageCandidatesFolderURL = folder
        status = "Loaded image candidates folder."
    }

    func chooseAudioLibrary() {
        let panel = NSOpenPanel()
        panel.title = "Choose Audio Library"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = audioLibraryURL
        if panel.runModal() == .OK, let url = panel.url {
            audioLibraryURL = url
            ProjectPaths.setAudioLibraryRoot(url)
            status = "Selected audio library."
        }
    }

    func copyPromptToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(generatedPrompt, forType: .string)
        status = "Copied prompt to clipboard."
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return encoder
    }

    private func syncMetadataFromSelection() {
        if episodeFolderURL == nil, let masterVideoURL {
            episodeFolderURL = ProjectPaths.inferEpisodeFolder(from: masterVideoURL)
        }
        if episodeFolderURL == nil, let imageCandidatesFolderURL {
            episodeFolderURL = ProjectPaths.inferEpisodeFolder(from: imageCandidatesFolderURL)
        }
        guard let episodeFolderURL else { return }
        let metadata = ProjectPaths.metadata(
            forEpisodeFolder: episodeFolderURL,
            masterVideo: masterVideoURL
        )
        sidecar.episodeID = metadata.episodeID
        sidecar.workingTitle = metadata.workingTitle
        sidecar.slug = metadata.slug
    }

    private func defaultImageCandidatesFolder() -> URL? {
        episodeFolderURL?
            .appendingPathComponent("images/source-stills/candidates", isDirectory: true)
    }

    private func defaultMasterFolder() -> URL? {
        guard let episodeFolderURL else { return nil }
        let finalMasters = episodeFolderURL.appendingPathComponent("masters/final", isDirectory: true)
        if FileManager.default.fileExists(atPath: finalMasters.path) {
            return finalMasters
        }

        let draftMasters = episodeFolderURL.appendingPathComponent("masters/drafts", isDirectory: true)
        if FileManager.default.fileExists(atPath: draftMasters.path) {
            return draftMasters
        }

        return episodeFolderURL.appendingPathComponent("masters", isDirectory: true)
    }

    private func removeGeneratedReviewOutputs() {
        guard let episodeFolderURL else { return }
        let outputDirectories = [
            episodeFolderURL.appendingPathComponent("qa/reviewer-notes", isDirectory: true),
            episodeFolderURL.appendingPathComponent("assembly/manifests", isDirectory: true)
        ]
        let removableNameFragments = [
            "_review-marks",
            "_studio-assembly-settings"
        ]

        for directory in outputDirectories {
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: nil
            ) else { continue }

            for file in files where removableNameFragments.contains(where: { file.lastPathComponent.contains($0) }) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
}

enum StudioStoreError: LocalizedError {
    case missingEpisodeFolder

    var errorDescription: String? {
        switch self {
        case .missingEpisodeFolder: "Choose or create an episode folder first."
        }
    }
}

struct ReviewPackage: Codable {
    var episodeID: String
    var workingTitle: String
    var masterVideo: String
    var timecodeFrameRate: Double
    var generatedAt: Date
    var reviewMarks: [ReviewMark]
    var assemblySettings: AssemblySettings

    var markdown: String {
        var lines: [String] = [
            "# Revision Request Packet: \(episodeID)",
            "",
            "- Title: \(workingTitle)",
            "- Master video: `\(masterVideo)`",
            "- Timecode frame rate: \(String(format: "%.3g", timecodeFrameRate)) fps",
            "- Generated: \(generatedAt)",
            "",
            "## Rules",
            "",
            "- Visual edits remain hard cuts only.",
            "- Audio uses hard cuts aligned to visual edits, with loudness normalization and peak control.",
            "- Speed correction is allowed only for marks that explicitly request it.",
            "- Thumbnail marks request a full-resolution 1920x1080 PNG still exported from the exact marked frame.",
            "- Regenerate Video marks request a fresh source clip re-roll through the Miniature Places image-to-video protocol, normally Kling 3.0 API, before replacing the marked clip.",
            "",
            "## Marks",
            "",
            "| # | Timecode | Type | Trim In | Trim Out | Speed | Volume | Replacement Title | Replacement SFX | SFX Note | Notes |",
            "| ---: | --- | --- | --- | --- | ---: | ---: | --- | --- | --- | --- |"
        ]
        for (index, mark) in reviewMarks.enumerated() {
            lines.append(
                "| \(index + 1) | \(TimecodeFormatter.string(mark.timecodeSeconds, frameRate: timecodeFrameRate)) | \(mark.revisionType.title) | \(optionalTimecode(mark.trimInSeconds)) | \(optionalTimecode(mark.trimOutSeconds)) | \(mark.speedPercent)% | \(String(format: "%.1f dB", mark.volumeDeltaDb)) | \(sanitize(mark.replacementTitle)) | \(sanitize(mark.replacementSFXPath)) | \(sanitize(mark.sfxNote)) | \(sanitize(mark.note)) |"
            )
        }
        return lines.joined(separator: "\n") + "\n"
    }

    private func optionalTimecode(_ seconds: Double?) -> String {
        guard let seconds else { return "" }
        return TimecodeFormatter.string(seconds, frameRate: timecodeFrameRate)
    }

    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "|", with: "/")
    }
}

struct StudioAssemblyManifest: Codable {
    var episodeID: String
    var workingTitle: String
    var masterVideo: String
    var audioLibrary: String
    var settings: AssemblySettings
    var reviewMarks: [ReviewMark]
}
