import numpy as np
from PIL import Image
D = "@HOME@/.config/mogo/art/"
N = 1500
y2, x2 = np.mgrid[0:N, 0:N].astype(np.float32)
Rp = N * 0.4159
nx, ny = (x2 - N / 2) / Rp, (y2 - N / 2) / Rp
rr = np.sqrt(nx * nx + ny * ny)
side = np.clip(0.5 - 0.5 * (nx * 0.84 + ny * 0.54) / np.maximum(rr, 1e-4), 0, 1)
o = np.maximum(rr - 1, 0)
atmo = (np.exp(-o * 22) * (0.12 + 0.88 * side ** 1.3) + np.exp(-o * 6) * 0.2 * (0.1 + 0.9 * side)) * (rr >= 0.995)
t = np.clip((1.19 - rr) / (1.19 - 1.02), 0, 1)
atmo *= t * t * (3 - 2 * t)
lantern = np.array([0.326, 0.96, 0.664]) * 255
img = np.dstack([np.ones((N, N, 3)) * lantern, np.clip(atmo * 0.85, 0, 1) * 255])
Image.fromarray(img.astype(np.uint8), "RGBA").save(D + "atmo.png", optimize=True)
print("ok")
