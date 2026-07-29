"""D-26/D-27 Audio builder — deterministic synthetic PCM WAV generation.

Per AUDIO_SFX_SPEC.md: 11 sound designs, all synthetic PCM, mono 48 kHz.
D-26: birth audio (birth_state_changed, birth_sequence_completed)
D-27: remaining game SFX (9 additional events)
"""
import wave, struct, os, math, hashlib

RATE = 48000
OUTDIR = os.path.join(os.path.dirname(__file__) or '.', '..', 'audio', 'events')
os.makedirs(OUTDIR, exist_ok=True)

def write_wav(path, samples, rate=RATE):
    """Write 16-bit signed PCM mono WAV."""
    with wave.open(path, 'w') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(rate)
        max_val = max(abs(s) for s in samples) if samples else 1
        scale = 32000 / max_val if max_val > 0 else 1
        w.writeframes(struct.pack(f'<{len(samples)}h', *[
            int(max(-32767, min(32767, s * scale))) for s in samples
        ]))

def tone(duration_ms, freq, attack_ms=5, decay_ms=30, volume=0.7):
    """Simple sine tone with envelope."""
    n = int(RATE * duration_ms / 1000)
    result = []
    for i in range(n):
        t = i / RATE
        env = 1.0
        attack_n = int(RATE * attack_ms / 1000)
        decay_start = n - int(RATE * decay_ms / 1000)
        if attack_n > 0 and i < attack_n:
            env = i / attack_n
        if i >= decay_start and decay_start < n:
            env = (n - i) / (n - decay_start)
        result.append(volume * env * math.sin(2 * math.pi * freq * t))
    return result

def noise(duration_ms, lowcut=200, highcut=2000, volume=0.5):
    """Band-limited noise burst with envelope."""
    n = int(RATE * duration_ms / 1000)
    result = []
    import random
    random.seed(42)
    # Simple approach: generate noise, apply simple moving average as low-pass
    raw = [random.uniform(-1, 1) for _ in range(n + 10)]
    window = int(RATE / highcut / 2) if highcut > 0 else 1
    smoothed = []
    for i in range(n):
        avg = sum(raw[i:i+window]) / window
        smoothed.append(avg * volume)
    # Apply envelope
    attack_n = max(1, int(RATE * 8 / 1000))
    decay_start = max(1, n - int(RATE * 30 / 1000))
    for i in range(n):
        env = 1.0
        if i < attack_n:
            env = i / attack_n
        if i >= decay_start:
            env = (n - i) / (n - decay_start)
        smoothed[i] *= env
    return smoothed

# --- D-26: Birth Audio ---

# birth_state_changed.wav: 450ms, low filtered flow narrows→pause→opens
def build_birth_state_changed():
    """450ms: flow narrows 180ms, pause 40ms, wider noise 230ms."""
    samples = []
    # Narrowing flow (180ms, descending tone)
    n1 = int(RATE * 180 / 1000)
    for i in range(n1):
        t = i / RATE
        freq = 400 - (i / n1) * 250  # 400Hz → 150Hz
        env = (1 - i / n1) * 0.6  # fading out
        samples.append(env * math.sin(2 * math.pi * freq * t))
    # Pause (40ms silence)
    samples.extend([0.0] * int(RATE * 40 / 1000))
    # Wide noise (230ms, opening)
    n3 = int(RATE * 230 / 1000)
    import random
    random.seed(88)
    for i in range(n3):
        t = i / RATE
        env = min(1.0, i / (RATE * 0.01)) * 0.4  # quick attack
        freq = 150 + (i / n3) * 350  # 150Hz → 500Hz
        samples.append(env * math.sin(2 * math.pi * freq * t))
        samples[-1] += env * 0.3 * random.uniform(-0.5, 0.5)
    return samples

write_wav(os.path.join(OUTDIR, 'birth_state_changed.wav'), build_birth_state_changed())

# birth_sequence_completed.wav: 850ms, soft air onset→rising intake→decay
def build_birth_sequence_completed():
    """850ms: 120ms soft air, 430ms rising intake, 300ms decay."""
    samples = []
    # Soft air onset (120ms, very quiet broadband)
    n1 = int(RATE * 120 / 1000)
    import random
    random.seed(77)
    for i in range(n1):
        samples.append(0.15 * (i/n1) * random.uniform(-0.5, 0.5))
    # Rising intake (430ms, increasing volume, broadening spectrum)
    n2 = int(RATE * 430 / 1000)
    for i in range(n2):
        t = i / RATE
        env = 0.2 + 0.6 * (i / n2)
        sig = env * 0.8 * math.sin(2 * math.pi * 300 * t)
        sig += env * 0.4 * random.uniform(-0.5, 0.5)
        samples.append(sig)
    # Decay (300ms, softening)
    n3 = int(RATE * 300 / 1000)
    for i in range(n3):
        env = 0.8 * (1 - i / n3)
        samples.append(env * 0.5 * math.sin(2 * math.pi * 250 * (1 - i/n3) * i/RATE))
        samples[-1] += env * 0.3 * random.uniform(-0.5, 0.5)
    return samples

