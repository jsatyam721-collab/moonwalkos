import hashlib
import json
import os
import re
import sys

HOME = os.path.expanduser("~")
THEMES = f"{HOME}/.config/moonwalk/themes"
MOONWALK = f"{HOME}/.cache/moonwalk"
CACHE = f"{HOME}/.cache/wallwheel/hashes.json"
EXTS = (".png", ".jpg", ".jpeg", ".webp", ".gif")
ACCENT = re.compile(r'^dcol_[1-4]xa7="([0-9A-Fa-f]{6})"$', re.M)


def sha1(path):
    h = hashlib.sha1()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    try:
        with open(CACHE) as f:
            cache = json.load(f)
    except (OSError, ValueError):
        cache = {}

    fresh, rows = {}, []
    for theme in sorted(os.listdir(THEMES)):
        wdir = f"{THEMES}/{theme}/wallpapers"
        if not os.path.isdir(wdir):
            continue
        for name in sorted(os.listdir(wdir)):
            path = f"{wdir}/{name}"
            if not name.lower().endswith(EXTS) or not os.path.isfile(path):
                continue
            st = os.stat(path)
            key = f"{st.st_size}:{st.st_mtime_ns}"
            old = cache.get(path)
            h = old[1] if old and old[0] == key else sha1(path)
            fresh[path] = [key, h]

            thumb = f"{MOONWALK}/thumbs/{h}.sqre"
            try:
                with open(f"{MOONWALK}/dcols/{h}.dcol") as f:
                    acc = ",".join(ACCENT.findall(f.read()))
            except OSError:
                acc = ""
            rows.append((theme, path, thumb if os.path.isfile(thumb) else path, acc))

    if fresh != cache:
        os.makedirs(os.path.dirname(CACHE), exist_ok=True)
        with open(CACHE + ".tmp", "w") as f:
            json.dump(fresh, f)
        os.replace(CACHE + ".tmp", CACHE)

    out = [os.path.realpath(f"{MOONWALK}/wall.set")] + ["\t".join(r) for r in rows]
    sys.stdout.write("\n".join(out) + "\n")


if __name__ == "__main__":
    main()
