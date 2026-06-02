#!/usr/bin/env python3
"""
Noto App Icon Generator v4 — macOS style rounded rect with note card inside
Standard macOS rounded-square shape (~20% corner radius),
with purple gradient background + white notecard + header band
"""

import struct, io, random
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
random.seed(42)

# ─── Colors ───
BG_TOP = (140, 55, 195)        # Deep purple (top)
BG_BOT = (225, 100, 75)        # Coral/amber (bottom)
CARD_COLOR = (254, 251, 245)   # Warm white
LINE_COLOR = (200, 190, 215, 55)
HEADER_TOP = (130, 50, 190)
HEADER_BOT = (220, 95, 80)
MARKER_COLOR = (100, 60, 200, 80)

def diagonal_gradient(size, c1, c2):
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

    # ── Outer rounded rect (standard macOS app icon shape) ──
    margin = int(SIZE * 0.04)       # Outer margin
    outer_r = int(SIZE * 0.22)      # Standard ~22% corner radius
    ox, oy = margin, margin
    ow = SIZE - 2*margin
    oh = SIZE - 2*margin

    # Outer mask
    outer_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(outer_mask).rounded_rectangle(
        (ox, oy, ox+ow, oy+oh), radius=outer_r, fill=255
    )

    # ── Background gradient within rounded rect ──
    bg_grad = diagonal_gradient((SIZE, SIZE), BG_TOP+(255,), BG_BOT+(255,))
    bg = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    bg.paste(bg_grad, (0,0), outer_mask)
    img = Image.alpha_composite(img, bg)

    # ── Subtle top highlight (glass-like) ──
    highlight = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    hd = ImageDraw.Draw(highlight)
    hi = int(SIZE * 0.05)
    for y in range(oy+hi, oy+int(oh*0.40)):
        ratio = (y-oy-hi) / max(int(oh*0.40)-hi-1, 1)
        alpha = int(55 * (1-ratio))
        hd.line([(ox+outer_r//2, y), (ox+ow-outer_r//2, y)], fill=(255,255,255,alpha))
    highlight_masked = Image.composite(highlight, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), outer_mask)
    img = Image.alpha_composite(img, highlight_masked)

    # ── Edge darkening for depth ──
    vignette = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    vd = ImageDraw.Draw(vignette)
    edge_w = int(SIZE * 0.10)
    for i in range(edge_w):
        a = int(25 * (1-i/edge_w))
        # Draw thin rects inset from each edge
        inset = margin + i
        vd.rounded_rectangle(
            (inset, inset, SIZE-inset, SIZE-inset),
            radius=max(0, outer_r-i), fill=(0,0,0,a)
        )
    vignette_masked = Image.composite(vignette, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), outer_mask)
    img = Image.alpha_composite(img, vignette_masked)

    # ── Notecard inside ──
    card_margin = int(SIZE * 0.10)
    cr = int(SIZE * 0.05)
    cx, cy = card_margin, card_margin
    cw = SIZE - 2*card_margin
    ch = SIZE - 2*card_margin
    card_rect = (cx, cy, cx+cw, cy+ch)

    # Card shadow
    for off, rad, col in [
        (int(SIZE*0.012), int(SIZE*0.05), (30,15,45,90)),
        (int(SIZE*0.025), int(SIZE*0.08), (0,0,0,20)),
    ]:
        sm = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(sm).rounded_rectangle(
            (cx+off, cy+off, cx+cw+off, cy+ch+off), radius=cr, fill=255
        )
        img = Image.alpha_composite(img, soft_shadow(sm, rad, col))

    # Card body
    card = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(cy, cy+ch):
        ratio = (y-cy)/max(ch-1,1)
        r = int(255*(1-ratio)+248*ratio)
        g = int(252*(1-ratio)+244*ratio)
        b = int(248*(1-ratio)+238*ratio)
        for x in range(cx, cx+cw):
            card.putpixel((x,y), (r,g,b,255))

    card_mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(card_mask).rounded_rectangle(card_rect, radius=cr, fill=255)
    card_masked = Image.composite(card, Image.new("RGBA", (SIZE,SIZE), (0,0,0,0)), card_mask)

    # Card border
    cd = ImageDraw.Draw(card_masked)
    cd.rounded_rectangle(card_rect, radius=cr, outline=(205,198,188,80), width=2)
    img = Image.alpha_composite(img, card_masked)

    # ── Header band on card ──
    header_h = int(SIZE * 0.15)
    header = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    h_grad = diagonal_gradient((SIZE, SIZE), HEADER_TOP+(255,), HEADER_BOT+(255,))

    # Clip header to card rounded rect
    header_mask = Image.new("L", (SIZE, SIZE), 0)
    hm = ImageDraw.Draw(header_mask)
    hm.rounded_rectangle(card_rect, radius=cr, fill=255)
    # Only top portion
    crop = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(crop).rectangle((cx, cy, cx+cw, cy+header_h), fill=255)
    header_mask = Image.composite(header_mask, Image.new("L", (SIZE,SIZE),0), crop)

    header_painted = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    header_painted.paste(h_grad, (0,0), header_mask)

    # Header bottom line
    hd = ImageDraw.Draw(header_painted)
    hd.line([(cx+cr//2, cy+header_h), (cx+cw-cr//2, cy+header_h)],
            fill=(180,75,130,100), width=2)
    img = Image.alpha_composite(img, header_painted)

    # ── Writing lines ──
    lines = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    ld = ImageDraw.Draw(lines)
    lm = int(SIZE * 0.06)
    ls_y = cy + header_h + int(SIZE * 0.045)
    lsp = int(SIZE * 0.042)

    for i in range(7):
        ly = ls_y + i * lsp
        ld.line([(cx+lm, ly), (cx+cw-lm, ly)], fill=LINE_COLOR, width=int(SIZE*0.002))

    # Accent marker
    ay = ls_y + 2 * lsp
    al = int(SIZE * 0.09)
    ld.line([(cx+lm, ay), (cx+lm+al, ay)], fill=MARKER_COLOR, width=int(SIZE*0.018))
    img = Image.alpha_composite(img, lines)

    # ── Fold corner ──
    fs = int(SIZE * 0.07)
    fold = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    fd = ImageDraw.Draw(fold)
    fd.polygon([(cx+cw-fs, cy+ch), (cx+cw, cy+ch), (cx+cw, cy+ch-fs)],
               fill=(245,240,232,255))
    fd.polygon([(cx+cw-fs, cy+ch), (cx+cw, cy+ch), (cx+cw, cy+ch-fs)],
               outline=(190,180,165,100), width=2)
    fd.line([(cx+cw-fs, cy+ch), (cx+cw, cy+ch-fs)], fill=(185,175,160,60), width=2)
    img = Image.alpha_composite(img, fold)

    # ── Subtle paper texture ──
    noise = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for _ in range(2500):
        x = random.randint(cx+lm, cx+cw-lm)
        y = random.randint(cy+lm, cy+ch-lm)
        v = random.randint(0, 10)
        noise.putpixel((x,y), (v,v,v,5))
    img = Image.alpha_composite(img, Image.composite(noise, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), outer_mask))

    return img


if __name__ == "__main__":
    print("🎨 Generating Noto icon v4 (macOS rounded rect)...")
    icon = generate()
    icon.save("/tmp/noto-v4-master.png")
    print(f"✅ Master: /tmp/noto-v4-master.png")

    # Preview
    preview = Image.new('RGB', (1024+200, 240), (245,245,245))
    pd = ImageDraw.Draw(preview)
    x = 20
    for s in [1024, 128, 64, 32, 16]:
        r = icon.resize((s, s), Image.LANCZOS)
        preview.paste(r, (x, 20))
        pd.text((x, 20+s+5), f'{s}x{s}', fill=(120,120,120))
        x += s + 20
    preview.save("/tmp/noto-v4-preview.png")
    print("✅ Preview saved")
