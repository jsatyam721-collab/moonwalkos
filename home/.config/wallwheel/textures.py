import numpy as np
from PIL import Image

OUT = "@HOME@/.config/wallwheel/"
rng = np.random.default_rng(3)


def polar(d):
    y, x = np.mgrid[0:d, 0:d].astype(np.float32)
    c = (d - 1) / 2
    x, y = x - c, y - c
    return np.hypot(x, y) / (d / 2), np.arctan2(y, x), y / (d / 2)


def brushed(r, d, amp):
    line = rng.normal(0, 1, 4096).astype(np.float32)
    line = np.convolve(line, np.ones(3) / 3, "same")
    idx = np.clip((r * 2048).astype(int), 0, 4095)
    return line[idx] * amp


def grain(d, amp):
    return rng.normal(0, amp, (d, d)).astype(np.float32)


def save(rgb, alpha, name):
    rgba = np.dstack([np.clip(rgb, 0, 1), np.clip(alpha, 0, 1)])
    Image.fromarray(np.uint8(rgba * 255), "RGBA").save(OUT + name)


def disc_alpha(r, d, inner=0.0):
    px = 2 / d
    a = np.clip((1 - r) / px, 0, 1)
    if inner:
        a *= np.clip((r - inner) / px, 0, 1)
    return a


d = 940
r, th, yy = polar(d)
v = 0.115 + brushed(r, d, 0.012) + grain(d, 0.012)
v += -yy * 0.025
v -= np.clip((r - 0.9) / 0.1, 0, 1) ** 2 * 0.05
for g in (0.52, 0.58, 0.985):
    v -= np.exp(-((r - g) / 0.0025) ** 2) * 0.05
    v += np.exp(-((r - g - 0.004) / 0.0025) ** 2) * 0.03
save(np.dstack([v, v, v * 1.08]), disc_alpha(r, d), "plate.png")

d = 460
r, th, yy = polar(d)
v = 0.6 + 0.22 * np.cos(2 * th + 0.6) + 0.08 * np.cos(6 * th) + brushed(r, d, 0.035) + grain(d, 0.015)
v -= np.exp(-((r - 0.86) / 0.006) ** 2) * 0.25
v -= np.clip((r - 0.95) / 0.05, 0, 1) * 0.2
save(np.dstack([v, v, v * 1.04]), disc_alpha(r, d), "bezel.png")

d = 392
r, th, yy = polar(d)
v = brushed(r, d, 0.01) + grain(d, 0.02) - yy * 0.02
v -= np.clip((r - 0.8) / 0.2, 0, 1) ** 2 * 0.07
base = np.array([0x2a, 0x26, 0x20], np.float32) / 255
save(base + v[..., None], disc_alpha(r, d), "face.png")

d = 1240
r, th, yy = polar(d)
r = r * 310 / 236
v = 0.11 + brushed(r * 236 / 310, d, 0.011) + grain(d, 0.012)
for g in (122, 129, 150):
    v -= np.exp(-((r * 236 - g) / 0.7) ** 2) * 0.05
    v += np.exp(-((r * 236 - g - 1.1) / 0.7) ** 2) * 0.035
knurl = (np.abs(r * 236 - 120) < 3.2) * (np.cos(th * 180) > 0.2)
v -= knurl * 0.045
v -= np.clip((r - 0.93) / 0.07, 0, 1) ** 2 * 0.03
save(np.dstack([v, v, v * 1.08]), np.ones_like(v), "housing.png")
