#!/usr/bin/env python3
"""Social-media launch images for Lingo15 with a QR code to the Play listing.
Run: .venv/bin/python tool/make_social.py  ->  store/social/*.png"""
import os
import qrcode
from qrcode.constants import ERROR_CORRECT_H
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "store", "social")
URL = "https://play.google.com/store/apps/details?id=com.homilabs.lingo15"
VERMILION, DEEP, PAPER, INK, GOLD = (200, 55, 45), (168, 40, 32), (251, 246, 238), (36, 27, 22), (224, 165, 38)
BOLD = "/usr/share/fonts/truetype/noto/NotoSans-Bold.ttf"
REG = "/usr/share/fonts/truetype/noto/NotoSans-Regular.ttf"
CJK = next((p for p in ["/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc",
                         "/usr/share/fonts/opentype/noto/NotoSerifCJK-Bold.ttc",
                         "/usr/share/fonts/truetype/droid/DroidSansFallbackFull.ttf"] if os.path.exists(p)), None)

def font(path, size):
    return ImageFont.truetype(path, size)

def qr_image(size):
    q = qrcode.QRCode(error_correction=ERROR_CORRECT_H, box_size=10, border=2)
    q.add_data(URL)
    q.make(fit=True)
    img = q.make_image(fill_color=INK, back_color="white").convert("RGB").resize((size, size), Image.NEAREST)
    # app icon in the middle (H-level error correction allows it)
    icon = Image.open(os.path.join(ROOT, "store", "play_icon_512.png")).convert("RGBA")
    s = size // 4
    icon = icon.resize((s, s), Image.LANCZOS)
    pad = s // 10
    plate = Image.new("RGBA", (s + 2 * pad, s + 2 * pad), (255, 255, 255, 255))
    plate.paste(icon, (pad, pad), icon)
    img.paste(plate, ((size - plate.width) // 2, (size - plate.height) // 2), plate)
    return img

def rounded(img, radius):
    mask = Image.new("L", img.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, img.width - 1, img.height - 1], radius, fill=255)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out

def background(w, h):
    img = Image.new("RGB", (w, h), VERMILION)
    d = ImageDraw.Draw(img)
    d.ellipse([w * 0.55, -h * 0.25, w * 1.35, h * 0.45], fill=DEEP)
    d.ellipse([-w * 0.35, h * 0.72, w * 0.45, h * 1.35], fill=DEEP)
    if CJK:
        # a faint character as a watermark, drawn on its own layer so alpha applies
        layer = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        ImageDraw.Draw(layer).text((w * 0.66, -h * 0.03), "好", font=font(CJK, int(min(w, h) * 0.34)), fill=(255, 255, 255, 34))
        img = Image.alpha_composite(img.convert("RGBA"), layer).convert("RGB")
    return img

def pills(d, x, y, labels, f, gap=18):
    for text in labels:
        tw = d.textlength(text, font=f)
        ph = f.size + 26
        d.rounded_rectangle([x, y, x + tw + 44, y + ph], ph // 2, fill=PAPER)
        d.text((x + 22, y + 10), text, font=f, fill=VERMILION)
        x += tw + 44 + gap

def square():
    W = H = 1080
    img = background(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    d.text((70, 60), "Lingo15", font=font(BOLD, 150), fill="white")
    d.text((76, 232), "is on Google Play", font=font(REG, 56), fill=PAPER)
    d.text((76, 318), "Chinese · German · Speak English", font=font(BOLD, 44), fill="white")
    d.text((76, 380), "in 15 minutes a day", font=font(REG, 44), fill=PAPER)
    pills(d, 76, 470, ["HSK 1-6", "A1-C2", "Accent coach"], font(BOLD, 34))
    # card with QR
    card = [76, 580, 1004, 1010]
    d.rounded_rectangle(card, 36, fill=PAPER)
    q = qr_image(360)
    img.paste(q, (card[0] + 36, card[1] + 35))
    tx = card[0] + 36 + 360 + 40
    d.text((tx, card[1] + 60), "Scan to install", font=font(BOLD, 54), fill=INK)
    d.text((tx, card[1] + 140), "Free on Google Play", font=font(REG, 40), fill=INK)
    d.text((tx, card[1] + 200), "Android 7 and up", font=font(REG, 32), fill=(110, 95, 85))
    bx, by = tx, card[1] + 290
    d.rounded_rectangle([bx, by, bx + 440, by + 82], 41, fill=INK)
    d.polygon([(bx + 40, by + 24), (bx + 40, by + 58), (bx + 70, by + 41)], fill=GOLD)
    d.text((bx + 88, by + 26), "GET IT ON GOOGLE PLAY", font=font(BOLD, 26), fill="white")
    d.text((76, 1026), "tools.homilabs.org/lingo15", font=font(REG, 30), fill=PAPER)
    img.save(os.path.join(OUT, "lingo15_post_1080.png"))

def story():
    W, H = 1080, 1920
    img = background(W, H)
    d = ImageDraw.Draw(img, "RGBA")
    d.text((70, 150), "Lingo15", font=font(BOLD, 170), fill="white")
    d.text((76, 350), "is on Google Play", font=font(REG, 64), fill=PAPER)
    d.text((76, 480), "Learn Chinese or German,", font=font(BOLD, 52), fill="white")
    d.text((76, 548), "or polish your spoken English —", font=font(BOLD, 52), fill="white")
    d.text((76, 616), "15 minutes a day.", font=font(BOLD, 52), fill="white")
    pills(d, 76, 730, ["HSK 1-6", "A1-C2", "Accent coach"], font(BOLD, 36))
    card = [120, 900, 960, 1690]
    d.rounded_rectangle(card, 44, fill=PAPER)
    q = qr_image(520)
    img.paste(q, ((W - 520) // 2, card[1] + 60))
    d.text(((W - d.textlength("Scan to install", font=font(BOLD, 60))) / 2, card[1] + 610),
           "Scan to install", font=font(BOLD, 60), fill=INK)
    t2 = "Free on Google Play · Android 7+"
    d.text(((W - d.textlength(t2, font=font(REG, 38))) / 2, card[1] + 700), t2, font=font(REG, 38), fill=INK)
    d.text((76, 1760), "tools.homilabs.org/lingo15", font=font(REG, 34), fill=PAPER)
    img.save(os.path.join(OUT, "lingo15_story_1080x1920.png"))

def plain_qr():
    qr_image(1024).save(os.path.join(OUT, "lingo15_qr.png"))

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    square(); story(); plain_qr()
    print("wrote", sorted(os.listdir(OUT)))
