import json
import os
import re
import subprocess
import sys

HOME = os.path.expanduser("~")
TEMPLATE = f"{HOME}/.config/wallbash/theme/waybar.dcol"
CACHE = f"{HOME}/.cache/wallwheel/hashes.json"


def main(wall):
    with open(CACHE) as f:
        h = json.load(f)[wall][1]
    with open(f"{HOME}/.cache/moonwalk/dcols/{h}.dcol") as f:
        dcol = dict(re.findall(r'^dcol_(\w+)="(.*)"$', f.read(), re.M))

    with open(TEMPLATE) as f:
        header, body = f.read().split("\n", 1)
    target, _, hook = header.partition("|")
    target = os.path.expandvars(target)

    def sub(m):
        key, alpha = m.group(1), m.group(2)
        if alpha is not None:
            return dcol[f"{key}_rgba"].replace("\\1", alpha)
        return dcol[key]

    out = re.sub(r"<wallbash_(\w+?)(?:_rgba\(([^)]*)\))?>", sub, body)
    with open(target + ".tmp", "w") as f:
        f.write(out)
    os.replace(target + ".tmp", target)
    if hook.strip():
        subprocess.run(hook, shell=True, check=False)
    else:
        os.utime(f"{HOME}/.config/waybar/style.css")


if __name__ == "__main__":
    main(sys.argv[1])
