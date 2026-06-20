import Foundation

enum ProjectPaths {
    private static let videosRootPreferenceKey = "VidmarkStudioVideosRoot"
    private static let audioLibraryPreferenceKey = "VidmarkStudioAudioLibraryRoot"

    static let workspaceRoot = FileManager.default
        .homeDirectoryForCurrentUser
        .appendingPathComponent("Movies", isDirectory: true)
        .appendingPathComponent("VIDMARK STUDIO", isDirectory: true)
    static var videosRoot: URL {
        if let storedPath = UserDefaults.standard.string(forKey: videosRootPreferenceKey),
           !storedPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return URL(fileURLWithPath: NSString(string: storedPath).expandingTildeInPath, isDirectory: true)
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
        name.hasPrefix("VID-") || name.hasPrefix("VRS-")
    }
}
