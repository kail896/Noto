#!/usr/bin/env python3
"""
Noto Icon v6 — Design C refined, 4 color variants
The icon IS the notecard (fills the macOS rounded rect).
"""

import struct, io, os, subprocess
from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
R = int(SIZE * 0.22)

def rounded_rect_mask(size, r=None):
    if r is None: r = R
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle((40,40,SIZE-40,SIZE-40), r, 255)
    return m

def shadow(mask, rad, color):
    s = mask.filter(ImageFilter.GaussianBlur(rad))
    r = Image.new("RGBA", s.size, (0,0,0,0))
    r.paste(color, mask=s)
    return r

def write_lines(draw, color, width=3, alpha=60):
    lm = int(SIZE*0.14)
    ly = int(SIZE*0.32)
    for i in range(5):
        y = ly + i*int(SIZE*0.08)
        c = color + (alpha - i*6,)
        draw.line([(lm, y), (SIZE-lm, y)], fill=c, width=width)

def accent_line(draw, color, w=12):
    lm = int(SIZE*0.14)
    ly = int(SIZE*0.32) + 2*int(SIZE*0.08)
    draw.line([(lm, ly), (lm+int(SIZE*0.12), ly)], fill=color, width=w)

def fold_corner(draw):
    fs = int(SIZE*0.10)
    draw.polygon([(SIZE-40-fs, SIZE-40), (SIZE-40, SIZE-40), (SIZE-40, SIZE-40-fs)],
                 fill=(255,255,255,40))
    draw.line([(SIZE-40-fs, SIZE-40), (SIZE-40, SIZE-40-fs)], fill=(255,255,255,60), width=2)


def variant_1():
    """v1: Deep purple -> Hot pink. White lines, gold accent."""
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x/SIZE + y/SIZE)/2
            r = int(100*(1-t) + 200*t)
            g = int(30*(1-t) + 50*t)
            b = int(160*(1-t) + 130*t)
            img.putpixel((x,y), (r,g,b,255))
    m = rounded_rect_mask((SIZE,SIZE))
    result = Image.new("RGBA", (SIZE,SIZE), (0,0,0,0)); result.paste(img,(0,0),m)
    d = ImageDraw.Draw(result)
    write_lines(d, (255,255,255), width=4, alpha=80)
    accent_line(d, (255,200,50,150), w=14)
    fold_corner(d)
    d.rounded_rectangle((44,44,SIZE-44,SIZE-44), R-4, outline=(255,255,255,20), width=2)
    return result

def variant_2():
    """v2: Coral -> Gold. WARM."""
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x/SIZE + y/SIZE)/2
            r = int(240*(1-t) + 255*t)
            g = int(90*(1-t) + 180*t)
            b = int(60*(1-t) + 50*t)
            img.putpixel((x,y), (r,g,b,255))
    m = rounded_rect_mask((SIZE,SIZE))
    result = Image.new("RGBA", (SIZE,SIZE), (0,0,0,0)); result.paste(img,(0,0),m)
    d = ImageDraw.Draw(result)
    write_lines(d, (255,255,255), width=4, alpha=90)
    accent_line(d, (180,60,80,180), w=14)
    fold_corner(d)
    d.rounded_rectangle((44,44,SIZE-44,SIZE-44), R-4, outline=(255,255,255,25), width=2)
    return result

def variant_3():
    """v3: Teal -> Bright Cyan. FRESH."""
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x/SIZE + y/SIZE)/2
            r = int(15*(1-t) + 15*t)
            g = int(130*(1-t) + 180*t)
            b = int(140*(1-t) + 200*t)
            img.putpixel((x,y), (r,g,b,255))
    m = rounded_rect_mask((SIZE,SIZE))
    result = Image.new("RGBA", (SIZE,SIZE), (0,0,0,0)); result.paste(img,(0,0),m)
    d = ImageDraw.Draw(result)
    write_lines(d, (255,255,255), width=4, alpha=85)
    accent_line(d, (255,100,100,160), w=14)
    fold_corner(d)
    d.rounded_rectangle((44,44,SIZE-44,SIZE-44), R-4, outline=(255,255,255,25), width=2)
    return result

