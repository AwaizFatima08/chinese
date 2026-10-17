#!/usr/bin/env python3
"""Draws the launcher icon: a bold "15" on the brand red.

Writes legacy and adaptive icon PNGs under android/app/src/main/res/.
Run: python3 tool/make_icons.py   (needs inkscape and the DejaVu Sans font)
"""
import json, os, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
RES = os.path.join(ROOT, "android", "app", "src", "main", "res")
RED = "#C8372D"

def svg(kind, _unused=None):
    """Bold "15" on the brand red. Language-neutral: the app teaches several languages."""
    if kind == "legacy":        # launcher icon, rounded
        size, fs, bg, radius = 1024, 600, RED, 230
    elif kind == "play":        # Play Store icon: full-bleed square (Play applies the mask)
        size, fs, bg, radius = 1024, 600, RED, 0
    else:                       # adaptive foreground: inside the 66% safe zone
        size, fs, bg, radius = 1024, 420, None, 0
    rect = f'<rect width="{size}" height="{size}" rx="{radius}" fill="{bg}"/>' if bg else ""
    text = (f'<text x="{size/2}" y="{size/2 + fs*0.36}" text-anchor="middle" fill="#FFFFFF" '
            f'font-family="DejaVu Sans, Liberation Sans, sans-serif" font-weight="bold" '
            f'font-size="{fs}" letter-spacing="-20">15</text>')
    return f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {size} {size}">{rect}{text}</svg>'


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
    strokes = None
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
    render(svg("play", strokes), os.path.join(ROOT, "store", "play_icon_512.png"), 512)
    print("icons written")

main()
