# Changelog

## v0.2.7

- Added a `Regenerate Video` review mark type for requesting a fresh image-to-video re-roll of a generated source clip, normally through the Miniature Places Kling 3.0 protocol.
- Revision packets now include an explicit Regenerate Video rule so production agents treat those marks as source-clip replacement requests, not ordinary edit fixes.
- Reworked video full-screen playback into a controlled full-screen window with an on-screen `Exit Full Screen` button and `Esc` key handling.
- Documented the new review mark type in the README workflow and feature list.

## v0.2.6

- Renamed the primary review module to Video Review.
- Added an Image Review module for choosing winning first-frame stills from candidate image sets.
- Image Review can load an episode's `images/source-stills/candidates` folder, display candidate sets in a large grid, save the selected winner into `images/source-stills/Final`, and record decisions in `image-review-decisions.json`.
- Added `candidates` and `Final` still-image folders to the generated episode structure.

## v0.2.5

- Replaced the macOS app icon with a higher-contrast classic 35mm cinema camera mark on a white background.
- Regenerated the full iconset and `.icns` bundle asset for the local macOS app.

## v0.2.4

- Synced the packaged macOS app bundle version with the current Vidmark Studio build.
- Refreshed the local installed app bundle so stale `0.2.2` app copies are replaced by the latest app.

## v0.2.3

- Added automatic episode metadata inference when choosing an episode folder or master video.
- Review packets now resolve project IDs and titles from real folder/master names instead of falling back to `VID-0000` and the untitled placeholder.
- Added a compact review-header metadata line so reviewers can verify the active episode, title, and loaded master before submitting notes.
- Review timecodes now use the loaded master video's detected frame rate and export that frame-rate metadata in review packets.

## v0.2.2

- Replaced the app icon with a premium, non-branded classic 35mm motion-picture camera icon.
- Added the 1024px app icon source asset for future iconset regeneration.

## v0.2.1

- Updated trim-start and trim-end marks so the parked playhead time pre-populates the trim `In` point.
- Trim `Out` now stays blank until the reviewer sets it manually.
- Added premium submit feedback: success color, checkmark state, subtle animation, and confirmation copy after revision packet submission.

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