def variant_4():
    """v4: Navy -> Violet. WITH white writing panel. CONTRAST."""
    img = Image.new("RGBA", (SIZE, SIZE), (0,0,0,0))
    for y in range(SIZE):
        for x in range(SIZE):
            t = (x/SIZE + y/SIZE)/2
            r = int(30*(1-t) + 100*t)
            g = int(20*(1-t) + 40*t)
            b = int(100*(1-t) + 180*t)
            img.putpixel((x,y), (r,g,b,255))
    m = rounded_rect_mask((SIZE,SIZE))
    result = Image.new("RGBA", (SIZE,SIZE), (0,0,0,0)); result.paste(img,(0,0),m)

    d = ImageDraw.Draw(result)
    pm = int(SIZE*0.10)
    pr = int(SIZE*0.04)
    d.rounded_rectangle((pm, pm, SIZE-pm, SIZE-pm), pr, fill=(255,250,242,220))

    lm = int(SIZE*0.14)
    ly = int(SIZE*0.25)
    for i in range(4):
        y = ly + i*int(SIZE*0.08)
        d.line([(lm, y), (SIZE-lm, y)], fill=(180,170,200,50), width=3)

    d.line([(lm, ly+int(SIZE*0.08)*2), (lm+int(SIZE*0.10), ly+int(SIZE*0.08)*2)],
           fill=(120,60,200,100), width=12)

    fs = int(SIZE*0.08)
    d.polygon([(SIZE-pm-fs, SIZE-pm), (SIZE-pm, SIZE-pm), (SIZE-pm, SIZE-pm-fs)],
              fill=(240,235,227,255))
    d.rounded_rectangle((pm, pm, SIZE-pm, SIZE-pm), pr, outline=(200,192,182,60), width=2)

    sm = Image.new("L", (SIZE,SIZE), 0)
    ImageDraw.Draw(sm).rounded_rectangle((pm+5,pm+5,SIZE-pm+5,SIZE-pm+5), pr, 255)
    result = Image.alpha_composite(result, shadow(sm, int(SIZE*0.03), (0,0,0,60)))

    return result


# Generate all variants
variants = [
    ("Purple-Pink", variant_1),
    ("Coral-Gold", variant_2),
    ("Teal-Cyan", variant_3),
    ("Navy-Violet-panel", variant_4),
]

for name, fn in variants:
    icon = fn()
    path = f"/tmp/noto-v6-{name.lower().split()[0]}.png"
    icon.save(path)
    print(f"✅ v6-{name}: {path}")

# Preview strip
preview = Image.new("RGB", (1060, 240), (240,240,240))
pd = ImageDraw.Draw(preview)
x = 20
for s in [128, 64, 32, 16]:
    for name, fn in variants:
        icon = fn()
        r = icon.resize((s,s), Image.LANCZOS)
        y_off = {128:0, 64:130, 32:180, 16:210}[s]
        preview.paste(r, (x, y_off))
        x += s + 5
    x += 15

# Labels
x = 20
for name, fn in variants:
    pd.text((x, 110), name.replace("-panel",""), fill=(100,100,100))
    x += 128 + 5
x += 15
for name, fn in variants:
    r2 = fn().resize((64,64), Image.LANCZOS)
    preview.paste(r2, (x, 170))
    x += 64 + 5

preview.save("/tmp/noto-v6-preview.png")
print("✅ Preview: /tmp/noto-v6-preview.png")

# Generate icns from variant 4 (default)
icon4 = variant_4()
icns_dir = "/tmp/noto-v6.iconset"
os.makedirs(icns_dir, exist_ok=True)
for s, nm in [(16,"icon_16x16.png"),(32,"icon_32x32.png"),(128,"icon_128x128.png"),
              (256,"icon_256x256.png"),(512,"icon_512x512.png"),(1024,"icon_512x512@2x.png")]:
    icon4.resize((s,s), Image.LANCZOS).save(f"{icns_dir}/{nm}")
subprocess.run(["iconutil", "-c", "icns", icns_dir, "-o", "/tmp/noto-v6.icns"],
               capture_output=True)
print("✅ ICNS created")

# Open all
import subprocess as sp
for name, fn in variants:
    p = f"/tmp/noto-v6-{name.lower().split()[0]}.png"
    sp.run(["open", p])
sp.run(["open", "/tmp/noto-v6-preview.png"])
