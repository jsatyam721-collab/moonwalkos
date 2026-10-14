import os

import numpy as np
from PIL import Image, ImageFilter
from scipy.ndimage import gaussian_filter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_W, OUT_H = 1920, 1080
TOP, HORIZON = 15, 326

src = np.asarray(Image.open(f"{HERE}/reference.png").convert("RGB")).astype(np.float32)
h, w, _ = src.shape

L = src @ np.float32([0.299, 0.587, 0.114])
mirror = L[:, ::-1]
y0, y1, x1 = 180, HORIZON, 420
ratio = gaussian_filter(mirror, 18) / np.maximum(gaussian_filter(L, 18), 1.0)
fix = np.ones_like(L)
fix[y0:y1, :x1] = np.clip(ratio[y0:y1, :x1], 0.2, 1.0)
ramp_y = np.clip((np.arange(h) - y0) / 40.0, 0, 1)[:, None]
ramp_x = np.clip((x1 - np.arange(w)) / 60.0, 0, 1)[None, :]
fix = 1.0 - (1.0 - fix) * ramp_y * ramp_x
fix = gaussian_filter(fix, 6)
scene = src * fix[..., None]

floor_h = h - HORIZON
refl = scene[HORIZON - floor_h:HORIZON][::-1].copy()
refl = gaussian_filter(refl, sigma=(9, 4, 0))
rng = np.random.default_rng(3)
ripple = gaussian_filter(rng.normal(0, 1, (floor_h, w)), sigma=(1.2, 14))
ripple = 1.0 - 0.25 * np.clip(ripple * 3.0, 0, 1) * np.clip(np.arange(floor_h) / 30.0, 0, 1)[:, None]
depth = (0.07 + 0.93 * np.exp(-np.arange(floor_h) / 38.0))[:, None]
refl = refl * (ripple * depth)[..., None]
pave = gaussian_filter(scene[HORIZON - 30:HORIZON].mean(axis=0, keepdims=True), sigma=(0, 30, 0))
pave = np.repeat(pave, floor_h, axis=0) * np.linspace(0.6, 0.25, floor_h)[:, None, None]
floor = refl + pave * 0.5 * np.clip(np.arange(floor_h) / 40.0, 0, 1)[:, None, None]
full = np.concatenate([scene[:HORIZON], floor], axis=0)[TOP:]

img = Image.fromarray(np.clip(full, 0, 255).astype(np.uint8))
scale = OUT_H / img.height
img = img.resize((round(img.width * scale), OUT_H), Image.LANCZOS)
left = (img.width - OUT_W) // 2
img = img.crop((left, 0, left + OUT_W, OUT_H))
img = img.filter(ImageFilter.UnsharpMask(radius=2.2, percent=60, threshold=2))
a = np.asarray(img).astype(np.float32)
grain = gaussian_filter(rng.normal(0, 1, (OUT_H, OUT_W)), 0.7) * 5.5
yy, xx = np.mgrid[0:OUT_H, 0:OUT_W]
vig = 1.0 - 0.38 * (((xx - OUT_W / 2) / (OUT_W / 2)) ** 2 + ((yy - OUT_H * 0.45) / (OUT_H * 0.75)) ** 2)
a = (a + grain[..., None]) * np.clip(vig, 0.45, 1.0)[..., None]
Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).save(f"{HERE}/backdrop.png")

glass = Image.fromarray(np.clip(a, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26))
Image.fromarray((np.asarray(glass).astype(np.float32) * 0.9 + 22).clip(0, 255).astype(np.uint8)).save(f"{HERE}/glass.png")

G = 512
gy, gx = np.mgrid[0:G, 0:G]
r = np.hypot(gx - G / 2, gy - G / 2) / (G / 2)
glow = np.clip(1 - r, 0, 1) ** 2.2
rgba = np.zeros((G, G, 4), np.float32)
rgba[..., 0], rgba[..., 1], rgba[..., 2] = 255, 244, 214
rgba[..., 3] = glow * 255
Image.fromarray(rgba.astype(np.uint8), "RGBA").save(f"{HERE}/glow.png")

FW, FH = 1920, 540
fog = gaussian_filter(rng.normal(0, 1, (FH, FW)), sigma=(40, 120), mode="wrap")
fog = gaussian_filter(np.clip(fog * 4, 0, 1), 10, mode="wrap")
fade = np.clip(np.sin(np.linspace(0, np.pi, FH)), 0, 1)[:, None] ** 1.5
frgba = np.zeros((FH, FW, 4), np.float32)
frgba[..., :3] = 225
frgba[..., 3] = fog * fade * 60
Image.fromarray(frgba.astype(np.uint8), "RGBA").save(f"{HERE}/fog.png")
print("baked", img.size)
