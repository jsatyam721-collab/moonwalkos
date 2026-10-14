import numpy as np
from PIL import Image

D = "@HOME@/.config/mogo/art/"
src = np.asarray(Image.open(D + "crop_x4.png").convert("RGB")).astype(np.float32) / 255
S0 = src.shape[0]
R = (S0 - 2 * 6 * 4) / 2
pad = int(R * 0.18)
N = S0 + 2 * pad
c = N / 2

img = np.zeros((N, N, 3), np.float32)
img[pad:pad + S0, pad:pad + S0] = src
y, x = np.mgrid[0:N, 0:N].astype(np.float32)
nx, ny = (x - c) / R, (y - c) / R
rr = np.sqrt(nx * nx + ny * ny)
inside = rr < 1
nz = np.sqrt(np.clip(1 - rr * rr, 0, 1))

L = np.array([-0.62, -0.42, 0.66]); L /= np.linalg.norm(L)
ndl = nx * L[0] + ny * L[1] + nz * L[2]
diffuse = np.clip(ndl, 0, 1)
terminator = 0.5 + 0.5 * np.tanh(ndl * 5.0)
shade = 0.18 + 0.95 * (0.35 * terminator + 0.65 * diffuse ** 0.85)
limb = (0.35 + 0.65 * nz ** 0.45)
lantern = np.array([0.36, 1.0, 0.48])

col = img * (0.45 + 0.55 * shade)[..., None] * limb[..., None]

H = L + np.array([0, 0, 1.0]); H /= np.linalg.norm(H)
ndh = np.clip(nx * H[0] + ny * H[1] + nz * H[2], 0, 1)
col += (ndh ** 60)[..., None] * 0.22 * np.array([0.85, 1.0, 0.88])

fres = (1 - nz) ** 3.2
lit = np.clip(0.35 + 0.65 * (-(nx * L[0] + ny * L[1]) / np.maximum(rr, 1e-4) * -1 + 1) / 2, 0, 1)
side = np.clip(0.5 - 0.5 * (nx * 0.84 + ny * 0.54) / np.maximum(rr, 1e-4), 0, 1)
col += fres[..., None] * lantern * (0.08 + 0.92 * side ** 1.4)[..., None] * 0.95

edge = np.clip((1 - rr) * R / 1.6, 0, 1)
col = col * edge[..., None]

out = np.maximum(rr - 1, 0)
atmo = np.exp(-out * 22) * (0.12 + 0.88 * side ** 1.3) + np.exp(-out * 6) * 0.2 * (0.1 + 0.9 * side)
atmo *= (rr >= 0.985)
atmo_rgb = lantern * atmo[..., None]

alpha_planet = edge
alpha = np.clip(alpha_planet + atmo * 0.85, 0, 1)
rgb = col + atmo_rgb * (1 - alpha_planet[..., None])
rgb_straight = np.where(alpha[..., None] > 1e-4, rgb / np.maximum(alpha[..., None], 1e-4), 0)

final = np.dstack([np.clip(rgb_straight, 0, 1), alpha]) * 255
out_img = Image.fromarray(final.astype(np.uint8), "RGBA").resize((1500, 1500), Image.LANCZOS)
out_img.save(D + "planet.png", optimize=True)
print("planet radius fraction of canvas:", round(R / N, 4))
