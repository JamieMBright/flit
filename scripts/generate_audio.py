#!/usr/bin/env python3
"""
Flit Flight Game - Audio Asset Generator
Generates all synthesized audio files for the game using math + lameenc.
"""

import math
import struct
import random
import lameenc
import os

SAMPLE_RATE = 44100
CHANNELS = 1
BITRATE = 96  # kbps


def encode_mp3(pcm_samples: list[float], output_path: str, bitrate: int = BITRATE):
    """Encode a list of float PCM samples [-1.0, 1.0] to MP3 file."""
    # Clamp and convert to 16-bit int
    int16_samples = []
    for s in pcm_samples:
        s = max(-1.0, min(1.0, s))
        int16_samples.append(int(s * 32767))

    raw = struct.pack(f"<{len(int16_samples)}h", *int16_samples)

    encoder = lameenc.Encoder()
    encoder.set_bit_rate(bitrate)
    encoder.set_in_sample_rate(SAMPLE_RATE)
    encoder.set_channels(CHANNELS)
    encoder.set_quality(2)  # 2 = high quality, 7 = fastest

    mp3_data = encoder.encode(raw)
    mp3_data += encoder.flush()

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    with open(output_path, "wb") as f:
        f.write(mp3_data)
    size_kb = len(mp3_data) / 1024
    print(f"  Written: {output_path} ({size_kb:.1f} KB)")


def apply_envelope(samples: list[float], attack: float = 0.01, release: float = 0.05) -> list[float]:
    """Apply attack/release envelope to avoid clicks at loop points."""
    n = len(samples)
    attack_samples = int(attack * SAMPLE_RATE)
    release_samples = int(release * SAMPLE_RATE)
    result = list(samples)
    for i in range(attack_samples):
        result[i] *= i / attack_samples
    for i in range(release_samples):
        idx = n - release_samples + i
        result[idx] *= (release_samples - i) / release_samples
    return result


def white_noise(n_samples: int, seed: int = 42) -> list[float]:
    """Generate white noise samples."""
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(n_samples)]


