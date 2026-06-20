import Foundation

enum ReviewRevisionType: String, Codable, CaseIterable, Identifiable {
    case videoProblem
    case audioProblem
    case speedRamp
    case trimClipStart
    case trimClipEnd
    case titleFix
    case removeClip

    var id: String { rawValue }

    var title: String {
        switch self {
        case .videoProblem: "Video problem"
        case .audioProblem: "Audio problem"
        case .speedRamp: "Speed ramp"
        case .trimClipStart: "Trim clip start"
        case .trimClipEnd: "Trim clip end"
        case .titleFix: "Title fix"
        case .removeClip: "Remove clip"
        }
    }

    var detail: String {
        switch self {
        case .videoProblem: "Flag visual artifacts, odd motion, bad framing, or malformed imagery."
        case .audioProblem: "Flag harsh, missing, creepy, loud, or mismatched sound."
        case .speedRamp: "Request a natural percentage speed change for this section."
        case .trimClipStart: "Mark an in/out range to cut from the beginning side of a clip."
        case .trimClipEnd: "Mark an in/out range to cut from the ending side of a clip."
        case .titleFix: "Request a title, callout, typo, placement, or timing correction."
        case .removeClip: "Remove the entire clip from the finished assembly."
        }
    }

    var systemImage: String {
        switch self {
        case .videoProblem: "video.badge.exclamationmark"
        case .audioProblem: "waveform.badge.exclamationmark"
        case .speedRamp: "speedometer"
        case .trimClipStart: "timeline.selection"
        case .trimClipEnd: "timeline.selection"
        case .titleFix: "textformat"
        case .removeClip: "trash"
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
        case .trimClipStart:
            self.trimInSeconds = 0
            self.trimOutSeconds = timecodeSeconds
        case .trimClipEnd:
            self.trimInSeconds = timecodeSeconds
            self.trimOutSeconds = timecodeSeconds + 2
        case .speedRamp:
            self.speedPercent = 120
        default:
            break
        }
    }
}

enum TimecodeFormatter {
    static func string(_ seconds: Double) -> String {
        let clamped = max(0, seconds)
        let totalFrames = Int((clamped * 24).rounded())
        let frames = totalFrames % 24
        let totalSeconds = totalFrames / 24
        let secs = totalSeconds % 60
        let mins = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        if hours > 0 {
            return String(format: "%d:%02d:%02d:%02d", hours, mins, secs, frames)
        }
        return String(format: "%02d:%02d:%02d", mins, secs, frames)
    }
}
