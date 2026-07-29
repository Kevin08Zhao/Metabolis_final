"""Build the deterministic D-26/D-27 one-shot PCM WAV files."""

from __future__ import annotations

import argparse
import hashlib
import math
import random
import struct
import wave
from pathlib import Path


RATE = 48_000
EXPECTED_DURATION_MS = {
    "birth_state_changed.wav": 450,
    "birth_sequence_completed.wav": 850,
    "build_decision_confirmed.wav": 180,
    "transport_pressure_appeared.wav": 240,
    "waste_buildup_appeared.wav": 300,
    "signal_gap_appeared.wav": 220,
    "system_observation_started.wav": 320,
    "stage_advanced.wav": 420,
    "minigame_rated.wav": 360,
    "resource_shortage_raised.wav": 180,
}


def sample_count(duration_ms: int) -> int:
    return RATE * duration_ms // 1000


def silence(duration_ms: int) -> list[float]:
    return [0.0] * sample_count(duration_ms)


def tone(
    duration_ms: int,
    frequency: float,
    *,
    attack_ms: int = 5,
    decay_ms: int = 30,
    volume: float = 0.7,
) -> list[float]:
    count = sample_count(duration_ms)
    attack = max(1, sample_count(attack_ms))
    decay = max(1, sample_count(decay_ms))
    samples: list[float] = []
    for index in range(count):
        envelope = min(1.0, index / attack, (count - index) / decay)
        samples.append(
            volume
            * max(0.0, envelope)
            * math.sin(2.0 * math.pi * frequency * index / RATE)
        )
    return samples


