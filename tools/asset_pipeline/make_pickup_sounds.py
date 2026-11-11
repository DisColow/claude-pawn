"""Synthétise les notes de ramassage des bûches : dix notes douces façon marimba / kalimba qui
montent une gamme pentatonique majeure (une par bûche de la pile, de la 1re à la 10e). La dixième
(charge pleine) se termine par un petit arpège. Sortie : assets/sounds/pickup/pickup_0.ogg … pickup_9.ogg.

Usage : python3 tools/asset_pipeline/make_pickup_sounds.py   (nécessite numpy et ffmpeg)
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

RATE = 44100
OUT_DIR = Path(__file__).resolve().parents[2] / "assets/sounds/pickup"
BASE_FREQ = 392.0  # sol 3 : assez grave pour que la 10e note (mi 5) ne soit pas stridente
# Pentatonique majeure sur deux octaves, en demi-tons : aucune note ne « frotte » avec la précédente.
SCALE = [0, 2, 4, 7, 9, 12, 14, 16, 19, 21]


def note(freq: float, duration: float) -> np.ndarray:
    """Une note de marimba : fondamentale ronde, partiels brefs, petit « plop » d'attaque."""
    t = np.arange(int(RATE * duration)) / RATE
    attack = 1.0 - np.exp(-t / 0.003)  # montée de 3 ms : pas de clic
    body = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.20)
    octave = 0.18 * np.sin(2 * np.pi * 2 * freq * t) * np.exp(-t / 0.10)
    # Partiel accordé à 4 fois la fondamentale, signature du marimba ; il s'éteint très vite.
    bar = 0.22 * np.sin(2 * np.pi * 4 * freq * t) * np.exp(-t / 0.035)
    # « Plop » : glissando très court qui monte jusqu'à la note (effet bulle).
    sweep = freq * (1.0 - 0.45 * np.exp(-t / 0.012))
    plop = 0.35 * np.sin(2 * np.pi * np.cumsum(sweep) / RATE) * np.exp(-t / 0.03)
    return (body + octave + bar + plop) * attack


def render(index: int) -> np.ndarray:
    freq = BASE_FREQ * 2 ** (SCALE[index] / 12)
    if index < len(SCALE) - 1:
        mix = note(freq, 0.7)
    else:
        # Charge pleine : la note, puis sa quinte et son octave en arpège rapide.
        mix = np.zeros(int(RATE * 1.0))
        for delay, ratio, gain in ((0.0, 1.0, 1.0), (0.09, 1.5, 0.8), (0.18, 2.0, 0.9)):
            part = note(freq * ratio, 1.0 - delay) * gain
            start = int(RATE * delay)
            mix[start:start + part.size] += part
    t = np.arange(mix.size) / RATE
    mix *= np.minimum(1.0, (t[-1] - t) / 0.08)  # fondu de sortie
    return mix * 0.7 / np.max(np.abs(mix))


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for index in range(len(SCALE)):
        pcm = (render(index) * 32767).astype(np.int16)
        out = OUT_DIR / ("pickup_%d.ogg" % index)
        wav_path = out.with_suffix(".wav")
        with wave.open(str(wav_path), "wb") as wav:
            wav.setnchannels(1)
            wav.setsampwidth(2)
            wav.setframerate(RATE)
            wav.writeframes(pcm.tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", str(wav_path), "-c:a", "libvorbis", "-q:a", "6", str(out)], check=True)
        wav_path.unlink()
        print("écrit :", out)


if __name__ == "__main__":
    sys.exit(main())
