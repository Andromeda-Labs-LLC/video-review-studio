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
- Native video review player using `AVPlayerView`
- Theater mode and full-screen playback for better review
- Timecode review marks with category, action, duration, speed, volume, and note fields
- Exportable review package in JSON and Markdown
- Assembly settings export for local post-production
- FFmpeg-based master assembly helper with hard video cuts, soft audio fades, and loudness normalization
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
~/Movies/VIDMARK STUDIO
```

The `Episode` picker opens the configured videos folder. To point it at an existing production library:

```bash
defaults write studio.vidmark.desktop VidmarkStudioVideosRoot "/path/to/your/Videos"
```

Each project folder can contain:

```text
images/source-stills
video-generations/drafts
video-generations/approved
masters/drafts
masters/final
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

## Review Workflow

1. Choose or create a project folder.
2. Choose a master video.
3. Watch in normal, theater, or full-screen mode.
4. Add marks at exact timecodes when something needs attention.
5. Export review notes for retakes, trims, audio fixes, speed fixes, or replacement clips.
6. Assemble or reframe only after the project passes review.

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
    "audioFadeMs": 350,
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
