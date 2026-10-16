#!/usr/bin/env python3
"""Draws the launcher icon from the 学 stroke outlines (Make Me a Hanzi data).

Writes legacy and adaptive icon PNGs under android/app/src/main/res/.
Run: python3 tool/make_icons.py   (needs inkscape; data/raw from scripts/fetch_sources.sh)
"""
import json, os, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
RED = "#C8372D"

def glyph_paths(ch):
    with open(os.path.join(ROOT, "data", "raw", "mmah_graphics.txt"), encoding="utf-8") as f:
        for line in f:
            e = json.loads(line)
            if e["character"] == ch:
                return e["strokes"]
    raise SystemExit("glyph not found")

def svg(kind, strokes):
    # Glyph box is 1024 wide, y-up with baseline 900. Scale to fill `fill` of the canvas.
    if kind == "legacy":      # full-bleed rounded square
        size, fill, bg, radius = 1024, 0.64, RED, 230
    elif kind == "background":
        size, fill, bg, radius = 1024, 0, RED, 0
    else:                     # adaptive foreground: transparent, inside the 66% safe zone
        size, fill, bg, radius = 1024, 0.50, None, 0
    paths = "".join(f'<path d="{d}"/>' for d in strokes)
    s = size * fill / 1024
    off = (size - 1024 * s) / 2
    g = (f'<g fill="#FFFFFF" transform="translate({off:.1f},{off + 900 * s:.1f}) scale({s:.4f},{-s:.4f})">{paths}</g>'
         if fill else "")
    rect = f'<rect width="{size}" height="{size}" rx="{radius}" fill="{bg}"/>' if bg else ""
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">{rect}{g}</svg>'

def render(svg_text, out, px):
    with tempfile.NamedTemporaryFile("w", suffix=".svg", delete=False) as t:
        t.write(svg_text)
        name = t.name
    os.makedirs(os.path.dirname(out), exist_ok=True)
    subprocess.run(["inkscape", name, "--export-type=png", f"--export-filename={out}",
                    f"--export-width={px}", f"--export-height={px}"], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    os.unlink(name)

def main():
    strokes = glyph_paths("学")
    dens = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}
    for d, k in dens.items():
        render(svg("legacy", strokes), f"{RES}/mipmap-{d}/ic_launcher.png", int(48 * k))
        render(svg("foreground", strokes), f"{RES}/mipmap-{d}/ic_launcher_foreground.png", int(108 * k))
    os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w") as f:
        f.write('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
''')
    os.makedirs(f"{RES}/values", exist_ok=True)
    with open(f"{RES}/values/ic_launcher_background.xml", "w") as f:
        f.write(f'''<?xml version="1.0" encoding="utf-8"?>
<resources>
    <color name="ic_launcher_background">{RED}</color>
</resources>
''')
    # 512 px Play Store icon
    render(svg("legacy", strokes), os.path.join(ROOT, "store", "play_icon_512.png"), 512)
    print("icons written")

main()
