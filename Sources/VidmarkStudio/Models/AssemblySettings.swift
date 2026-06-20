import Foundation

struct AssemblySettings: Codable, Equatable {
    var width = 1920
    var height = 1080
    var fps = 24
    var targetDurationSeconds = 180
    var moduleCountMin = 18
    var moduleCountMax = 24
    var videoCutsOnly = true
    var allowVideoTransitions = false
    var allowFilters = false
    var defaultPlaybackSpeed = 1.0
    var speedCorrectionRequiresReviewerMark = true
    var audioFadeMs = 0
    var audioCrossfadeAllowed = false
    var targetLUFS = -19.0
    var truePeakDb = -2.0
    var noHumanVocalizations = true
}
