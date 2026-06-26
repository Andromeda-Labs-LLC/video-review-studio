import Foundation

struct EpisodeMetadata: Equatable {
    var episodeID: String
    var workingTitle: String
    var slug: String
}

enum ProjectPaths {
    private static let videosRootPreferenceKey = "VidmarkStudioVideosRoot"
    private static let audioLibraryPreferenceKey = "VidmarkStudioAudioLibraryRoot"

    static let workspaceRoot = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("VIDMARK STUDIO", isDirectory: true)
    static let miniaturePlacesVideosRoot = URL(fileURLWithPath: "/Volumes/Adventure/Miniature Places/Videos", isDirectory: true)

    static var videosRoot: URL {
        if let storedPath = UserDefaults.standard.string(forKey: videosRootPreferenceKey),
           !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: NSString(string: storedPath).expandingTildeInPath, isDirectory: true)
        }
        if FileManager.default.fileExists(atPath: miniaturePlacesVideosRoot.path) {
            return miniaturePlacesVideosRoot
        }
        return workspaceRoot.appendingPathComponent("Videos", isDirectory: true)
    }
    static var audioLibraryRoot: URL {
        if let storedPath = UserDefaults.standard.string(forKey: audioLibraryPreferenceKey),
           !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: NSString(string: storedPath).expandingTildeInPath, isDirectory: true)
        }
        return workspaceRoot.appendingPathComponent("Audio Library", isDirectory: true)
    }
    static let toolRoot = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)

    static func setVideosRoot(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: videosRootPreferenceKey)
    }

    static func setAudioLibraryRoot(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: audioLibraryPreferenceKey)
    }

    static func defaultOutputFolder(for input: URL) -> URL {
        var cursor = input.deletingLastPathComponent()
        while cursor.path != "/" {
            if isLikelyProjectFolder(cursor.lastPathComponent) {
                return cursor
                    .appendingPathComponent("shorts", isDirectory: true)
                    .appendingPathComponent("reframer-candidates", isDirectory: true)
            }
            cursor.deleteLastPathComponent()
        }
        return input
            .deletingLastPathComponent()
            .appendingPathComponent("shorts", isDirectory: true)
            .appendingPathComponent("reframer-candidates", isDirectory: true)
    }

    static func engineScriptURL() -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL
                .appendingPathComponent("engine", isDirectory: true)
                .appendingPathComponent("reframer.py")
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        let local = toolRoot.appendingPathComponent("engine/reframer.py")
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    static func inferEpisodeFolder(from input: URL) -> URL? {
        var cursor = input.deletingLastPathComponent()
        while cursor.path != "/" {
            if isLikelyProjectFolder(cursor.lastPathComponent) {
                return cursor
            }
            cursor.deleteLastPathComponent()
        }
        return nil
    }

    static func metadata(forEpisodeFolder folder: URL, masterVideo: URL? = nil) -> EpisodeMetadata {
        let folderName = folder.lastPathComponent
        let masterName = masterVideo?.deletingPathExtension().lastPathComponent ?? ""
        let episodeID = extractEpisodeID(from: folderName)
            ?? extractEpisodeID(from: masterName)
            ?? "VID-0000"
        let slug = slugFromProjectName(folderName, episodeID: episodeID)
            ?? slugFromProjectName(masterName, episodeID: episodeID)
            ?? "untitled-video-review-project"
        let workingTitle = titleFromSlug(slug)
        return EpisodeMetadata(episodeID: episodeID, workingTitle: workingTitle, slug: slug)
    }

    static func studioAssemblerScriptURL() -> URL? {
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL
                .appendingPathComponent("engine", isDirectory: true)
                .appendingPathComponent("studio_assembler.py")
            if FileManager.default.fileExists(atPath: bundled.path) {
                return bundled
            }
        }

        let local = toolRoot.appendingPathComponent("engine/studio_assembler.py")
        return FileManager.default.fileExists(atPath: local.path) ? local : nil
    }

    private static func isLikelyProjectFolder(_ name: String) -> Bool {
        extractEpisodeID(from: name) != nil
    }

    private static func extractEpisodeID(from text: String) -> String? {
        guard let range = text.range(
            of: #"[A-Za-z]{2,}-\d{3,}"#,
            options: .regularExpression
        ) else { return nil }
        return String(text[range]).uppercased()
    }

    private static func slugFromProjectName(_ name: String, episodeID: String) -> String? {
        var slug = name
        if slug.localizedCaseInsensitiveContains(episodeID),
           let range = slug.range(of: episodeID, options: [.caseInsensitive]) {
            slug.removeSubrange(range)
        }
        slug = slug.replacingOccurrences(
            of: #"(?i)^[-_\s]*v\d+[-_\s]*"#,
            with: "",
            options: .regularExpression
        )
        slug = slug.replacingOccurrences(
            of: #"(?i)[-_\s]*v\d+$"#,
            with: "",
            options: .regularExpression
        )
        slug = slug.replacingOccurrences(
            of: #"(?i)[-_\s]*edit[-_\s]*v\d+.*$"#,
            with: "",
            options: .regularExpression
        )
        slug = slug.replacingOccurrences(
            of: #"[^A-Za-z0-9]+"#,
            with: "-",
            options: .regularExpression
        )
        slug = slug.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return slug.isEmpty ? nil : slug.lowercased()
    }

    private static func titleFromSlug(_ slug: String) -> String {
        let words = slug
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
            .split(separator: " ")
            .map { word -> String in
                let lower = word.lowercased()
                if lower.count <= 3, ["ai", "ugc", "sfx", "qa"].contains(lower) {
                    return lower.uppercased()
                }
                return lower.prefix(1).uppercased() + lower.dropFirst()
            }
        return words.isEmpty ? "Untitled Video Review Project" : words.joined(separator: " ")
    }
}
