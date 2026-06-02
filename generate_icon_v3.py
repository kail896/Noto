#!/usr/bin/env python3
"""
Noto App Icon Generator v3 — Minimal Notecard with Colored Header
Design: Simple white card + purple gradient top band + writing lines
No outer shape, no folder-like elements. Pure notecard.
"""

import struct, io, random
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# ─── Colors ───
HEADER_TOP = (130, 50, 190)       # Deep purple
HEADER_BOT = (220, 95, 80)        # Coral
CARD_TOP = (255, 252, 246)        # Slightly warm white (top of card)
CARD_BOT = (250, 246, 238)        # Slightly warmer (bottom of card)
LINE_COLOR = (200, 190, 210, 55)  # Faint writing lines
MARKER_COLOR = (100, 60, 200, 80) # Purple marker accent

random.seed(42)

def diagonal_gradient(size, c1, c2):
    """2-pass diagonal gradient for smoothness."""
    w, h = size
    img = Image.new("RGBA", size, (0,0,0,0))
    for y in range(h):
        for x in range(w):
            t = (x/max(w-1,1) + y/max(h-1,1)) / 2.0
            t = min(max(t,0),1)
            r = int(c1[0]*(1-t) + c2[0]*t)
            g = int(c1[1]*(1-t) + c2[1]*t)
            b = int(c1[2]*(1-t) + c2[2]*t)
            a = int((c1[3] if len(c1)>3 else 255)*(1-t) + (c2[3] if len(c2)>3 else 255)*t)
            img.putpixel((x,y), (r,g,b,a))
    return img

def soft_shadow(mask, radius, color):
    s = mask.filter(ImageFilter.GaussianBlur(radius=radius))
    r = Image.new("RGBA", s.size, (0,0,0,0))
    r.paste(color, mask=s)
    return r

