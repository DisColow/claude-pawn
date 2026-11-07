# Texture de terre battue pour les clairières (décalque) : deux tons, craquelures, bord irrégulier.
# usage : python3 make_dirt_texture.py assets/textures/dirt_clearing.png
import sys, math
import numpy as np
from PIL import Image, ImageFilter

S = 512
rng = np.random.default_rng(11)


def value_noise(size, cells, seed):
    r = np.random.default_rng(seed).random((cells + 1, cells + 1))
    x = np.linspace(0, cells, size, endpoint=False)
    xi = x.astype(int); xf = x - xi
    xf = xf * xf * (3 - 2 * xf)
    a = r[np.ix_(xi, xi)]; b = r[np.ix_(xi + 1, xi)]; c = r[np.ix_(xi, xi + 1)]; d = r[np.ix_(xi + 1, xi + 1)]
    u = xf[:, None]; v = xf[None, :]
    return a * (1 - u) * (1 - v) + b * u * (1 - v) + c * (1 - u) * v + d * u * v


def fbm(size, seed, octaves=4, base=4):
    out = np.zeros((size, size)); amp = 1.0; total = 0.0
    for o in range(octaves):
        out += value_noise(size, base * 2 ** o, seed + o) * amp
        total += amp; amp *= 0.5
    return out / total


tone = fbm(S, 1)
detail = fbm(S, 20, octaves=3, base=16)
dark = np.array([0.50, 0.37, 0.24]); light = np.array([0.70, 0.56, 0.38])
t = np.clip((tone - 0.35) * 2.2 + (detail - 0.5) * 0.4, 0, 1)
rgb = dark[None, None, :] * (1 - t[..., None]) + light[None, None, :] * t[..., None]

# Craquelures : bords des cellules de Voronoï, légèrement assombris.
pts = rng.random((70, 2)) * S
yy, xx = np.mgrid[0:S, 0:S]
d = np.sort(np.stack([np.hypot(xx - px, yy - py) for px, py in pts]), axis=0)
edge = np.clip(1.0 - (d[1] - d[0]) / 3.0, 0, 1) * (fbm(S, 40) > 0.45)
rgb *= (1 - 0.12 * edge)[..., None]

# Bord irrégulier : disque déformé par du bruit, fondu doux.
cx = cy = S / 2
ang = np.arctan2(yy - cy, xx - cx); rad = np.hypot(xx - cx, yy - cy) / (S / 2)
wobble = 0.82 + 0.08 * np.sin(3 * ang + 1.0) + 0.05 * np.sin(7 * ang + 2.0) + (fbm(S, 60) - 0.5) * 0.25
alpha = np.clip((wobble - rad) / 0.12, 0, 1)

img = Image.fromarray((np.dstack([np.clip(rgb, 0, 1), alpha]) * 255).astype(np.uint8), "RGBA")
img.filter(ImageFilter.SMOOTH).save(sys.argv[1])
