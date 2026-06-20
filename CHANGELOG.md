# Changelog

## v0.2.0

- Rebuilt the review screen around a larger hero video player.
- Locked the review player to a 16:9 aspect ratio during window resizing.
- Added revision-type marking with dynamic side-panel cards.
- Added yellow submit workflow that saves and copies the full edit packet.
- Added `New Review` as a full clean-state reset for selected project, master, marks, and review metadata.
- Added a top-level yellow `Thumbnail` mark button for exact-frame YouTube thumbnail export requests.
- Added bare `M` mark shortcut.
- Added `1` and `2` hotkeys to jump to the first and last reviewable frames.
- Added J/K/L shuttle controls with repeated reverse/forward speed stepping.
- Kept arrow transport controls as one-frame stepping buttons.
- Improved frame stepping by mapping arrow actions to the detected source frame timing.
- Clamped review playback away from the zero-time black frame so the player starts on the first visible frame.
- Added `masters/shorts` as the final Shorts master destination.
- Documented short Finder-friendly master naming for draft, final, and Shorts exports.
- Reorganized the sidebar so Review is the primary workflow.

## v0.1.0

- Initial public release of VIDMARK STUDIO.
- Added macOS SwiftUI review console.
- Added native video review player with theater and full-screen modes.
- Added timecode review marks and Markdown/JSON export.
- Added local FFmpeg assembly helper.
- Added smart vertical reframing helper.
- Added generic local system check.
- Removed private production branding, provider helper scripts, and account-specific workflow material from the public project.
