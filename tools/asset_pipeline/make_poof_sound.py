"""Synthétise le « poof » de disparition en fumée (ramassage ninja) : souffle de bruit filtré
qui s'ouvre puis se referme, avec un petit coup sourd. Sortie : assets/sounds/pickup/poof.ogg.

Usage : python3 tools/asset_pipeline/make_poof_sound.py   (nécessite numpy et ffmpeg)
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
DURATION = 0.55
OUT = Path(__file__).resolve().parents[2] / "assets/sounds/pickup/poof.ogg"


def one_pole_lowpass(signal: np.ndarray, cutoff: np.ndarray) -> np.ndarray:
    """Passe-bas à un pôle dont la fréquence de coupure varie dans le temps."""
    alpha = 1.0 - np.exp(-2.0 * np.pi * cutoff / RATE)
    out = np.empty_like(signal)
    acc = 0.0
    for i, (x, a) in enumerate(zip(signal, alpha)):
        acc += a * (x - acc)
        out[i] = acc
    return out


def main() -> None:
    rng = np.random.default_rng(7)
    t = np.arange(int(RATE * DURATION)) / RATE
    noise = rng.uniform(-1.0, 1.0, t.size)
    # Souffle : la coupure monte très vite (l'air est chassé) puis redescend en s'étouffant.
    cutoff = 300.0 + 5200.0 * np.exp(-t / 0.07) * (1.0 - np.exp(-t / 0.006))
    breath = one_pole_lowpass(one_pole_lowpass(noise, cutoff), cutoff)
    breath -= one_pole_lowpass(breath, np.full(t.size, 120.0))  # retire le grondement
    envelope = (1.0 - np.exp(-t / 0.004)) * np.exp(-t / 0.11)
    breath *= envelope
    # Petit coup sourd au début (le « pof »), fréquence qui chute.
    phase = 2.0 * np.pi * np.cumsum(70.0 + 110.0 * np.exp(-t / 0.03)) / RATE
    thump = np.sin(phase) * np.exp(-t / 0.05) * (1.0 - np.exp(-t / 0.002))
    mix = breath / np.max(np.abs(breath)) * 0.8 + thump * 0.45
    mix *= 0.85 / np.max(np.abs(mix))
    fade = np.minimum(1.0, (t[-1] - t) / 0.05)
    pcm = (mix * fade * 32767).astype(np.int16)

    OUT.parent.mkdir(parents=True, exist_ok=True)
    wav_path = OUT.with_suffix(".wav")
    with wave.open(str(wav_path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "5", str(OUT)], check=True)
    wav_path.unlink()
    print("écrit :", OUT)


if __name__ == "__main__":
    sys.exit(main())
