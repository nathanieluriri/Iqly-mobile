"""Synthesises the iQLY notification sounds.

Bings are the light "idea" chimes, sirens the soft rising whistles. Each sound
is written as Ogg Vorbis for Android (res/raw) and as 16-bit PCM CAF for iOS
(ios/Runner/Sounds). Run from the repo root (needs numpy and ffmpeg):

    python3 tool/gen_sounds.py

then add any new sound to SOUNDS in lib/surfaces/notification_sounds.dart.
"""

import subprocess
import tempfile
import wave
from pathlib import Path

import numpy as np

RATE = 44100
ANDROID = Path('android/app/src/main/res/raw')
IOS = Path('ios/Runner/Sounds')


def time(seconds):
    return np.arange(int(RATE * seconds)) / RATE


def envelope(t, attack, decay):
    rise = np.clip(t / attack, 0, 1)
    return rise * np.exp(-t / decay)


def bell(freq, seconds, decay, brightness=1.0):
    """A small FM bell: a sine carrier with a decaying inharmonic modulator."""
    t = time(seconds)
    index = 2.2 * brightness * np.exp(-t / (decay * 0.35))
    tone = np.sin(2 * np.pi * freq * t + index * np.sin(2 * np.pi * freq * 1.41 * t))
    shimmer = 0.18 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / (decay * 0.3))
    return (tone + shimmer) * envelope(t, 0.004, decay)


def glide(start, end, seconds, curve=0.5):
    t = time(seconds)
    progress = (t / seconds) ** curve
    freq = start * (end / start) ** progress
    return 2 * np.pi * np.cumsum(freq) / RATE, t


def whistle(phase, t, vibrato_hz=0.0, vibrato_depth=0.0):
    wobble = vibrato_depth * np.sin(2 * np.pi * vibrato_hz * t)
    tone = np.sin(phase + wobble) + 0.12 * np.sin(2 * (phase + wobble))
    breath = np.random.default_rng(7).normal(0, 0.015, len(t))
    return tone + breath


def place(track, sound, at):
    start = int(RATE * at)
    end = min(len(track), start + len(sound))
    track[start:end] += sound[: end - start]
    return track


def fade(sound, out=0.15, into=0.006):
    n_out, n_in = int(RATE * out), int(RATE * into)
    sound[:n_in] *= np.linspace(0, 1, n_in)
    sound[-n_out:] *= np.linspace(1, 0, n_out)
    return sound


def bing_spark():
    return bell(1568, 1.4, 0.45)


def bing_idea():
    track = np.zeros(int(RATE * 1.6))
    place(track, 0.8 * bell(1319, 1.2, 0.3, 0.8), 0)
    place(track, bell(1976, 1.4, 0.5), 0.11)
    return track


def bing_glass():
    phase, t = glide(2093, 2349, 1.5, 0.15)
    tone = np.sin(phase) + 0.3 * np.sin(2.01 * phase) + 0.12 * np.sin(3.98 * phase)
    return tone * envelope(t, 0.003, 0.5)


def siren_whistle():
    rise, t1 = glide(880, 2200, 0.55, 0.6)
    hold_t = time(0.75)
    hold = rise[-1] + 2 * np.pi * 2200 * hold_t
    phase = np.concatenate([rise, hold])
    t = np.concatenate([t1, t1[-1] + hold_t])
    depth = np.clip((t - 0.5) * 4, 0, 1) * 0.9
    tone = whistle(phase, t, 6.0, 1.0) * (1 - 0.1 * depth)
    return fade(tone * envelope(t, 0.06, 2.5), out=0.35)


def siren_wail():
    t = time(2.0)
    freq = 1100 + 650 * (0.5 - 0.5 * np.cos(2 * np.pi * 1.0 * t))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return fade(whistle(phase, t) * envelope(t, 0.08, 3.0), out=0.4)


def siren_chirp():
    track = np.zeros(int(RATE * 1.2))
    for at, peak in ((0, 2000), (0.36, 2400)):
        phase, t = glide(1000, peak, 0.3, 0.7)
        place(track, fade(whistle(phase, t) * envelope(t, 0.02, 0.6), out=0.08), at)
    return track


SOUNDS = {
    'iqly_bing_spark': bing_spark,
    'iqly_bing_idea': bing_idea,
    'iqly_bing_glass': bing_glass,
    'iqly_siren_whistle': siren_whistle,
    'iqly_siren_wail': siren_wail,
    'iqly_siren_chirp': siren_chirp,
}


def write(name, samples):
    samples = samples / np.max(np.abs(samples)) * 0.7
    pcm = (samples * 32767).astype(np.int16)
    with tempfile.TemporaryDirectory() as tmp:
        source = Path(tmp) / f'{name}.wav'
        with wave.open(str(source), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(pcm.tobytes())
        ffmpeg = ['ffmpeg', '-loglevel', 'error', '-y', '-i', str(source)]
        subprocess.run([*ffmpeg, '-c:a', 'libvorbis', '-q:a', '4', str(ANDROID / f'{name}.ogg')], check=True)
        subprocess.run([*ffmpeg, '-c:a', 'pcm_s16le', '-f', 'caf', str(IOS / f'{name}.caf')], check=True)


if __name__ == '__main__':
    ANDROID.mkdir(parents=True, exist_ok=True)
    IOS.mkdir(parents=True, exist_ok=True)
    for name, make in SOUNDS.items():
        write(name, make())
        print(name)
