#!/usr/bin/env python3
"""
Noto App Icon v5 — Bold, minimal, vibrant note icon
Concept: Vibrant purple-to-hotpink gradient bg + white notecard + golden tab
"""

import struct, io
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
R = int(SIZE * 0.22)   # macOS standard corner radius
M = int(SIZE * 0.04)   # Outer margin

# VIBRANT colors
BG_A = (90, 30, 160)    # Deep purple
BG_B = (210, 50, 110)   # Hot pink
CARD = (255, 252, 245)  # Warm white
TAB = (240, 180, 40)    # Golden yellow tab
LINE = (190, 170, 210, 50)  # Faint writing lines


def grad(size, c1, c2):
    w, h = size
    img = Image.new("RGBA", size, (0,0,0,0))
    for y in range(h):
        for x in range(w):
            t = (x/max(w-1,1)+y/max(h-1,1))/2
            img.putpixel((x,y), (
                int(c1[0]*(1-t)+c2[0]*t),
                int(c1[1]*(1-t)+c2[1]*t),
                int(c1[2]*(1-t)+c2[2]*t),
                int((c1[3] if len(c1)>3 else 255)*(1-t)+(c2[3] if len(c2)>3 else 255)*t))
            )
    return img


def shadow(mask, rad, color):
    s = mask.filter(ImageFilter.GaussianBlur(rad))
    r = Image.new("RGBA", s.size, (0,0,0,0))
    r.paste(color, mask=s)
    return r


def generate():
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    ox, oy = M, M
    ow = oh = SIZE - 2*M
    outer = (ox, oy, ox+ow, oy+oh)

    # Outer mask
    mask = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(mask).rounded_rectangle(outer, R, fill=255)

    # 1. Background gradient (diagonal purple→hotpink)
    bg = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    bg.paste(grad((SIZE,SIZE), BG_A+(255,), BG_B+(255,)), (0,0), mask)
    img = Image.alpha_composite(img, bg)

    # 2. Subtle top shine
    shine = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    sd = ImageDraw.Draw(shine)
    hi = int(SIZE*0.04)
    for y in range(oy+hi, oy+int(oh*0.35)):
        a = int(50*(1-(y-oy-hi)/(int(oh*0.35)-hi)))
        sd.line([(ox+R//3, y), (ox+ow-R//3, y)], fill=(255,255,255,a))
    img = Image.alpha_composite(img, Image.composite(shine, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), mask))

    # 3. Notecard (clean white, centered)
    cm = int(SIZE*0.12)   # Card margin from outer edge
    cr = int(SIZE*0.055)  # Card corner radius
    cx, cy = cm, cm
    cw = ch = SIZE - 2*cm
    card_r = (cx, cy, cx+cw, cy+ch)

    # Card shadow
    for off, rad, col in [(int(SIZE*0.012), int(SIZE*0.045), (40,20,60,80)),
                           (int(SIZE*0.025), int(SIZE*0.075), (0,0,0,18))]:
        sm = Image.new("L", (SIZE, SIZE), 0)
        ImageDraw.Draw(sm).rounded_rectangle((cx+off,cy+off,cx+cw+off,cy+ch+off), cr, 255)
        img = Image.alpha_composite(img, shadow(sm, rad, col))

    # Card body (very subtle vertical gradient, barely visible)
    card = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(cy, cy+ch):
        ratio = (y-cy)/max(ch-1,1)
        r = int(255*(1-ratio)+251*ratio)
        g = int(253*(1-ratio)+247*ratio)
        b = int(249*(1-ratio)+240*ratio)
        for x in range(cx, cx+cw):
            card.putpixel((x,y), (r,g,b,255))

    card_m = Image.new("L", (SIZE, SIZE), 0)
    ImageDraw.Draw(card_m).rounded_rectangle(card_r, cr, 255)
    card_final = Image.composite(card, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), card_m)
    ImageDraw.Draw(card_final).rounded_rectangle(card_r, cr, outline=(200,192,182,60), width=2)
    img = Image.alpha_composite(img, card_final)

    # 4. Golden tab on top-right of card
    tw = int(SIZE*0.14)
    th = int(SIZE*0.07)
    tx = cx + cw - tw - int(SIZE*0.01)
    ty = cy - int(SIZE*0.02)  # Slightly overlapping the top
    tab = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    td = ImageDraw.Draw(tab)
    # Rounded rect tab
    t_r = int(SIZE*0.02)
    td.rounded_rectangle((tx, ty, tx+tw, ty+th), t_r, fill=TAB+(255,))
    # Subtle fold shadow under tab
    td.rounded_rectangle((tx+1, ty+th-2, tx+tw-1, ty+th+4), 2, fill=(180,120,30,60))
    img = Image.alpha_composite(img, tab)

    # 5. Two minimal writing lines
    lines = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    ld = ImageDraw.Draw(lines)
    lm = int(SIZE*0.09)   # Line left margin
    ly1 = cy + th + int(SIZE*0.08)  # Below tab
    lsp = int(SIZE*0.045)
    for i in range(3):
        ly = ly1 + i*lsp
        ld.line([(cx+lm, ly), (cx+cw-lm, ly)], fill=LINE, width=int(SIZE*0.0025))

    # 6. One accent colored line (pink/magenta highlight)
    al = ly1 + lsp
    ld.line([(cx+lm, al), (cx+lm+int(SIZE*0.08), al)],
            fill=(210,50,110,70), width=int(SIZE*0.018))
    img = Image.alpha_composite(img, lines)

    # 7. Fold corner (tiny, bottom-right)
    fs = int(SIZE*0.065)
    fold = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    fd = ImageDraw.Draw(fold)
    fd.polygon([(cx+cw-fs, cy+ch), (cx+cw, cy+ch), (cx+cw, cy+ch-fs)],
               fill=(247,242,234,255))
    fd.polygon([(cx+cw-fs, cy+ch), (cx+cw, cy+ch), (cx+cw, cy+ch-fs)],
               outline=(185,175,160,80), width=2)
    img = Image.alpha_composite(img, fold)

    # 8. Edge darkening for depth
    edge = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    ed = ImageDraw.Draw(edge)
    ew = int(SIZE*0.08)
    for i in range(ew):
        a = int(20*(1-i/ew))
        inset = M + i
        ed.rounded_rectangle((inset,inset,SIZE-inset,SIZE-inset), max(0,R-i), fill=(0,0,0,a))
    img = Image.alpha_composite(img, Image.composite(edge, Image.new("RGBA",(SIZE,SIZE),(0,0,0,0)), mask))

    return img


if __name__ == "__main__":
    print("🎨 Noto icon v5 — Bold minimal notecard")
    icon = generate()
    icon.save("/tmp/noto-v5-master.png")
    print(f"✅ Master saved")

    # Preview
    preview = Image.new("RGB", (1060, 240), (240,240,240))
    pd = ImageDraw.Draw(preview)
    x = 20
    for s in [1024, 128, 64, 32, 16]:
        r = icon.resize((s,s), Image.LANCZOS)
        preview.paste(r, (x,20))
        pd.text((x, 20+s+5), f"{s}x{s}", fill=(100,100,100))
        x += s + 20
    preview.save("/tmp/noto-v5-preview.png")
    open("/tmp/noto-v5-master.png")
    print("✅ Preview opened")
