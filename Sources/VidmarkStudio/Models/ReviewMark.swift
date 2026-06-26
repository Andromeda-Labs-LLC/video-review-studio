import Foundation

enum ReviewRevisionType: String, Codable, CaseIterable, Identifiable {
    case videoProblem
    case regenerateVideo
    case audioProblem
    case speedRamp
    case trimClipStart
    case trimClipEnd
    case titleFix
    case removeClip
    case thumbnail

    var id: String { rawValue }

    static let pickerCases: [ReviewRevisionType] = [
        .videoProblem,
        .regenerateVideo,
        .audioProblem,
        .speedRamp,
        .trimClipStart,
        .trimClipEnd,
        .titleFix,
        .removeClip
    ]

    var title: String {
        switch self {
        case .videoProblem: "Video problem"
        case .regenerateVideo: "Regenerate Video"
        case .audioProblem: "Audio problem"
        case .speedRamp: "Speed ramp"
        case .trimClipStart: "Trim clip start"
        case .trimClipEnd: "Trim clip end"
        case .titleFix: "Title fix"
        case .removeClip: "Remove clip"
        case .thumbnail: "Thumbnail"
        }
    }

    var detail: String {
        switch self {
        case .videoProblem: "Flag visual artifacts, odd motion, bad framing, or malformed imagery."
        case .regenerateVideo: "Request a fresh image-to-video re-roll for the generated source clip."
        case .audioProblem: "Flag harsh, missing, creepy, loud, or mismatched sound."
        case .speedRamp: "Request a natural percentage speed change for this section."
        case .trimClipStart: "Mark an in/out range to cut from the beginning side of a clip."
        case .trimClipEnd: "Mark an in/out range to cut from the ending side of a clip."
        case .titleFix: "Request a title, callout, typo, placement, or timing correction."
        case .removeClip: "Remove the entire clip from the finished assembly."
        case .thumbnail: "Use this exact frame as the source image for the video thumbnail."
        }
    }

    var systemImage: String {
        switch self {
        case .videoProblem: "video.badge.exclamationmark"
        case .regenerateVideo: "arrow.triangle.2.circlepath.video"
        case .audioProblem: "waveform.badge.exclamationmark"
        case .speedRamp: "speedometer"
        case .trimClipStart: "timeline.selection"
        case .trimClipEnd: "timeline.selection"
        case .titleFix: "textformat"
        case .removeClip: "trash"
        case .thumbnail: "photo"
        }
    }
}

struct ReviewMark: Identifiable, Codable, Equatable {
    var id = UUID()
    var timecodeSeconds: Double
    var revisionType: ReviewRevisionType = .videoProblem
    var note = ""
    var trimInSeconds: Double?
    var trimOutSeconds: Double?
    var speedPercent: Int = 100
    var volumeDeltaDb: Double = -3
    var replacementTitle = ""
    var replacementSFXPath = ""
    var sfxNote = ""
    var createdAt = Date()

    init(timecodeSeconds: Double, revisionType: ReviewRevisionType = .videoProblem) {
        self.timecodeSeconds = timecodeSeconds
        self.revisionType = revisionType

        switch revisionType {
        case .trimClipStart, .trimClipEnd:
            self.trimInSeconds = timecodeSeconds
            self.trimOutSeconds = nil
        case .speedRamp:
            self.speedPercent = 120
        case .regenerateVideo:
            self.note = "Regenerate this generated source video clip as a fresh re-roll. Go back to the approved first-frame still and Miniature Places image-to-video protocol, normally Kling 3.0 API, rewrite the video prompt as needed around the actual still, and create a new candidate clip to replace this one for review."
        case .thumbnail:
            self.note = "Export a full-resolution 1920x1080 PNG still image from this exact frame for the YouTube thumbnail background."
        default:
            break
        }
    }
}

enum TimecodeFormatter {
    static func string(_ seconds: Double, frameRate: Double = 24) -> String {
        let clamped = max(0, seconds)
        let framesPerSecond = max(1, Int(frameRate.rounded()))
        let totalFrames = Int((clamped * Double(framesPerSecond)).rounded())
        let frames = totalFrames % framesPerSecond
        let totalSeconds = totalFrames / framesPerSecond
        let secs = totalSeconds % 60
        let mins = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d:%02d", hours, mins, secs, frames)
        }
        return String(format: "%02d:%02d:%02d", mins, secs, frames)
    }
}
