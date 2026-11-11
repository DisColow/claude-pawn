"""Bouffée de fumée « cartoon » pour la disparition ninja : blanche, opaque au cœur, bord net.
Dérivée de assets/vfx/smoke_07.png (Kenney Particle Pack, CC0). Sortie : assets/vfx/poof_puff.png.

Usage : python3 tools/asset_pipeline/make_poof_texture.py   (nécessite Pillow et numpy)
"""
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
source = np.asarray(Image.open(ROOT / "assets/vfx/smoke_07.png").convert("RGBA"), dtype=np.float32) / 255.0
luminance = source[..., :3].mean(axis=2)
coverage = source[..., 3] * luminance
coverage /= coverage.max()
# Opacité poussée (cœur plein, bord encore doux) et volume léger : blanc, ombré gris clair.
alpha = np.clip((coverage - 0.08) / 0.32, 0.0, 1.0) ** 0.8
shade = 0.78 + 0.22 * np.clip(luminance / max(luminance.max(), 1e-6), 0.0, 1.0)
rgba = np.dstack([shade, shade, shade * 1.02, alpha])
Image.fromarray((np.clip(rgba, 0.0, 1.0) * 255).astype(np.uint8)).resize((256, 256), Image.LANCZOS).save(ROOT / "assets/vfx/poof_puff.png")
print("écrit : assets/vfx/poof_puff.png")