def generate():
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))

    # ── Card dimensions ──
    MARGIN = int(SIZE * 0.07)
    cr = int(SIZE * 0.065)       # Corner radius
    cx, cy = MARGIN, MARGIN
    cw = SIZE - 2*MARGIN
    ch = SIZE - 2*MARGIN
    card_rect = (cx, cy, cx+cw, cy+ch)

    header_h = int(SIZE * 0.17)  # Header band height
    line_margin = int(SIZE * 0.07)

    # ── 1. Card shadow ──
    for offset, radius, color in [
        (int(SIZE*0.015), int(SIZE*0.05), (30,15,45,90)),
        (int(SIZE*0.025), int(SIZE*0.08), (0,0,0,25)),
    ]:
        mask = Image.new("L", (SIZE, SIZE), 0)
        d = ImageDraw.Draw(mask)
        d.rounded_rectangle(
            (cx+offset, cy+offset, cx+cw+offset, cy+ch+offset),
            radius=cr, fill=255
        )
        img = Image.alpha_composite(img, soft_shadow(mask, radius, color))

    # ── 2. Card body (very subtle gradient) ──
    card = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    # Vertical gradient on card
    for y in range(cy, cy+ch):
        ratio = (y-cy) / max(ch-1, 1)
        r = int(CARD_TOP[0]*(1-ratio) + CARD_BOT[0]*ratio)
        g = int(CARD_TOP[1]*(1-ratio) + CARD_BOT[1]*ratio)
        b = int(CARD_TOP[2]*(1-ratio) + CARD_BOT[2]*ratio)
        for x in range(cx, cx+cw):
            card.putpixel((x,y), (r,g,b,255))

    # Clip to rounded rect
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(card_rect, radius=cr, fill=255)
    card_masked = Image.composite(card, Image.new("RGBA", (SIZE, SIZE), (0,0,0,0)), mask)

    # Subtle border
    d = ImageDraw.Draw(card_masked)
    d.rounded_rectangle(card_rect, radius=cr, outline=(205,198,188,80), width=2)

    img = Image.alpha_composite(img, card_masked)

    # ── 3. Colored header band ──
    header = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    header_rect = (cx, cy, cx+cw, cy+header_h)

    # Clip header to card's rounded corners
    header_mask = Image.new("L", (SIZE, SIZE), 0)
    hmd = ImageDraw.Draw(header_mask)
    hmd.rounded_rectangle(card_rect, radius=cr, fill=255)
    # But only keep the top portion
    header_crop = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(header_crop).rectangle(header_rect, fill=255)
    header_mask = Image.composite(header_mask, Image.new("L", (SIZE, SIZE), 0), header_crop)

    # Gradient for header
    h_grad = diagonal_gradient((SIZE, SIZE), HEADER_TOP+(255,), HEADER_BOT+(255,))
    header_painted = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    header_painted.paste(h_grad, (0,0), header_mask)

    # Header bottom border line
    hd = ImageDraw.Draw(header_painted)
    hd.line([(cx+cr//2, cy+header_h), (cx+cw-cr//2, cy+header_h)],
            fill=(180,75,130,100), width=2)

    img = Image.alpha_composite(img, header_painted)

    # ── 4. Writing lines ──
    lines = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    ld = ImageDraw.Draw(lines)
    line_start = cy + header_h + int(SIZE * 0.055)
    line_spacing = int(SIZE * 0.045)
    num_lines = 6

    for i in range(num_lines):
        ly = line_start + i * line_spacing
        lx1 = cx + line_margin
        lx2 = cx + cw - line_margin
        ld.line([(lx1, ly), (lx2, ly)], fill=LINE_COLOR, width=int(SIZE*0.002))

    # ── 5. Purple accent marker line ──
    accent_y = line_start + 2 * line_spacing
    accent_len = int(SIZE * 0.10)
    ld.line([(cx+line_margin, accent_y), (cx+line_margin+accent_len, accent_y)],
            fill=MARKER_COLOR, width=int(SIZE*0.02))

    img = Image.alpha_composite(img, lines)

    # ── 6. Fold corner (bottom-right) ──
    fold_size = int(SIZE * 0.08)
    fx1 = cx+cw-fold_size
    fy1 = cy+ch
    fx2 = cx+cw
    fy2 = cy+ch-fold_size

    fold = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    fd = ImageDraw.Draw(fold)
    fd.polygon([(fx1,fy1),(fx2,fy1),(fx2,fy2)], fill=(245,240,232,255))
    fd.polygon([(fx1,fy1),(fx2,fy1),(fx2,fy2)], outline=(190,180,165,100), width=2)
    fd.line([(fx1,fy1),(fx2,fy2)], fill=(185,175,160,60), width=2)
    img = Image.alpha_composite(img, fold)

    # ── 7. Very subtle paper texture ──
    noise = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for _ in range(3000):
        x = random.randint(cx+line_margin, cx+cw-line_margin)
        y = random.randint(cy+line_margin, cy+ch-line_margin)
        v = random.randint(0, 12)
        noise.putpixel((x,y), (v,v,v,6))
    noise_masked = Image.composite(noise, Image.new("RGBA", (SIZE,SIZE),(0,0,0,0)), mask)
    img = Image.alpha_composite(img, noise_masked)

    return img


def make_icns(icon, path):
    ICON_TYPES = [
        ('ic11', 32), ('ic12', 64), ('ic07', 128),
        ('ic08', 256), ('ic09', 512), ('ic10', 1024),
    ]
    entries = b''
    for code, size in ICON_TYPES:
        resized = icon.resize((size, size), Image.LANCZOS)
        buf = io.BytesIO()
        resized.save(buf, format='PNG')
        png_data = buf.getvalue()
        entries += code.encode() + struct.pack('>I', 8+len(png_data)) + png_data
        print(f"  {code}: {size}x{size} -> {len(png_data)} bytes")
    data = b'icns' + struct.pack('>I', 8+len(entries)) + entries
    with open(path, 'wb') as f:
        f.write(data)
    print(f"✅ ICNS: {path} ({len(data)} bytes)")


if __name__ == "__main__":
    print("🎨 Generating Noto icon v3...")
    icon = generate()
    icon.save("/tmp/noto-v3-master.png")
    print(f"✅ Master: /tmp/noto-v3-master.png")
    make_icns(icon, "/tmp/noto-v3.icns")

    # Preview strip
    preview = Image.new('RGB', (1024+200, 240), (245,245,245))
    pd = ImageDraw.Draw(preview)
    x = 20
    for s in [1024, 128, 64, 32, 16]:
        r = icon.resize((s, s), Image.LANCZOS)
        preview.paste(r, (x, 20))
        pd.text((x, 20+s+5), f'{s}x{s}', fill=(120,120,120))
        x += s + 20
    preview.save("/tmp/noto-v3-preview.png")
