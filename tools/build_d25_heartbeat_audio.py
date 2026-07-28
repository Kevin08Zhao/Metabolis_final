#!/usr/bin/env python3
"""Build deterministic D-25 heartbeat loops for all three stability bands."""

from __future__ import annotations

import argparse
import json
import math
import random
import wave
from array import array
from dataclasses import dataclass
from pathlib import Path


SAMPLE_RATE = 48_000
TARGET_PEAK = 7_600


@dataclass(frozen=True)
class StateSpec:
    state: str
    duration_seconds: float
    first_pulse_seconds: float
    second_pulse_seconds: float
    random_seed: int
    filename: str


STATE_SPECS = {
    "stable": StateSpec(
        state="stable",
        duration_seconds=1.0,
        first_pulse_seconds=0.100,
        second_pulse_seconds=0.320,
        random_seed=25_001,
        filename="heartbeat_bed.wav",
    ),
    "strained": StateSpec(
        state="strained",
        duration_seconds=0.440,
        first_pulse_seconds=0.044,
        second_pulse_seconds=0.141,
        random_seed=25_002,
        filename="heartbeat_bed_strained.wav",
    ),
    "critical": StateSpec(
        state="critical",
        duration_seconds=1.800,
        first_pulse_seconds=0.180,
        second_pulse_seconds=0.576,
        random_seed=25_003,
        filename="heartbeat_bed_critical.wav",
    ),
}


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


def remove_dc_with_silent_boundaries(values: list[float]) -> list[float]:
    if len(values) < 2:
        return values
    weights = [
        math.sin(math.pi * frame / (len(values) - 1)) ** 2
        for frame in range(len(values))
    ]
    correction = sum(values) / sum(weights)
    return [
        value - correction * weight
        for value, weight in zip(values, weights, strict=True)
    ]


def build_samples(spec: StateSpec = STATE_SPECS["stable"]) -> array:
    random_source = random.Random(spec.random_seed)
    values: list[float] = []
    frame_count = round(SAMPLE_RATE * spec.duration_seconds)
    for frame in range(frame_count):
        time_seconds = frame / SAMPLE_RATE
        noise_a = random_source.uniform(-0.035, 0.035) * math.exp(
            -max(time_seconds - spec.first_pulse_seconds, 0.0) * 55.0
        )
        noise_b = random_source.uniform(-0.025, 0.025) * math.exp(
            -max(time_seconds - spec.second_pulse_seconds, 0.0) * 55.0
        )
        value = pulse(
            time_seconds - spec.first_pulse_seconds,
            72.0,
            0.150,
            1.0,
            noise_a,
        )
        value += pulse(
            time_seconds - spec.second_pulse_seconds,
            56.0,
            0.180,
            0.62,
            noise_b,
        )
        values.append(value)

    if spec.state != "stable":
        values = remove_dc_with_silent_boundaries(values)
    peak = max(abs(value) for value in values)
    scale = TARGET_PEAK / peak
    return array("h", (round(value * scale) for value in values))


def write_wave(
    output: Path,
    spec: StateSpec = STATE_SPECS["stable"],
) -> dict[str, int | str]:
    samples = build_samples(spec)
    output.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(output), "wb") as stream:
        stream.setnchannels(1)
        stream.setsampwidth(2)
        stream.setframerate(SAMPLE_RATE)
        stream.writeframes(samples.tobytes())
    return {
        "status": "PASS",
        "state": spec.state,
        "output": output.as_posix(),
        "sample_rate_hz": SAMPLE_RATE,
        "channels": 1,
        "sample_width_bytes": 2,
        "frames": len(samples),
        "duration_ms": round(len(samples) * 1000 / SAMPLE_RATE),
        "peak_pcm16": max(abs(sample) for sample in samples),
    }


def write_all(output_dir: Path) -> list[dict[str, int | str]]:
    return [
        write_wave(output_dir / spec.filename, spec)
        for spec in STATE_SPECS.values()
    ]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    output_group = parser.add_mutually_exclusive_group()
    output_group.add_argument(
        "--output",
        type=Path,
        help="Write only the legacy stable-band output to this path.",
    )
    output_group.add_argument(
        "--output-dir",
        type=Path,
        default=Path("audio/ambient"),
        help="Write all three stability-band loops to this directory.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    result: dict[str, object]
    if args.output is not None:
        result = write_wave(args.output)
    else:
        outputs = write_all(args.output_dir)
        result = {
            "status": "PASS",
            "outputs": outputs,
        }
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
