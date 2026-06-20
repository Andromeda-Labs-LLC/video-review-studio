import AppKit
import Foundation

@MainActor
final class StudioStore: ObservableObject {
    @Published var selectedSection: StudioSection = .episode
    @Published var sidecar = EpisodeSidecar()
    @Published var assembly = AssemblySettings()
    @Published var episodeFolderURL: URL?
    @Published var masterVideoURL: URL?
    @Published var audioLibraryURL: URL = ProjectPaths.audioLibraryRoot
    @Published var reviewMarks: [ReviewMark] = []
    @Published var status = "Ready."

    var generatedPrompt: String {
        sidecar.episodePrompt
    }

    var episodeRootForDisplay: String {
        episodeFolderURL?.path ?? "No episode folder selected"
    }

    func createEpisodeFolder() {
        let root = ProjectPaths.videosRoot
            .appendingPathComponent(sidecar.folderName, isDirectory: true)

        let folders = [
            "images/source-stills",
            "video-generations/drafts",
            "video-generations/approved",
            "masters/drafts",
            "masters/final",
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
        guard let episodeFolderURL else {
            status = "Choose or create an episode folder first."
            return
        }
        let reviewDir = episodeFolderURL.appendingPathComponent("qa/reviewer-notes", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: reviewDir, withIntermediateDirectories: true)
            let package = ReviewPackage(
                episodeID: sidecar.episodeID,
                workingTitle: sidecar.workingTitle,
                masterVideo: masterVideoURL?.path ?? "",
                generatedAt: Date(),
                reviewMarks: reviewMarks.sorted { $0.timecodeSeconds < $1.timecodeSeconds },
                assemblySettings: assembly
            )
            let jsonURL = reviewDir.appendingPathComponent("\(sidecar.episodeID)_review-marks.json")
            let mdURL = reviewDir.appendingPathComponent("\(sidecar.episodeID)_review-marks.md")
            try Self.encoder.encode(package).write(to: jsonURL)
            try package.markdown.write(to: mdURL, atomically: true, encoding: .utf8)
            status = "Exported reviewer notes package."
        } catch {
            status = "Could not export review package: \(error.localizedDescription)"
        }
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
            status = "Selected episode folder."
        }
    }

    func chooseMasterVideo() {
        let panel = NSOpenPanel()
        panel.title = "Choose Master Video"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.movie, .mpeg4Movie, .quickTimeMovie]
        panel.directoryURL = episodeFolderURL ?? ProjectPaths.videosRoot
        if panel.runModal() == .OK, let url = panel.url {
            masterVideoURL = url
            if episodeFolderURL == nil {
                episodeFolderURL = ProjectPaths.inferEpisodeFolder(from: url)
            }
            status = "Selected master video."
        }
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
}

struct ReviewPackage: Codable {
    var episodeID: String
    var workingTitle: String
    var masterVideo: String
    var generatedAt: Date
    var reviewMarks: [ReviewMark]
    var assemblySettings: AssemblySettings

    var markdown: String {
        var lines: [String] = [
            "# Review Marks: \(episodeID)",
            "",
            "- Title: \(workingTitle)",
            "- Master video: `\(masterVideo)`",
            "- Generated: \(generatedAt)",
            "",
            "## Rules",
            "",
            "- Visual edits remain hard cuts only.",
            "- Audio uses gentle fades/crossfades and loudness normalization.",
            "- Speed correction is allowed only for marks that explicitly request it.",
            "",
            "## Marks",
            "",
            "| Timecode | Duration | Category | Action | Speed | Volume | Note |",
            "| --- | ---: | --- | --- | ---: | ---: | --- |"
        ]
        for mark in reviewMarks {
            lines.append(
                "| \(TimecodeFormatter.string(mark.timecodeSeconds)) | \(String(format: "%.1f", mark.durationSeconds))s | \(mark.category.title) | \(mark.action.title) | \(String(format: "%.2fx", mark.speedMultiplier)) | \(String(format: "%.1f dB", mark.volumeDeltaDb)) | \(mark.note.replacingOccurrences(of: "\n", with: " ")) |"
            )
        }
        return lines.joined(separator: "\n") + "\n"
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
