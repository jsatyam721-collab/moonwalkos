import numpy as np
from PIL import Image
from scipy import ndimage

D = "@HOME@/.config/mogo/art/"
src = np.asarray(Image.open(D + "crop_x4.png").convert("RGB")).astype(np.float32)
S0 = src.shape[0]
R = (S0 - 48) / 2
C = S0 / 2

W, H = 2048, 1024
lon = (np.arange(W) + 0.5) / W * 2 * np.pi - np.pi
lat = (np.arange(H) + 0.5) / H * np.pi - np.pi / 2
LON, LAT = np.meshgrid(lon, lat)

front = np.where(np.abs(LON) <= np.pi / 2, LON, np.sign(LON) * np.pi - LON)
front = np.clip(front, -1.52, 1.52)
lat_c = np.clip(LAT, -1.52, 1.52)
x = np.sin(front) * np.cos(lat_c)
y = np.sin(lat_c)
px = C + x * R * 0.965
py = C + y * R * 0.965

out = np.dstack([ndimage.map_coordinates(src[..., k], [py, px], order=1, mode="nearest") for k in range(3)])

seam = np.abs(np.abs(LON) - np.pi / 2)
blur = ndimage.gaussian_filter(out, sigma=(0, 8, 0))
w = np.clip(1 - seam / 0.25, 0, 1)[..., None]
out = out * (1 - w) + blur * w

Image.fromarray(np.clip(out, 0, 255).astype(np.uint8)).save(D + "surface.png", optimize=True)

N = 1500
y2, x2 = np.mgrid[0:N, 0:N].astype(np.float32)
Rp = N * 0.4159
nx, ny = (x2 - N / 2) / Rp, (y2 - N / 2) / Rp
rr = np.sqrt(nx * nx + ny * ny)
side = np.clip(0.5 - 0.5 * (nx * 0.84 + ny * 0.54) / np.maximum(rr, 1e-4), 0, 1)
o = np.maximum(rr - 1, 0)
atmo = (np.exp(-o * 22) * (0.12 + 0.88 * side ** 1.3) + np.exp(-o * 6) * 0.2 * (0.1 + 0.9 * side)) * (rr >= 0.995)
lantern = np.array([0.36, 1.0, 0.48]) * 255
img = np.dstack([np.ones((N, N, 3)) * lantern, np.clip(atmo * 0.85, 0, 1) * 255])
Image.fromarray(img.astype(np.uint8), "RGBA").save(D + "atmo.png", optimize=True)
print("ok")
