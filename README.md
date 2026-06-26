# VIDMARK STUDIO

VIDMARK STUDIO is an open-source macOS desktop tool for creators who need a faster way to review, organize, annotate, and manage video production assets.

It is built for creator workflows where a finished video is assembled from many clips, drafts, generated shots, retakes, sound beds, thumbnails, and vertical cutdowns. The app keeps the process simple: choose a project, review the master, mark problems by timecode, export review notes, assemble approved media, and generate vertical short candidates from a widescreen master.

## Who It Helps

- Video creators reviewing episode drafts
- AI-video creators managing many generated clips and retakes
- Editors who need clean timecode notes instead of scattered comments
- Short-form and social-video teams preparing both widescreen and vertical outputs
- Solo creators who want a lightweight review console without opening a full editing suite

## Current Features

- macOS SwiftUI desktop app with a dark, minimal interface
- Project sidecar setup for repeatable planning and folder creation
- Prompt/brief export for external planning or generation tools
- Image Review module for selecting winning first-frame stills from candidate image batches
- Native video review player using `AVPlayerView`
- Theater mode and full-screen playback for better review, with Escape and an on-screen Exit button to leave full screen
- Large hero review player with J/K/L shuttle controls
- Timecode revision cards for video, regenerate-video, audio, speed, trim, title, and remove-clip requests
- New Review reset that clears the active marks and generated review packets without deleting media
- Dynamic card controls for notes, speed percentages, SFX swaps with preview, audio volume changes, trim in/out points, and title fixes
- Submit workflow that saves a Markdown/JSON revision packet and copies the Markdown packet to the clipboard
- Exportable review package in JSON and Markdown
- Assembly settings export for local post-production
- FFmpeg-based master assembly helper with hard video cuts, hard audio cuts, and loudness normalization
- FFmpeg/Pillow-based smart reframing helper for vertical short candidates
- Local system check for FFmpeg, FFprobe, Python, Swift, engine scripts, and workspace folders

## Privacy And Safety

VIDMARK STUDIO does not ship accounts, private access material, private videos, paid assets, personal details, or provider-specific configuration.

The public repo is designed to be safe to clone and inspect. Your local media stays wherever you choose to store it.

## Requirements

- macOS 14 or newer
- Swift 6 toolchain or Xcode command line tools
- FFmpeg and FFprobe for assembly/reframing workflows
- Python 3
- Pillow for smart reframing analysis

Install common local dependencies with Homebrew:

```bash
brew install ffmpeg python
python3 -m pip install Pillow
```

## Build And Run

From the project root:

```bash
swift build
./script/build_and_run.sh
```

The app bundle is created at:

```text
dist/VIDMARK STUDIO.app
```

To run a quick launch verification:

```bash
./script/build_and_run.sh --verify
```

## Workspace

By default, VIDMARK STUDIO creates and uses:

```text
/Volumes/Adventure/Miniature Places/Videos
```

If the Adventure drive is not mounted, VIDMARK STUDIO falls back to `~/Movies/VIDMARK STUDIO/Videos`.

The `Episode` picker opens the configured videos folder. To point it at an existing production library:

```bash
defaults write studio.vidmark.desktop VidmarkStudioVideosRoot "/path/to/your/Videos"
```

Each project folder can contain:

```text
images/source-stills/candidates
images/source-stills/Final
video-generations/drafts
video-generations/approved
masters/drafts
masters/final
masters/shorts
audio/stems
audio/mix
assembly/manifests
shorts/reframer-candidates
shorts/approved
thumbnails/candidates
metadata
prompts
qa/reviewer-notes
```

Recommended master naming:

- Draft review masters: `<project-id>-v1.mp4`, `<project-id>-v2.mp4`, `<project-id>-v3.mp4`
- Draft render artifacts: `masters/drafts/workfiles/`
- Approved upload master: `<project-id>-Final.mp4`
- Approved Shorts masters: `<project-id>-Short-01.mp4`, `<project-id>-Short-02.mp4`

## Review Workflow

1. Choose or create a project folder.
2. Choose a master video.
   After an episode is selected, the Master picker opens that episode's `masters/final` folder first, then falls back to `masters/drafts`.
3. Watch in normal, theater, or full-screen mode.
   Full-screen playback can be exited with `Esc` or the `Exit Full Screen` button.
4. Use the arrow transport buttons to step backward or forward one frame.
5. Use `J` for reverse playback, `L` for forward playback, and press the same key again to double the shuttle speed. Use `K` or the spacebar to play/pause.
6. Use `1` to jump to the first frame and `2` to jump to the last frame.
7. Pause on a trouble spot and press `Mark`, or press `M`.
8. Press `Thumbnail` to mark the parked frame for a full-resolution PNG thumbnail export.
9. Choose the revision type: video problem, regenerate video, audio problem, speed ramp, trim clip start, trim clip end, title fix, thumbnail, or remove clip.
10. Add notes or use the card-specific controls in the revision panel.
   Audio problem cards can preview and attach a replacement SFX file from the selected audio library.
11. Press `SUBMIT` to save the full revision packet and copy it to the clipboard for editor or agent handoff.
12. Use `New Review` to reset the app to a clean state before loading another project. This clears selected project state and generated review packets, but never deletes media.
13. Assemble or reframe only after the project passes review.

## Image Review Workflow

Use Image Review when a shot has multiple generated still-image candidates and one needs to be selected for video generation.

1. Open `Image Review` from the sidebar.
2. Choose the episode folder.
3. Press `Candidates` to load that episode's `images/source-stills/candidates` folder.
4. Review each five-image candidate set in the large grid.
5. Select the winning image, then press `Submit Winner`.
6. The selected still is copied into `images/source-stills/Final`.
7. The app records the choice in `images/source-stills/Final/image-review-decisions.json`.

Candidate files are left untouched. The module is designed for fast verdict sorting, not destructive cleanup.

## Local CLI: Reframer

```bash
python3 engine/reframer.py "/path/to/master.mp4" \
  --mode smart \
  --aspect 9:16 \
  --width 1080 \
  --height 1920 \
  --duration 20 \
  --candidates 3 \
  --quality standard
```

If `--output-dir` is omitted, output goes to:

```text
<video project>/shorts/reframer-candidates
```

## Local CLI: Assembly

```bash
python3 engine/studio_assembler.py "/path/to/assembly-manifest.json"
```

Example manifest:

```json
{
  "output": "masters/final/final-master.mp4",
  "settings": {
    "width": 1920,
    "height": 1080,
    "fps": 24,
    "quality": "standard",
    "audioFadeMs": 0,
    "targetLUFS": -19,
    "truePeakDb": -2
  },
  "baseAudio": "audio/mix/base-bed.wav",
  "clips": [
    {
      "video": "video-generations/approved/01_opener.mp4",
      "audio": "audio/stems/01_opener.wav",
      "trimStart": 0,
      "trimEnd": 0,
      "speed": 1.0,
      "reviewerApprovedSpeedCorrection": false,
      "volumeDb": 0
    }
  ]
}
```

The assembler writes a final MP4 and an `.assembly-report.json` beside it.

## Project Status

VIDMARK STUDIO is early but usable. It is actively maintained as part of a real creator production workflow, with an emphasis on local-first review, simple notation, and automation-friendly outputs.

No usage metrics, stars, downloads, or adoption claims are implied.

## Roadmap

See [ROADMAP.md](ROADMAP.md).

## Contributing

Contributions are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), open an issue with a concrete creator workflow problem, or propose a small pull request.

## License

MIT. See [LICENSE](LICENSE).
