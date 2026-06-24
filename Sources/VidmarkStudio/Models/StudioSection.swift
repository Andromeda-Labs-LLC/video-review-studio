import Foundation

enum StudioSection: String, CaseIterable, Identifiable {
    case review
    case imageReview
    case episode
    case prompts
    case audio
    case assembly
    case shorts
    case diagnostics

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review: "Video Review"
        case .imageReview: "Image Review"
        case .episode: "Episode"
        case .prompts: "Prompts"
        case .audio: "Audio"
        case .assembly: "Assembly"
        case .shorts: "Shorts"
        case .diagnostics: "System Check"
        }
    }

    var detail: String {
        switch self {
        case .review: "Mark revisions"
        case .imageReview: "Choose still winners"
        case .episode: "Sidecar and folder"
        case .prompts: "ChatGPT image batches"
        case .audio: "SFX and loudness"
        case .assembly: "Manifest export"
        case .shorts: "Smart reframing"
        case .diagnostics: "Local tools"
        }
    }

    var systemImage: String {
        switch self {
        case .review: "scope"
        case .imageReview: "photo.on.rectangle.angled"
        case .episode: "square.stack.3d.up"
        case .prompts: "text.badge.sparkles"
        case .audio: "waveform"
        case .assembly: "timeline.selection"
        case .shorts: "rectangle.portrait.on.rectangle.portrait"
        case .diagnostics: "stethoscope"
        }
    }
}
