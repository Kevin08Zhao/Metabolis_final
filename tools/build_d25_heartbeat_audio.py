#!/usr/bin/env python3
"""Build the deterministic one-second D-25 heartbeat source loop."""

from __future__ import annotations

import argparse
import json
import math
import random
import wave
from array import array
from pathlib import Path


SAMPLE_RATE = 48_000
DURATION_SECONDS = 1.0
TARGET_PEAK = 7_600


def pulse(
    elapsed: float,
    frequency: float,
    duration: float,
    amplitude: float,
    noise: float,
) -> float:
    if elapsed < 0.0 or elapsed >= duration:
        return 0.0
    attack = min(elapsed / 0.006, 1.0)
    release = math.exp(-elapsed * 28.0)
    body = math.sin(math.tau * frequency * elapsed)
    body += 0.42 * math.sin(math.tau * frequency * 0.61 * elapsed)
    return amplitude * attack * release * (body + noise)


def build_samples() -> array:
    random_source = random.Random(25_001)
    values: list[float] = []
    frame_count = int(SAMPLE_RATE * DURATION_SECONDS)
    for frame in range(frame_count):
        time_seconds = frame / SAMPLE_RATE
        noise_a = random_source.uniform(-0.035, 0.035) * math.exp(
            -max(time_seconds - 0.100, 0.0) * 55.0
        )
        noise_b = random_source.uniform(-0.025, 0.025) * math.exp(
            -max(time_seconds - 0.320, 0.0) * 55.0
        )
        value = pulse(time_seconds - 0.100, 72.0, 0.150, 1.0, noise_a)
        value += pulse(time_seconds - 0.320, 56.0, 0.180, 0.62, noise_b)
        values.append(value)

    peak = max(abs(value) for value in values)
    scale = TARGET_PEAK / peak
    return array("h", (round(value * scale) for value in values))


def write_wave(output: Path) -> dict[str, int | str]:
    samples = build_samples()
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(SAMPLE_RATE)
        stream.writeframes(samples.tobytes())
    return {
        "status": "PASS",
        "output": output.as_posix(),
        "sample_rate_hz": SAMPLE_RATE,
        "channels": 1,
        "sample_width_bytes": 2,
        "frames": len(samples),
        "duration_ms": round(len(samples) * 1000 / SAMPLE_RATE),
        "peak_pcm16": max(abs(sample) for sample in samples),
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output",
        type=Path,
        default=Path("audio/ambient/heartbeat_bed.wav"),
    )
    return parser.parse_args()


def main() -> int:
    print(json.dumps(write_wave(parse_args().output), indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