write_wav(os.path.join(OUTDIR, 'birth_sequence_completed.wav'), build_birth_sequence_completed())

# --- D-27: Remaining SFX ---

# build_decision_confirmed.wav (180ms)
s = tone(5, 300, volume=0.8)
s += noise(120, lowcut=500, highcut=1500, volume=0.4)
s += tone(55, 200, volume=0.3)
write_wav(os.path.join(OUTDIR, 'build_decision_confirmed.wav'), s)

# transport_pressure_appeared.wav (240ms)
s = tone(10, 150, volume=0.6)
s += [0.0] * int(RATE * 70 / 1000)  # gap
s += tone(10, 150, volume=0.4)
s += noise(150, lowcut=100, highcut=800, volume=0.3)
write_wav(os.path.join(OUTDIR, 'transport_pressure_appeared.wav'), s)

# waste_buildup_appeared.wav (300ms)
s = noise(180, lowcut=300, highcut=2000, volume=0.5)
s += tone(120, 600, volume=0.2, decay_ms=100)
write_wav(os.path.join(OUTDIR, 'waste_buildup_appeared.wav'), s)

# signal_gap_appeared.wav (220ms)
s = tone(20, 2000, volume=0.5, attack_ms=2, decay_ms=5)
s += [0.0] * int(RATE * 80 / 1000)
s += tone(10, 2000, volume=0.3, attack_ms=2, decay_ms=3)
s += tone(110, 3000, volume=0.1, decay_ms=100)
write_wav(os.path.join(OUTDIR, 'signal_gap_appeared.wav'), s)

# system_observation_started.wav (320ms)
for j in range(3):
    s = tone(60, 200 + j*100, volume=0.4, attack_ms=60, decay_ms=100)
    if j == 0:
        combined = s
    else:
        combined = [combined[i] + s[i] if i < len(s) else combined[i] for i in range(len(combined))]
write_wav(os.path.join(OUTDIR, 'system_observation_started.wav'), combined)

# stage_advanced.wav (420ms)
s = tone(30, 400, volume=0.4, attack_ms=10, decay_ms=20)
s += noise(160, lowcut=200, highcut=2000, volume=0.3)
# Second impact louder
s2 = tone(30, 400, volume=0.55, attack_ms=10, decay_ms=20)
s2_offset = int(RATE * 80 / 1000)
full = [0.0] * (len(s) + s2_offset + len(s2))
for i, v in enumerate(s): full[i] = v
for i, v in enumerate(s2): full[s2_offset + i] += v
# Add noise decay
for i in range(int(RATE * 160 / 1000)):
    idx = len(full) - 1 - i
    if idx >= 0:
        full[idx] = full[idx] * (1 - i / 160)
write_wav(os.path.join(OUTDIR, 'stage_advanced.wav'), full)

# minigame_rated.wav (360ms) — up to 3 stamps at 100ms spacing
stamp = tone(70, 500, volume=0.5, attack_ms=2, decay_ms=50)
rating = [0.0] * int(RATE * 360 / 1000)
for stamp_idx in range(3):
    offset = stamp_idx * int(RATE * 100 / 1000)
    for i, v in enumerate(stamp):
        if offset + i < len(rating):
            rating[offset + i] += v * (1.0 if stamp_idx < 3 else 0.0)
write_wav(os.path.join(OUTDIR, 'minigame_rated.wav'), rating)

# resource_shortage_raised.wav (180ms)
s = tone(40, 3000, volume=0.6, attack_ms=5, decay_ms=10)
s += noise(120, lowcut=1000, highcut=4000, volume=0.3)
write_wav(os.path.join(OUTDIR, 'resource_shortage_raised.wav'), s)

# Print results
import glob
wavs = sorted(glob.glob(os.path.join(OUTDIR, '*.wav')))
print(f'{len(wavs)} WAV files generated:')
for w in wavs:
    name = os.path.basename(w)
    size = os.path.getsize(w)
    sha = hashlib.sha256(open(w, 'rb').read()).hexdigest()
    print(f'  {name}: {size} bytes, sha={sha[:24]}...')
print('D-26/D-27 audio complete.')