def lowpass_filter(samples: list[float], cutoff_hz: float, resonance: float = 0.5) -> list[float]:
    """Simple single-pole IIR lowpass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = dt / (rc + dt)
    filtered = []
    prev = 0.0
    for s in samples:
        y = prev + alpha * (s - prev)
        filtered.append(y)
        prev = y
    return filtered


def highpass_filter(samples: list[float], cutoff_hz: float) -> list[float]:
    """Simple single-pole IIR highpass filter."""
    rc = 1.0 / (2.0 * math.pi * cutoff_hz)
    dt = 1.0 / SAMPLE_RATE
    alpha = rc / (rc + dt)
    filtered = []
    prev_x = 0.0
    prev_y = 0.0
    for s in samples:
        y = alpha * (prev_y + s - prev_x)
        filtered.append(y)
        prev_x = s
        prev_y = y
    return filtered


def bandpass_filter(samples: list[float], low_hz: float, high_hz: float) -> list[float]:
    """Bandpass via cascade of lowpass and highpass."""
    return highpass_filter(lowpass_filter(samples, high_hz), low_hz)


def mix(*sample_lists, weights=None) -> list[float]:
    """Mix multiple sample lists together."""
    n = max(len(sl) for sl in sample_lists)
    if weights is None:
        weights = [1.0 / len(sample_lists)] * len(sample_lists)
    result = [0.0] * n
    for sl, w in zip(sample_lists, weights):
        for i in range(len(sl)):
            result[i] += sl[i] * w
    return result


def sine_wave(freq: float, n_samples: int, phase: float = 0.0, amp: float = 1.0) -> list[float]:
    """Generate a sine wave."""
    return [amp * math.sin(2 * math.pi * freq * i / SAMPLE_RATE + phase) for i in range(n_samples)]


def sine_wave_varying(freq_fn, n_samples: int, amp: float = 1.0) -> list[float]:
    """Generate a sine wave with time-varying frequency."""
    samples = []
    phase = 0.0
    for i in range(n_samples):
        t = i / SAMPLE_RATE
        freq = freq_fn(t)
        samples.append(amp * math.sin(phase))
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 2 * math.pi:
            phase -= 2 * math.pi
    return samples


def normalize(samples: list[float], peak: float = 0.85) -> list[float]:
    """Normalize samples to a given peak amplitude."""
    max_val = max(abs(s) for s in samples)
    if max_val < 1e-9:
        return samples
    scale = peak / max_val
    return [s * scale for s in samples]


# ─────────────────────────────────────────────
# ENGINE SOUNDS
# ─────────────────────────────────────────────

def gen_biplane_engine(duration: float = 4.0) -> list[float]:
    """
    Low-frequency rumbling/puttering biplane engine.
    80-120Hz oscillating with slight irregularity.
    """
    n = int(duration * SAMPLE_RATE)
    rng = random.Random(1)

    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Base frequency oscillates between 80-120Hz with slow modulation
        base_freq = 95.0 + 20.0 * math.sin(2 * math.pi * 0.7 * t)
        # Add slight irregularity (engine miss)
        irregularity = 1.0 + 0.08 * math.sin(2 * math.pi * 3.1 * t) + 0.03 * rng.uniform(-1, 1)
        freq = base_freq * irregularity

        # Fundamental + harmonics (odd harmonics give engine-like timbre)
        s = (
            0.5 * math.sin(phase) +
            0.25 * math.sin(2 * phase) +
            0.15 * math.sin(3 * phase) +
            0.08 * math.sin(4 * phase) +
            0.04 * math.sin(6 * phase)
        )
        samples.append(s)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 6 * math.pi:
            phase -= 6 * math.pi

    # Add some rumble noise
    noise = lowpass_filter(white_noise(n, seed=2), 200)
    combined = [samples[i] * 0.75 + noise[i] * 0.15 for i in range(n)]

    # Amplitude modulation for putter effect
    result = []
    for i, s in enumerate(combined):
        t = i / SAMPLE_RATE
        putter = 0.85 + 0.15 * math.sin(2 * math.pi * 14.0 * t)
        result.append(s * putter)

    return normalize(apply_envelope(result, attack=0.05, release=0.05))


def gen_prop_engine(duration: float = 4.0) -> list[float]:
    """
    Smoother propeller drone.
    150-200Hz steady hum with harmonic content.
    """
    n = int(duration * SAMPLE_RATE)
    rng = random.Random(3)

    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Steady frequency with gentle variation
        freq = 175.0 + 8.0 * math.sin(2 * math.pi * 0.4 * t)

        # Rich harmonic content for propeller
        s = (
            0.45 * math.sin(phase) +
            0.30 * math.sin(2 * phase) +
            0.15 * math.sin(3 * phase) +
            0.07 * math.sin(4 * phase) +
            0.03 * math.sin(5 * phase)
        )
        samples.append(s)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 10 * math.pi:
            phase -= 10 * math.pi

    # Very gentle amplitude modulation
    result = []
    for i, s in enumerate(samples):
        t = i / SAMPLE_RATE
        mod = 0.92 + 0.08 * math.sin(2 * math.pi * 8.5 * t)
        result.append(s * mod)

    # Slight noise floor
    noise = lowpass_filter(white_noise(n, seed=4), 400)
    combined = [result[i] * 0.88 + noise[i] * 0.08 for i in range(n)]

    return normalize(apply_envelope(combined, attack=0.05, release=0.05))


def gen_bomber_engine(duration: float = 5.0) -> list[float]:
    """
    Deep heavy rumble.
    60-100Hz throbbing bomber engine (4 engines implied).
    """
    n = int(duration * SAMPLE_RATE)

    # Four "engines" slightly detuned for beating effect
    freqs = [68.0, 72.0, 76.0, 80.0]
    phases = [0.0, 0.5, 1.0, 1.5]

    samples = [0.0] * n
    for fi, (base_freq, init_phase) in enumerate(zip(freqs, phases)):
        phase = init_phase
        for i in range(n):
            t = i / SAMPLE_RATE
            freq = base_freq + 3.0 * math.sin(2 * math.pi * 0.3 * t + fi)
            s = (
                0.5 * math.sin(phase) +
                0.25 * math.sin(2 * phase) +
                0.12 * math.sin(3 * phase) +
                0.08 * math.sin(4 * phase)
            )
            samples[i] += s * 0.25
            phase += 2 * math.pi * freq / SAMPLE_RATE
            if phase > 8 * math.pi:
                phase -= 8 * math.pi

    # Heavy throbbing envelope
    result = []
    for i, s in enumerate(samples):
        t = i / SAMPLE_RATE
        throb = 0.80 + 0.20 * math.sin(2 * math.pi * 6.0 * t)
        result.append(s * throb)

    # Low rumble noise
    noise = lowpass_filter(white_noise(n, seed=5), 150)
    combined = [result[i] * 0.82 + noise[i] * 0.12 for i in range(n)]

    return normalize(apply_envelope(combined, attack=0.08, release=0.08))


def gen_jet_engine(duration: float = 4.0) -> list[float]:
    """
    High-frequency jet whoosh.
    Broadband noise filtered to 2-6kHz range.
    """
    n = int(duration * SAMPLE_RATE)

    # Broadband noise bandpassed to jet frequency range
    noise = white_noise(n, seed=6)
    # Multiple filtering passes for sharper band
    bp = bandpass_filter(noise, 2000, 6000)
    bp2 = bandpass_filter(bp, 1500, 8000)

    # Add low turbine whine around 800Hz
    whine = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 820 + 30 * math.sin(2 * math.pi * 0.6 * t)
        s = math.sin(phase) * 0.3 + math.sin(2 * phase) * 0.15
        whine.append(s)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 4 * math.pi:
            phase -= 4 * math.pi

    # Low rumble underneath
    rumble = lowpass_filter(white_noise(n, seed=7), 120)

    combined = [
        bp2[i] * 0.55 +
        whine[i] * 0.25 +
        rumble[i] * 0.15
        for i in range(n)
    ]

    # Slight high-frequency shimmer
    result = []
    for i, s in enumerate(combined):
        t = i / SAMPLE_RATE
        shimmer = 0.93 + 0.07 * math.sin(2 * math.pi * 47.0 * t)
        result.append(s * shimmer)

    return normalize(apply_envelope(result, attack=0.06, release=0.06))


def gen_rocket_engine(duration: float = 4.0) -> list[float]:
    """
    Intense rocket roar.
    Layered noise + low frequency rumble.
    """
    n = int(duration * SAMPLE_RATE)

    # Wide-band noise (main roar)
    noise1 = white_noise(n, seed=8)
    noise_lp = lowpass_filter(noise1, 3000)

    # Mid-range crackle
    noise2 = bandpass_filter(white_noise(n, seed=9), 300, 1200)

    # Deep infrasonic rumble
    rumble = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        freq = 45.0 + 10 * math.sin(2 * math.pi * 0.8 * t)
        s = math.sin(phase) * 0.6 + math.sin(2 * phase) * 0.3 + math.sin(3 * phase) * 0.1
        rumble.append(s)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 6 * math.pi:
            phase -= 6 * math.pi

    # Combine all layers
    combined = [
        noise_lp[i] * 0.45 +
        noise2[i] * 0.30 +
        rumble[i] * 0.25
        for i in range(n)
    ]

    # Intensity fluctuation (combustion instability)
    result = []
    for i, s in enumerate(combined):
        t = i / SAMPLE_RATE
        flutter = 0.88 + 0.12 * (
            math.sin(2 * math.pi * 23.0 * t) * 0.5 +
            math.sin(2 * math.pi * 37.0 * t) * 0.5
        )
        result.append(s * flutter)

    return normalize(apply_envelope(result, attack=0.04, release=0.04))


def gen_wind(duration: float = 5.0) -> list[float]:
    """
    Gentle wind/breeze sound.
    Filtered noise, soft, atmospheric.
    """
    n = int(duration * SAMPLE_RATE)

    # Multiple noise layers filtered at different frequencies
    low_wind = lowpass_filter(white_noise(n, seed=10), 400)
    mid_wind = bandpass_filter(white_noise(n, seed=11), 200, 1200)

    # Very gentle AM for gusting
    result = []
    for i in range(n):
        t = i / SAMPLE_RATE
        gust = (
            0.75 +
            0.15 * math.sin(2 * math.pi * 0.3 * t) +
            0.10 * math.sin(2 * math.pi * 0.7 * t + 1.2)
        )
        s = low_wind[i] * 0.65 + mid_wind[i] * 0.35
        result.append(s * gust)

    return normalize(apply_envelope(result, attack=0.15, release=0.15), peak=0.6)


# ─────────────────────────────────────────────
# MUSIC TRACKS
# ─────────────────────────────────────────────

def apply_lofi_filter(samples: list[float]) -> list[float]:
    """Apply lo-fi character: slight high-cut, gentle saturation."""
    # High-cut for warmth (lo-fi sound)
    lp = lowpass_filter(samples, 8000)
    # Gentle tape saturation (soft clip)
    return [math.tanh(s * 1.3) * 0.77 for s in lp]


def note_to_freq(note: int) -> float:
    """MIDI note number to frequency. A4 = 69 = 440Hz."""
    return 440.0 * (2 ** ((note - 69) / 12.0))


def gen_piano_note(freq: float, duration: float, amp: float = 1.0) -> list[float]:
    """Generate a simple piano-like tone with decay envelope."""
    n = int(duration * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Quick attack, exponential decay
        env = math.exp(-t * 3.5) * (1.0 - math.exp(-t * 60.0))
        s = (
            math.sin(phase) * 0.50 +
            math.sin(2 * phase) * 0.25 +
            math.sin(3 * phase) * 0.12 +
            math.sin(4 * phase) * 0.08 +
            math.sin(6 * phase) * 0.05
        )
        samples.append(s * env * amp)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 12 * math.pi:
            phase -= 12 * math.pi
    return samples


def gen_kick(duration: float = 0.25) -> list[float]:
    """Generate a kick drum."""
    n = int(duration * SAMPLE_RATE)
    samples = []
    for i in range(n):
        t = i / SAMPLE_RATE
        # Pitch sweep from 150Hz to 40Hz
        freq = 150 * math.exp(-t * 20)
        env = math.exp(-t * 18)
        s = math.sin(2 * math.pi * freq * t)
        # Add click transient
        click = math.exp(-t * 200) * 0.5
        samples.append((s + click) * env)
    return samples


def gen_hihat(duration: float = 0.08, open_hat: bool = False) -> list[float]:
    """Generate a hi-hat."""
    decay = 2.0 if not open_hat else 12.0
    n = int(duration * SAMPLE_RATE if not open_hat else 0.15 * SAMPLE_RATE)
    noise = white_noise(n, seed=20)
    hp = bandpass_filter(noise, 6000, 16000)
    result = []
    for i, s in enumerate(hp):
        t = i / SAMPLE_RATE
        env = math.exp(-t * (decay * 10))
        result.append(s * env * 0.4)
    return result


def gen_snare(duration: float = 0.15) -> list[float]:
    """Generate a snare drum."""
    n = int(duration * SAMPLE_RATE)
    noise = white_noise(n, seed=25)
    bp = bandpass_filter(noise, 800, 5000)

    tone_phase = 0.0
    result = []
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 25)
        tone = math.sin(tone_phase) * 0.3
        result.append((bp[i] * 0.7 + tone) * env * 0.6)
        tone_phase += 2 * math.pi * 200 / SAMPLE_RATE
    return result


def overlay_samples(base: list[float], overlay: list[float], start_sample: int, amp: float = 1.0) -> list[float]:
    """Overlay samples onto base starting at start_sample."""
    result = list(base)
    for i, s in enumerate(overlay):
        idx = start_sample + i
        if idx < len(result):
            result[idx] += s * amp
    return result


def gen_lofi_track_01(duration: float = 12.0) -> list[float]:
    """
    Lofi chill beat Track 01.
    C major pentatonic melody in 4/4 at ~75 BPM.
    """
    n = int(duration * SAMPLE_RATE)
    bpm = 75.0
    beat = SAMPLE_RATE * 60.0 / bpm  # samples per beat

    # Base track
    result = [0.0] * n

    # C major pentatonic: C D E G A (MIDI: 60 61 64 67 69 72)
    melody_notes = [
        # (beat_offset, note, duration_beats, amp)
        (0, 72, 1.0, 0.6),   # C5
        (1, 69, 0.5, 0.5),   # A4
        (1.5, 67, 0.5, 0.5), # G4
        (2, 64, 1.0, 0.55),  # E4
        (3, 67, 0.5, 0.5),   # G4
        (3.5, 69, 0.5, 0.5), # A4
        (4, 72, 1.5, 0.6),   # C5
        (5.5, 67, 0.5, 0.5), # G4
        (6, 64, 1.0, 0.55),  # E4
        (7, 60, 1.0, 0.5),   # C4
        (8, 69, 0.75, 0.55), # A4
        (9, 67, 0.5, 0.5),   # G4
        (9.5, 64, 0.5, 0.5), # E4
        (10, 72, 1.0, 0.6),  # C5
        (11, 69, 1.0, 0.55), # A4
    ]

    for (beat_off, note, dur_beats, amp) in melody_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # Bass line (root notes, lower octave)
    bass_notes = [
        (0, 48, 1.0, 0.45),  # C3
        (2, 43, 1.0, 0.40),  # G2
        (4, 48, 1.0, 0.45),  # C3
        (6, 45, 1.0, 0.40),  # A2
        (8, 48, 1.0, 0.45),  # C3
        (10, 43, 1.0, 0.40), # G2
    ]
    for (beat_off, note, dur_beats, amp) in bass_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # Kick on beats 1, 3 (every 2 beats)
    kick = gen_kick()
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 2 == 0:
            start = int(beat_idx * beat)
            result = overlay_samples(result, kick, start, 0.6)

    # Snare on beats 2, 4
    snare = gen_snare()
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 2 == 1:
            start = int(beat_idx * beat)
            result = overlay_samples(result, snare, start, 0.5)

    # Hi-hat every half beat
    hihat = gen_hihat()
    for beat_idx_h in range(int(duration * bpm / 30)):
        start = int(beat_idx_h * beat / 2)
        amp_h = 0.35 if beat_idx_h % 2 == 0 else 0.20
        result = overlay_samples(result, hihat, start, amp_h)

    result = apply_lofi_filter(result)
    return normalize(apply_envelope(result, attack=0.1, release=0.1), peak=0.80)


def gen_lofi_track_02(duration: float = 13.0) -> list[float]:
    """
    Lofi chill beat Track 02.
    A minor pentatonic melody at ~68 BPM.
    Different key and slightly slower tempo.
    """
    n = int(duration * SAMPLE_RATE)
    bpm = 68.0
    beat = SAMPLE_RATE * 60.0 / bpm

    result = [0.0] * n

    # A minor pentatonic: A C D E G (MIDI: 57 60 62 64 67 69)
    melody_notes = [
        (0, 69, 1.0, 0.6),   # A4
        (1, 67, 0.5, 0.5),   # G4
        (1.5, 64, 0.5, 0.5), # E4
        (2, 62, 1.5, 0.55),  # D4
        (3.5, 60, 0.5, 0.5), # C4
        (4, 64, 1.0, 0.6),   # E4
        (5, 67, 0.75, 0.55), # G4
        (5.75, 69, 1.25, 0.6),# A4
        (7, 64, 1.0, 0.55),  # E4
        (8, 60, 0.5, 0.5),   # C4
        (8.5, 62, 0.5, 0.5), # D4
        (9, 67, 1.0, 0.55),  # G4
        (10, 69, 1.5, 0.6),  # A4
        (11.5, 67, 1.5, 0.5),# G4
    ]

    for (beat_off, note, dur_beats, amp) in melody_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # Bass line
    bass_notes = [
        (0, 45, 1.5, 0.45),  # A2
        (2, 43, 1.0, 0.40),  # G2
        (4, 45, 1.5, 0.45),  # A2
        (6, 40, 1.0, 0.40),  # E2
        (8, 45, 1.5, 0.45),  # A2
        (10, 43, 1.0, 0.40), # G2
    ]
    for (beat_off, note, dur_beats, amp) in bass_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # Slightly different drum pattern (half-time feel)
    kick = gen_kick()
    for beat_idx in range(int(duration * bpm / 60)):
        # Kick on 1 and 3
        if beat_idx % 4 in [0, 2]:
            start = int(beat_idx * beat)
            result = overlay_samples(result, kick, start, 0.65)

    snare = gen_snare()
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 4 == 2:
            start = int(beat_idx * beat)
            result = overlay_samples(result, snare, start, 0.55)

    hihat = gen_hihat(open_hat=True)
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 2 == 1:
            start = int(beat_idx * beat)
            result = overlay_samples(result, hihat, start, 0.30)

    result = apply_lofi_filter(result)
    return normalize(apply_envelope(result, attack=0.1, release=0.1), peak=0.80)


def gen_lofi_track_03(duration: float = 14.0) -> list[float]:
    """
    Lofi chill beat Track 03.
    F major pentatonic at ~80 BPM with more rhythmic variation.
    """
    n = int(duration * SAMPLE_RATE)
    bpm = 80.0
    beat = SAMPLE_RATE * 60.0 / bpm

    result = [0.0] * n

    # F major pentatonic: F G A C D (MIDI: 65 67 69 72 74)
    melody_notes = [
        (0, 72, 0.75, 0.6),   # C5
        (0.75, 74, 0.5, 0.55),# D5
        (1.25, 72, 0.5, 0.5), # C5
        (1.75, 69, 0.75, 0.55),# A4
        (2.5, 67, 0.5, 0.5),  # G4
        (3, 65, 1.0, 0.6),    # F4
        (4, 69, 0.5, 0.55),   # A4
        (4.5, 72, 1.0, 0.6),  # C5
        (5.5, 74, 0.75, 0.55),# D5
        (6.25, 72, 0.5, 0.5), # C5
        (6.75, 67, 0.75, 0.55),# G4
        (7.5, 65, 0.5, 0.5),  # F4
        (8, 72, 1.0, 0.6),    # C5
        (9, 69, 0.5, 0.55),   # A4
        (9.5, 67, 0.5, 0.5),  # G4
        (10, 65, 1.5, 0.6),   # F4
        (11.5, 67, 0.5, 0.5), # G4
        (12, 69, 1.0, 0.55),  # A4
        (13, 65, 1.0, 0.5),   # F4
    ]

    for (beat_off, note, dur_beats, amp) in melody_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # Bass line
    bass_notes = [
        (0, 53, 1.0, 0.45),  # F2
        (2, 55, 1.0, 0.40),  # G2
        (4, 53, 1.0, 0.45),  # F2
        (6, 57, 1.0, 0.40),  # A2
        (8, 53, 1.0, 0.45),  # F2
        (10, 55, 1.0, 0.40), # G2
        (12, 53, 2.0, 0.45), # F2
    ]
    for (beat_off, note, dur_beats, amp) in bass_notes:
        freq = note_to_freq(note)
        dur_s = dur_beats * 60.0 / bpm
        tone = gen_piano_note(freq, dur_s, amp)
        start = int(beat_off * beat)
        result = overlay_samples(result, tone, start)

    # More energetic drum pattern
    kick = gen_kick()
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 4 in [0, 3]:
            start = int(beat_idx * beat)
            result = overlay_samples(result, kick, start, 0.60)

    snare = gen_snare()
    for beat_idx in range(int(duration * bpm / 60)):
        if beat_idx % 4 in [1, 2]:
            start = int(beat_idx * beat)
            result = overlay_samples(result, snare, start, 0.45)

    hihat = gen_hihat()
    for beat_idx_h in range(int(duration * bpm / 30)):
        start = int(beat_idx_h * beat / 2)
        amp_h = 0.30 if beat_idx_h % 4 in [0, 2] else 0.18
        result = overlay_samples(result, hihat, start, amp_h)

    result = apply_lofi_filter(result)
    return normalize(apply_envelope(result, attack=0.1, release=0.1), peak=0.80)


# ─────────────────────────────────────────────
# SFX
# ─────────────────────────────────────────────

def gen_clue_pop(duration: float = 0.4) -> list[float]:
    """
    Short pop/bubble sound.
    Quick frequency sweep upward.
    """
    n = int(duration * SAMPLE_RATE)
    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Exponential sweep from 200Hz to 800Hz
        freq = 200 * math.exp(t * math.log(800 / 200) / duration)
        # Sharp pop envelope
        env = math.exp(-t * 18) * (1 - math.exp(-t * 200))
        s = math.sin(phase) * 0.7 + math.sin(2 * phase) * 0.2 + math.sin(3 * phase) * 0.1
        samples.append(s * env)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 6 * math.pi:
            phase -= 6 * math.pi
    return normalize(samples, peak=0.85)


def gen_landing_success(duration: float = 0.9) -> list[float]:
    """
    Triumphant short chime.
    Ascending notes in quick succession.
    """
    n = int(duration * SAMPLE_RATE)
    result = [0.0] * n

    # Ascending major arpeggio: C E G C (higher)
    chord_notes = [
        (0.0, 523.25, 0.35),   # C5
        (0.15, 659.25, 0.35),  # E5
        (0.30, 783.99, 0.35),  # G5
        (0.50, 1046.50, 0.40), # C6
    ]

    for (t_start, freq, amp) in chord_notes:
        note_dur = duration - t_start
        note_n = int(note_dur * SAMPLE_RATE)
        note_samples = []
        phase = 0.0
        for i in range(note_n):
            t = i / SAMPLE_RATE
            env = math.exp(-t * 5.0) * (1 - math.exp(-t * 80))
            s = (
                math.sin(phase) * 0.5 +
                math.sin(2 * phase) * 0.3 +
                math.sin(3 * phase) * 0.15 +
                math.sin(4 * phase) * 0.05
            )
            note_samples.append(s * env * amp)
            phase += 2 * math.pi * freq / SAMPLE_RATE
            if phase > 8 * math.pi:
                phase -= 8 * math.pi

        start_idx = int(t_start * SAMPLE_RATE)
        result = overlay_samples(result, note_samples, start_idx)

    return normalize(result, peak=0.85)


def gen_coin_collect(duration: float = 0.35) -> list[float]:
    """
    Quick coin ding.
    High metallic ping with fast decay.
    """
    n = int(duration * SAMPLE_RATE)
    samples = []
    phase1, phase2, phase3 = 0.0, 0.0, 0.0
    freq1 = 1318.5  # E6 (high metallic)
    freq2 = 2093.0  # C7 (sparkle)
    freq3 = 880.0   # A5 (body)

    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 15) * (1 - math.exp(-t * 300))

        s = (
            math.sin(phase1) * 0.5 +
            math.sin(phase2) * 0.3 +
            math.sin(phase3) * 0.2
        )
        samples.append(s * env)
        phase1 += 2 * math.pi * freq1 / SAMPLE_RATE
        phase2 += 2 * math.pi * freq2 / SAMPLE_RATE
        phase3 += 2 * math.pi * freq3 / SAMPLE_RATE
        for p in [phase1, phase2, phase3]:
            if p > 2 * math.pi:
                p -= 2 * math.pi  # noqa

    return normalize(samples, peak=0.85)


def gen_ui_click(duration: float = 0.06) -> list[float]:
    """
    Soft UI click.
    Very short transient, neutral timbre.
    """
    n = int(duration * SAMPLE_RATE)
    # Filtered noise burst with rapid decay
    noise = white_noise(n, seed=30)
    bp = bandpass_filter(noise, 800, 4000)

    samples = []
    for i, s in enumerate(bp):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 120) * (1 - math.exp(-t * 1000))
        samples.append(s * env * 0.7)

    # Add a quick tonal component
    phase = 0.0
    freq = 1200.0
    for i in range(n):
        t = i / SAMPLE_RATE
        env = math.exp(-t * 150)
        samples[i] += math.sin(phase) * env * 0.4
        phase += 2 * math.pi * freq / SAMPLE_RATE

    return normalize(samples, peak=0.80)


def gen_altitude_change(duration: float = 0.6) -> list[float]:
    """
    Whoosh/sweep sound.
    Frequency sweep through mid range.
    """
    n = int(duration * SAMPLE_RATE)

    # Bandpassed noise sweep
    noise = white_noise(n, seed=35)

    # Sweep center frequency from low to high (whoosh up)
    result = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Rising sweep: 300Hz to 1800Hz
        freq = 300 * math.exp(t * math.log(1800 / 300) / duration)
        env = math.sin(math.pi * t / duration)  # Hanning window

        # Sine tone component
        tone = math.sin(phase) * 0.4

        # Noise component
        noise_val = noise[i] * 0.3

        result.append((tone + noise_val) * env)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 2 * math.pi:
            phase -= 2 * math.pi

    return normalize(result, peak=0.82)


def gen_boost_start(duration: float = 0.8) -> list[float]:
    """
    Power-up acceleration sound.
    Rising pitch with increasing intensity.
    """
    n = int(duration * SAMPLE_RATE)
    noise = white_noise(n, seed=40)
    noise_hp = highpass_filter(noise, 800)

    samples = []
    phase = 0.0
    for i in range(n):
        t = i / SAMPLE_RATE
        # Rising frequency: 200Hz to 1200Hz
        freq = 200 * math.exp(t * math.log(1200 / 200) / duration)

        # Rising amplitude envelope
        env = (t / duration) ** 0.5 * math.exp(-((t - duration) ** 2) * 8)
        env = max(0.0, env)

        # Rich harmonics for power feel
        s = (
            math.sin(phase) * 0.45 +
            math.sin(2 * phase) * 0.30 +
            math.sin(3 * phase) * 0.15 +
            math.sin(4 * phase) * 0.10
        )

        # Noise burst increases
        noise_amp = (t / duration) * 0.25
        result_s = s * 0.75 + noise_hp[i] * noise_amp
        samples.append(result_s * env)
        phase += 2 * math.pi * freq / SAMPLE_RATE
        if phase > 8 * math.pi:
            phase -= 8 * math.pi

    return normalize(samples, peak=0.85)


# ─────────────────────────────────────────────
# MAIN GENERATION
# ─────────────────────────────────────────────

def main():
    base = "/home/user/flit/assets/audio"

    files = [
        # Engines
        (f"{base}/engines/biplane_engine.mp3", gen_biplane_engine, {"duration": 4.0}),
        (f"{base}/engines/prop_engine.mp3", gen_prop_engine, {"duration": 4.0}),
        (f"{base}/engines/bomber_engine.mp3", gen_bomber_engine, {"duration": 5.0}),
        (f"{base}/engines/jet_engine.mp3", gen_jet_engine, {"duration": 4.0}),
        (f"{base}/engines/rocket_engine.mp3", gen_rocket_engine, {"duration": 4.0}),
        (f"{base}/engines/wind.mp3", gen_wind, {"duration": 5.0}),

        # Music
        (f"{base}/music/lofi_track_01.mp3", gen_lofi_track_01, {"duration": 12.0}),
        (f"{base}/music/lofi_track_02.mp3", gen_lofi_track_02, {"duration": 13.0}),
        (f"{base}/music/lofi_track_03.mp3", gen_lofi_track_03, {"duration": 14.0}),

        # SFX
        (f"{base}/sfx/clue_pop.mp3", gen_clue_pop, {"duration": 0.4}),
        (f"{base}/sfx/landing_success.mp3", gen_landing_success, {"duration": 0.9}),
        (f"{base}/sfx/coin_collect.mp3", gen_coin_collect, {"duration": 0.35}),
        (f"{base}/sfx/ui_click.mp3", gen_ui_click, {"duration": 0.06}),
        (f"{base}/sfx/altitude_change.mp3", gen_altitude_change, {"duration": 0.6}),
        (f"{base}/sfx/boost_start.mp3", gen_boost_start, {"duration": 0.8}),
    ]

    print(f"Generating {len(files)} audio files...\n")

    for path, gen_fn, kwargs in files:
        name = os.path.basename(path)
        print(f"Generating {name}...")
        samples = gen_fn(**kwargs)
        encode_mp3(samples, path)

    print(f"\nDone! Generated {len(files)} files.")


if __name__ == "__main__":
    main()