def noise(
    duration_ms: int,
    *,
    seed: int,
    highcut_hz: int = 2_000,
    attack_ms: int = 8,
    decay_ms: int = 30,
    volume: float = 0.5,
) -> list[float]:
    count = sample_count(duration_ms)
    rng = random.Random(seed)
    window = max(1, RATE // highcut_hz // 2)
    raw = [rng.uniform(-1.0, 1.0) for _ in range(count + window)]
    attack = max(1, sample_count(attack_ms))
    decay = max(1, sample_count(decay_ms))
    samples: list[float] = []
    for index in range(count):
        envelope = min(1.0, index / attack, (count - index) / decay)
        averaged = sum(raw[index : index + window]) / window
        samples.append(averaged * volume * max(0.0, envelope))
    return samples


def overlay(
    destination: list[float], source: list[float], offset_ms: int = 0
) -> None:
    offset = sample_count(offset_ms)
    for index, value in enumerate(source):
        target = offset + index
        if target >= len(destination):
            break
        destination[target] += value


def build_birth_state_changed() -> list[float]:
    samples: list[float] = []
    narrowing_count = sample_count(180)
    for index in range(narrowing_count):
        progress = index / narrowing_count
        frequency = 400.0 - progress * 250.0
        samples.append(
            (1.0 - progress)
            * 0.6
            * math.sin(2.0 * math.pi * frequency * index / RATE)
        )
    samples += silence(40)
    opening_count = sample_count(230)
    rng = random.Random(88)
    for index in range(opening_count):
        progress = index / opening_count
        envelope = min(1.0, index / sample_count(10)) * (1.0 - progress * 0.25)
        frequency = 150.0 + progress * 350.0
        value = 0.4 * envelope * math.sin(
            2.0 * math.pi * frequency * index / RATE
        )
        samples.append(value + envelope * 0.15 * rng.uniform(-1.0, 1.0))
    return samples


def build_birth_sequence_completed() -> list[float]:
    samples = noise(
        120, seed=77, highcut_hz=3_000, attack_ms=120, decay_ms=1, volume=0.18
    )
    intake = noise(
        430, seed=78, highcut_hz=3_500, attack_ms=430, decay_ms=1, volume=0.55
    )
    overlay(intake, tone(430, 300, attack_ms=430, decay_ms=1, volume=0.18))
    samples += intake
    decay = noise(
        300, seed=79, highcut_hz=2_000, attack_ms=1, decay_ms=300, volume=0.45
    )
    overlay(decay, tone(300, 250, attack_ms=1, decay_ms=300, volume=0.12))
    return samples + decay


def build_files() -> dict[str, list[float]]:
    files: dict[str, list[float]] = {
        "birth_state_changed.wav": build_birth_state_changed(),
        "birth_sequence_completed.wav": build_birth_sequence_completed(),
    }

    files["build_decision_confirmed.wav"] = (
        tone(20, 300, attack_ms=4, decay_ms=12, volume=0.8)
        + noise(120, seed=42, highcut_hz=1_500, decay_ms=110, volume=0.4)
        + tone(40, 200, attack_ms=2, decay_ms=38, volume=0.25)
    )

    pressure = silence(240)
    overlay(pressure, tone(25, 150, attack_ms=4, decay_ms=18, volume=0.6), 0)
    overlay(pressure, tone(25, 140, attack_ms=4, decay_ms=18, volume=0.4), 70)
    overlay(
        pressure,
        noise(145, seed=43, highcut_hz=800, decay_ms=140, volume=0.3),
        95,
    )
    files["transport_pressure_appeared.wav"] = pressure

    waste = noise(
        180, seed=44, highcut_hz=2_000, attack_ms=8, decay_ms=170, volume=0.5
    )
    waste += tone(120, 600, attack_ms=2, decay_ms=115, volume=0.2)
    files["waste_buildup_appeared.wav"] = waste

    signal = silence(220)
    overlay(signal, tone(20, 2_000, attack_ms=2, decay_ms=5, volume=0.5), 0)
    overlay(signal, tone(10, 2_000, attack_ms=2, decay_ms=3, volume=0.3), 100)
    files["signal_gap_appeared.wav"] = signal

    observation = silence(320)
    for index, start_ms in enumerate((0, 80, 160)):
        overlay(
            observation,
            tone(
                160,
                220 + index * 110,
                attack_ms=60,
                decay_ms=100,
                volume=0.28,
            ),
            start_ms,
        )
    files["system_observation_started.wav"] = observation

    stage = silence(420)
    overlay(stage, noise(45, seed=45, highcut_hz=2_000, volume=0.35), 0)
    overlay(stage, noise(45, seed=46, highcut_hz=2_000, volume=0.5), 100)
    overlay(
        stage,
        noise(160, seed=47, highcut_hz=2_000, decay_ms=150, volume=0.25),
        260,
    )
    files["stage_advanced.wav"] = stage

    rating = silence(360)
    stamp = tone(70, 500, attack_ms=2, decay_ms=50, volume=0.5)
    for start_ms in (0, 100, 200):
        overlay(rating, stamp, start_ms)
    files["minigame_rated.wav"] = rating

    files["resource_shortage_raised.wav"] = (
        tone(60, 3_000, attack_ms=40, decay_ms=18, volume=0.6)
        + noise(120, seed=48, highcut_hz=4_000, decay_ms=115, volume=0.3)
    )
    return files


def write_wav(path: Path, samples: list[float]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    peak = max((abs(sample) for sample in samples), default=1.0)
    scale = 28_000.0 / peak if peak else 1.0
    pcm = [
        int(max(-32_767, min(32_767, round(sample * scale)))) for sample in samples
    ]
    with wave.open(str(path), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(struct.pack(f"<{len(pcm)}h", *pcm))


def build_all(output_dir: Path) -> list[Path]:
    outputs: list[Path] = []
    for filename, samples in build_files().items():
        expected = sample_count(EXPECTED_DURATION_MS[filename])
        if len(samples) != expected:
            raise ValueError(f"{filename}: expected {expected} samples, got {len(samples)}")
        output = output_dir / filename
        write_wav(output, samples)
        outputs.append(output)
    return outputs


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=Path(__file__).resolve().parents[1] / "audio" / "events",
    )
    return parser.parse_args()


def main() -> int:
    outputs = build_all(parse_args().output_dir)
    for output in outputs:
        digest = hashlib.sha256(output.read_bytes()).hexdigest()
        print(f"{output.name}: {digest}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
