import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

D = "@HOME@/.config/mogo/art/"
W, H = 2048, 1024
base = np.asarray(Image.open(D + "dl/2k_haumea_fictional.jpg").convert("L").resize((W, H), Image.LANCZOS)).astype(np.float32) / 255
lo, hi = np.percentile(base, [2, 98])
L = np.clip((base - lo) / (hi - lo), 0, 1)
detail = L - ndimage.gaussian_filter(L, 3)

lon = ((np.arange(W) + 0.5) / W) * 2 * np.pi - np.pi
lat = np.pi / 2 - ((np.arange(H) + 0.5) / H) * np.pi
LON, LAT = np.meshgrid(lon, lat)
P = np.dstack([np.cos(LAT) * np.sin(LON), np.sin(LAT), np.cos(LAT) * np.cos(LON)])

stops = np.array([[0.00, 3, 10, 8], [0.35, 6, 26, 17], [0.6, 14, 62, 40], [0.82, 34, 128, 86], [1.00, 104, 212, 160]], np.float32)
def ramp(t):
    out = np.zeros(t.shape + (3,), np.float32)
    for k in range(3):
        out[..., k] = np.interp(t, stops[:, 0], stops[:, k + 1])
    return out

band_lat = np.radians(-8) + np.radians(9) * np.sin(LON * 2 + 0.6)
band = np.exp(-((LAT - band_lat) / np.radians(17)) ** 2)
t = np.clip(L * 0.8 + band * 0.34 - 0.14, 0, 1)
col = ramp(t)
col *= (1 + detail[..., None] * 2.2)
col += band[..., None] * np.array([8, 36, 24]) * 0.8

S = 1400
dec = Image.new("L", (S, S), 0)
d = ImageDraw.Draw(dec)
c = S / 2
ro, ri = S * 0.27, S * 0.165
d.ellipse((c - ro, c - ro, c + ro, c + ro), fill=255)
bw, y_in, y_out = ro * 1.22, ro * 0.74, ro * 1.06
for sgn in (-1, 1):
    d.rectangle((c - bw, c + sgn * y_in if sgn > 0 else c - y_out, c + bw, c + y_out if sgn > 0 else c - y_in), fill=255)
d.ellipse((c - ri, c - ri, c + ri, c + ri), fill=0)
dec_a = np.asarray(dec.filter(ImageFilter.GaussianBlur(2)), np.float32) / 255
glow_a = np.asarray(dec.filter(ImageFilter.GaussianBlur(40)), np.float32) / 255

lon0, lat0, size = np.radians(-20), np.radians(-6), 0.62
cen = np.array([np.cos(lat0) * np.sin(lon0), np.sin(lat0), np.cos(lat0) * np.cos(lon0)])
east = np.array([np.cos(lon0), 0, -np.sin(lon0)])
north = np.cross(cen, east)
north /= np.linalg.norm(north)
u = (P @ east) / size
v = (P @ north) / size
front = (P @ cen) > 0.2
sx = (u * 0.5 + 0.5) * S
sy = (-v * 0.5 + 0.5) * S
inb = front & (sx >= 0) & (sx < S) & (sy >= 0) & (sy < S)
emb = np.zeros((H, W), np.float32)
glw = np.zeros((H, W), np.float32)
emb[inb] = ndimage.map_coordinates(dec_a, [sy[inb], sx[inb]], order=1)
glw[inb] = ndimage.map_coordinates(glow_a, [sy[inb], sx[inb]], order=1)

lantern = np.array([186, 255, 140], np.float32)
col = col * (1 - emb[..., None] * 0.85) + emb[..., None] * np.array([60, 190, 128]) * (0.8 + 0.2 * L[..., None])
col += glw[..., None] * np.array([30, 110, 72]) * 0.6
Image.fromarray(np.clip(col, 0, 255).astype(np.uint8)).save(D + "surface.png", optimize=True)

emis = np.clip(emb * 0.9 + glw * 0.45, 0, 1)
Image.fromarray((emis * 255).astype(np.uint8)).save(D + "emission.png", optimize=True)
print("ok")
