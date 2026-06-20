#!/usr/bin/env python3
"""VIDMARK STUDIO assembly engine.

Local FFmpeg assembly for approved modules. The engine keeps video and sound
effect cuts hard, normalizes loudness, and allows speed correction only when a
manifest explicitly marks it as reviewer-approved.
"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass, asdict
from pathlib import Path
from typing import Any


def fail(message: str, code: int = 2) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(code)


def find_binary(name: str) -> str:
    found = shutil.which(name)
    if found:
        return found
    for prefix in ("/opt/homebrew/bin", "/usr/local/bin", "/usr/bin"):
        candidate = Path(prefix) / name
        if candidate.exists():
            return str(candidate)
    fail(f"{name} not found. Install FFmpeg or add it to PATH.")


FFMPEG = find_binary("ffmpeg")
FFPROBE = find_binary("ffprobe")


@dataclass
class ClipPlan:
    index: int
    video: str
    audio: str
    trim_start: float
    trim_end: float
    source_duration: float
    output_duration: float
    speed: float
    reviewer_approved_speed: bool
    volume_db: float
    normalized_video: str
    normalized_audio: str


def run(cmd: list[str], *, capture: bool = True) -> subprocess.CompletedProcess:
    return subprocess.run(
        cmd,
        check=True,
        text=True,
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def ffprobe_duration(path: Path) -> float:
    cmd = [
        FFPROBE,
        "-v",
        "error",
        "-show_entries",
        "format=duration",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(path),
    ]
    try:
        return float(run(cmd).stdout.strip())
    except Exception as exc:
        fail(f"Could not determine duration for {path}: {exc}")


def load_manifest(path: Path) -> dict[str, Any]:
    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        fail(f"Could not read manifest {path}: {exc}")


def resolve_path(base: Path, value: str) -> Path:
    path = Path(value).expanduser()
    if path.is_absolute():
        return path
    return (base / path).resolve()


def quality_settings(name: str) -> tuple[str, str]:
    presets = {
        "draft": ("24", "veryfast"),
        "standard": ("20", "medium"),
        "high": ("17", "slow"),
        "archival": ("14", "slower"),
    }
    return presets.get(name, presets["standard"])


def make_video_segment(
    source: Path,
    output: Path,
    duration: float,
    trim_start: float,
    speed: float,
    width: int,
    height: int,
    fps: int,
    quality: str,
) -> None:
    crf, preset = quality_settings(quality)
    speed_filter = f",setpts=PTS/{speed:.5f}" if abs(speed - 1.0) > 0.001 else ""
    vf = (
        f"scale={width}:{height}:force_original_aspect_ratio=decrease,"
        f"pad={width}:{height}:(ow-iw)/2:(oh-ih)/2,"
        f"fps={fps},setsar=1{speed_filter}"
    )
    cmd = [
        FFMPEG,
        "-y",
        "-ss",
        f"{trim_start:.3f}",
        "-i",
        str(source),
        "-t",
        f"{duration:.3f}",
        "-map",
        "0:v:0",
        "-an",
        "-vf",
        vf,
        "-c:v",
        "libx264",
        "-preset",
        preset,
        "-crf",
        crf,
        "-pix_fmt",
        "yuv420p",
        str(output),
    ]
    run(cmd)


def make_audio_segment(source: Path | None, output: Path, duration: float, volume_db: float) -> None:
    filters = [
        f"volume={volume_db}dB",
        "aresample=48000",
    ]
    if source and source.exists():
        cmd = [
            FFMPEG,
            "-y",
            "-stream_loop",
            "-1",
            "-i",
            str(source),
            "-t",
            f"{duration:.3f}",
            "-vn",
            "-af",
            ",".join(filters),
            "-ac",
            "2",
            "-ar",
            "48000",
            str(output),
        ]
    else:
        cmd = [
            FFMPEG,
            "-y",
            "-f",
            "lavfi",
            "-i",
            "anullsrc=channel_layout=stereo:sample_rate=48000",
            "-t",
            f"{duration:.3f}",
            "-af",
            ",".join(filters),
            "-ac",
            "2",
            "-ar",
            "48000",
            str(output),
        ]
    run(cmd)


def concat_files(files: list[Path], list_path: Path, output: Path, *, audio: bool) -> None:
    def quote(path: Path) -> str:
        return str(path).replace("'", "'\\''")

    list_path.write_text(
        "".join(f"file '{quote(path)}'\n" for path in files),
        encoding="utf-8",
    )
    cmd = [
        FFMPEG,
        "-y",
        "-f",
        "concat",
        "-safe",
        "0",
        "-i",
        str(list_path),
        "-c",
        "copy",
        str(output),
    ]
    if audio:
        cmd = [
            FFMPEG,
            "-y",
            "-f",
            "concat",
            "-safe",
            "0",
            "-i",
            str(list_path),
            "-c:a",
            "pcm_s16le",
            str(output),
        ]
    run(cmd)


def mix_base_audio(base_audio: Path | None, segment_audio: Path, output: Path, duration: float, target_lufs: float, true_peak: float) -> None:
    loudnorm = f"loudnorm=I={target_lufs:.1f}:TP={true_peak:.1f}:LRA=8"
    limiter = f"alimiter=limit={db_to_linear(true_peak):.5f}"
    if base_audio and base_audio.exists():
        cmd = [
            FFMPEG,
            "-y",
            "-i",
            str(segment_audio),
            "-stream_loop",
            "-1",
            "-i",
            str(base_audio),
            "-t",
            f"{duration:.3f}",
            "-filter_complex",
            f"[1:a]volume=-9dB,aresample=48000[bed];[0:a][bed]amix=inputs=2:duration=first:dropout_transition=0,{loudnorm},{limiter}[a]",
            "-map",
            "[a]",
            "-ac",
            "2",
            "-ar",
            "48000",
            str(output),
        ]
    else:
        cmd = [
            FFMPEG,
            "-y",
            "-i",
            str(segment_audio),
            "-af",
            f"{loudnorm},{limiter}",
            "-ac",
            "2",
            "-ar",
            "48000",
            str(output),
        ]
    run(cmd)


def db_to_linear(db: float) -> float:
    return 10 ** (db / 20.0)


def mux(video: Path, audio: Path, output: Path) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    cmd = [
        FFMPEG,
        "-y",
        "-i",
        str(video),
        "-i",
        str(audio),
        "-map",
        "0:v:0",
        "-map",
        "1:a:0",
        "-c:v",
        "copy",
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-movflags",
        "+faststart",
        str(output),
    ]
    run(cmd)


def assemble(manifest_path: Path) -> tuple[Path, dict[str, Any]]:
    manifest = load_manifest(manifest_path)
    base = manifest_path.parent
    settings = manifest.get("settings", {})
    width = int(settings.get("width", 1920))
    height = int(settings.get("height", 1080))
    fps = int(settings.get("fps", 24))
    quality = settings.get("quality", "standard")
    audio_fade_ms = 0
    target_lufs = float(settings.get("targetLUFS", settings.get("target_lufs", -19.0)))
    true_peak = float(settings.get("truePeakDb", settings.get("true_peak_db", -2.0)))
    output = resolve_path(base, manifest.get("output", "masters/final/final-master.mp4"))
    base_audio = manifest.get("baseAudio") or manifest.get("base_audio") or ""
    base_audio_path = resolve_path(base, base_audio) if base_audio else None
    clips = manifest.get("clips", [])
    if not clips:
        fail("Manifest must include at least one clip.")

    plans: list[ClipPlan] = []
    with tempfile.TemporaryDirectory(prefix="vidmark-studio-") as tmp_raw:
        tmp = Path(tmp_raw)
        video_segments: list[Path] = []
        audio_segments: list[Path] = []
        total_duration = 0.0

        for index, clip in enumerate(clips, start=1):
            video = resolve_path(base, clip["video"])
            if not video.exists():
                fail(f"Video clip not found: {video}")
            audio_value = clip.get("audio", "")
            audio = resolve_path(base, audio_value) if audio_value else None
            trim_start = float(clip.get("trimStart", clip.get("trim_start", 0.0)))
            trim_end = float(clip.get("trimEnd", clip.get("trim_end", 0.0)))
            source_duration = ffprobe_duration(video)
            usable_duration = max(0.1, source_duration - trim_start - trim_end)
            speed = float(clip.get("speed", 1.0))
            approved_speed = bool(clip.get("reviewerApprovedSpeedCorrection", clip.get("reviewer_approved_speed", False)))
            if abs(speed - 1.0) > 0.001 and not approved_speed:
                print(f"WARNING: clip {index} requested speed {speed:.2f} without Reviewer approval; using 1.0x.")
                speed = 1.0
            if speed < 0.5 or speed > 1.25:
                fail(f"Clip {index} speed {speed:.2f} is outside safe range.")
            output_duration = usable_duration / speed
            volume_db = float(clip.get("volumeDb", clip.get("volume_db", 0.0)))
            video_out = tmp / f"video_{index:03d}.mp4"
            audio_out = tmp / f"audio_{index:03d}.wav"
            make_video_segment(video, video_out, usable_duration, trim_start, speed, width, height, fps, quality)
            make_audio_segment(audio, audio_out, output_duration, volume_db)
            video_segments.append(video_out)
            audio_segments.append(audio_out)
            total_duration += output_duration
            plans.append(
                ClipPlan(
                    index=index,
                    video=str(video),
                    audio=str(audio) if audio else "",
                    trim_start=trim_start,
                    trim_end=trim_end,
                    source_duration=round(source_duration, 3),
                    output_duration=round(output_duration, 3),
                    speed=round(speed, 3),
                    reviewer_approved_speed=approved_speed,
                    volume_db=volume_db,
                    normalized_video=str(video_out),
                    normalized_audio=str(audio_out),
                )
            )

        concat_video = tmp / "concat_video.mp4"
        concat_audio = tmp / "concat_audio.wav"
        final_audio = tmp / "final_audio.wav"
        concat_files(video_segments, tmp / "videos.txt", concat_video, audio=False)
        concat_files(audio_segments, tmp / "audios.txt", concat_audio, audio=True)
        mix_base_audio(base_audio_path, concat_audio, final_audio, total_duration, target_lufs, true_peak)
        mux(concat_video, final_audio, output)

    report = {
        "tool": "VIDMARK STUDIO Assembler",
        "version": "0.1.0",
        "manifest": str(manifest_path),
        "output": str(output),
        "settings": {
            "width": width,
            "height": height,
            "fps": fps,
            "quality": quality,
            "video_cuts": "hard",
            "video_transitions": "none",
            "audio_cut_mode": "hard cuts aligned to video module boundaries",
            "audio_fade_ms": audio_fade_ms,
            "target_lufs": target_lufs,
            "true_peak_db": true_peak,
            "speed_correction_rule": "Only reviewer-approved clip speed changes are applied.",
        },
        "duration_seconds": round(sum(plan.output_duration for plan in plans), 3),
        "clips": [asdict(plan) for plan in plans],
        "cost": {
            "local_tool_cost_usd": 0,
            "paid_services_used": [],
            "notes": "Local FFmpeg assembly. No paid service used.",
        },
    }
    report_path = output.with_suffix(".assembly-report.json")
    report_path.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return output, report


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Assemble a video master from a JSON manifest.")
    parser.add_argument("manifest", help="Assembly manifest JSON.")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    output, report = assemble(Path(args.manifest).expanduser().resolve())
    print(f"Finished: {output}")
    print(f"Duration: {report['duration_seconds']:.2f}s")
    print(f"Report: {output.with_suffix('.assembly-report.json')}")


if __name__ == "__main__":
    main()
