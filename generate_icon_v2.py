#!/usr/bin/env python3
"""
Noto App Icon Generator v2
Minimalist, highly recognizable note-taking icon
Design: Simple notecard with colored bookmark ribbon — NO outer folder-like shape
"""

import math
import os
import struct
import io

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024

# ─── Colors ───────────────────────────────────────────
CARD_COLOR = (252, 249, 242)        # Warm cream paper
CARD_SHADOW = (40, 20, 50, 60)       # Shadow
RIBBON_TOP = (120, 40, 180)          # Deep purple
RIBBON_BOT = (230, 90, 70)           # Coral
LINE_COLOR = (200, 190, 210, 50)     # Faint writing lines
ACCENT_COLOR = (100, 60, 200, 90)    # Purple marker highlight
FOLD_SHADOW = (200, 190, 180, 80)    # Fold corner shadow

# ─── Drawing helpers ──────────────────────────────────

def rounded_rect(draw, xy, r, fill=None, outline=None, width=1):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)

def soft_shadow(mask, radius=40, color=(0, 0, 0, 80)):
    shadow = mask.filter(ImageFilter.GaussianBlur(radius=radius))
    result = Image.new("RGBA", shadow.size, (0, 0, 0, 0))
    result.paste(color, mask=shadow)
    return result

def diagonal_gradient(size, color_tl, color_br):
    """Create a diagonal gradient image."""
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    w, h = size
    for y in range(h):
        for x in range(w):
            t = (x / max(w - 1, 1) + y / max(h - 1, 1)) / 2.0
            t = min(max(t, 0), 1)
            r = int(color_tl[0] * (1 - t) + color_br[0] * t)
            g = int(color_tl[1] * (1 - t) + color_br[1] * t)
            b = int(color_tl[2] * (1 - t) + color_br[2] * t)
            a = int((color_tl[3] if len(color_tl) > 3 else 255) * (1 - t) +
                    (color_br[3] if len(color_br) > 3 else 255) * t)
            img.putpixel((x, y), (r, g, b, a))
    return img


def generate_icon():
    """Generate the new minimalist notecard icon."""
    img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Sizing ──
    # Card dimensions
    cw = int(SIZE * 0.78)     # Card width
    ch = int(SIZE * 0.88)     # Card height
    cr = int(SIZE * 0.055)    # Corner radius
    cx = (SIZE - cw) // 2
    cy = (SIZE - ch) // 2
    card_rect = (cx, cy, cx + cw, cy + ch)

    m = int(SIZE * 0.06)  # Margin from card edge for lines/etc

    # ── 1. Card shadow ──
    shadow_offset = int(SIZE * 0.012)
    shadow_mask = Image.new("L", (SIZE, SIZE), 0)
    sd = ImageDraw.Draw(shadow_mask)
    sd.rounded_rectangle(
        (cx + shadow_offset, cy + shadow_offset, cx + cw + shadow_offset, cy + ch + shadow_offset),
        radius=cr, fill=255
    )
    shadow = soft_shadow(shadow_mask, radius=int(SIZE * 0.035), color=(40, 20, 50, 100))
    img = Image.alpha_composite(img, shadow)

    # Also add a deeper, smaller shadow for realism
    shadow2_mask = Image.new("L", (SIZE, SIZE), 0)
    sd2 = ImageDraw.Draw(shadow2_mask)
    sd2.rounded_rectangle(
        (cx + shadow_offset * 2, cy + shadow_offset * 2, cx + cw + shadow_offset * 2, cy + ch + shadow_offset * 2),
        radius=cr, fill=255
    )
    shadow2 = soft_shadow(shadow2_mask, radius=int(SIZE * 0.06), color=(0, 0, 0, 30))
    img = Image.alpha_composite(img, shadow2)

    # ── 2. Card body ──
    card = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)

    # Subtle paper gradient (very slight warm tint)
    paper_grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pg = ImageDraw.Draw(paper_grad)

    # Draw gradient within card area
    card_mask = Image.new("L", (SIZE, SIZE), 0)
    cmd = ImageDraw.Draw(card_mask)
    cmd.rounded_rectangle(card_rect, radius=cr, fill=255)

    # Subtle light gradient on card (top-left to bottom-right, very faint)
    grad = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(cy, cy + ch):
        ratio = (y - cy) / max(ch - 1, 1)
        r = int(255 * (1 - ratio) + 248 * ratio)
        g = int(252 * (1 - ratio) + 244 * ratio)
        b = int(248 * (1 - ratio) + 238 * ratio)
        for x in range(cx, cx + cw):
            grad.putpixel((x, y), (r, g, b, 255))

    card = Image.composite(grad, card, card_mask)

    # Card border (very subtle)
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle(card_rect, radius=cr, outline=(215, 208, 195, 100), width=2)

    img = Image.alpha_composite(img, card)

    # ── 3. Fold corner (bottom-right) ──
    fold_size = int(SIZE * 0.09)
    fx1 = cx + cw - fold_size
    fy1 = cy + ch
    fx2 = cx + cw
    fy2 = cy + ch - fold_size

    fold = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fd = ImageDraw.Draw(fold)
    # Fold triangle (underside of the folded corner)
    fd.polygon(
        [(fx1, fy1), (fx2, fy1), (fx2, fy2)],
        fill=(245, 240, 232, 255)
    )
    # Fold shadow line
    fd.polygon(
        [(fx1, fy1), (fx2, fy1), (fx2, fy2)],
        outline=(195, 185, 170, 120), width=2
    )
    # Subtle crease line
    fd.line([(fx1, fy1), (fx2, fy2)], fill=(185, 175, 160, 80), width=2)
    img = Image.alpha_composite(img, fold)

    # ── 4. Writing lines ──
    lines_img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ld = ImageDraw.Draw(lines_img)

    line_start_y = cy + m + int(SIZE * 0.04)
    line_spacing = int(SIZE * 0.05)
    line_margin_x = m

    for i in range(8):
        ly = line_start_y + i * line_spacing
        lx1 = cx + line_margin_x
        lx2 = cx + cw - line_margin_x
        # Stop before fold corner
        fold_avoid = fold_size + m
        if ly > (cy + ch - fold_avoid):
            # Gradually shorten
            overlap = ly - (cy + ch - fold_avoid)
            lx2 = max(lx1, lx2 - int(overlap * 2.5))
        ld.line([(lx1, ly), (lx2, ly)], fill=LINE_COLOR, width=int(SIZE * 0.0025))

    # ── 5. Accent marker line (purple highlight) ──
    accent_y = line_start_y + 3 * line_spacing
    accent_len = int(SIZE * 0.12)
    accent_x = cx + line_margin_x
    ld.line(
        [(accent_x, accent_y), (accent_x + accent_len, accent_y)],
        fill=ACCENT_COLOR, width=int(SIZE * 0.022)
    )

    img = Image.alpha_composite(img, lines_img)

    # ── 6. Bookmark Ribbon ──
    ribbon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rd = ImageDraw.Draw(ribbon)

    ribbon_w = int(SIZE * 0.055)
    ribbon_x = cx + cw - int(SIZE * 0.07)
    ribbon_y1 = cy + int(SIZE * 0.12)
    ribbon_y2 = cy + ch + int(SIZE * 0.15)  # Hang below the card
    ribbon_notch = int(SIZE * 0.025)  # V-notch height

    # Ribbon body (rounded top, straight sides, V-notch bottom)
    r_points = [
        (ribbon_x, ribbon_y1 + int(ribbon_w * 0.4)),  # Start at rounded top
        (ribbon_x + ribbon_w // 2, ribbon_y1),  # Top center
        (ribbon_x + ribbon_w, ribbon_y1 + int(ribbon_w * 0.4)),  # Top right curve
        (ribbon_x + ribbon_w, ribbon_y2 - ribbon_notch),  # Right side to notch
        (ribbon_x + ribbon_w // 2 + ribbon_notch // 2, ribbon_y2 - ribbon_notch),  # V-notch right
        (ribbon_x + ribbon_w // 2, ribbon_y2),  # V-notch point
        (ribbon_x + ribbon_w // 2 - ribbon_notch // 2, ribbon_y2 - ribbon_notch),  # V-notch left
        (ribbon_x, ribbon_y2 - ribbon_notch),  # Left side to notch
    ]

    # Create ribbon gradient
    ribbon_grad = diagonal_gradient(
        (SIZE, SIZE),
        RIBBON_TOP + (255,),
        RIBBON_BOT + (255,)
    )

    # Mask for ribbon
    ribbon_mask = Image.new("L", (SIZE, SIZE), 0)
    rmd = ImageDraw.Draw(ribbon_mask)
    rmd.polygon(r_points, fill=255)

    # Apply gradient through mask
    ribbon_colored = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    ribbon_colored.paste(ribbon_grad, (0, 0), ribbon_mask)

    # Ribbon shadow on card
    ribbon_shadow = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    rsd = ImageDraw.Draw(ribbon_shadow)
    # Shadow offset to the left
    shadow_r_points = [(x - int(SIZE * 0.004), y) for x, y in r_points]
    rsd.polygon(shadow_r_points, fill=(40, 20, 50, 30))

    img = Image.alpha_composite(img, ribbon_shadow)
    img = Image.alpha_composite(img, ribbon_colored)

    # ── 7. Subtle texture/noise on paper ──
    noise = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    import random
    random.seed(42)
    for _ in range(2000):
        x = random.randint(cx + m, cx + cw - m)
        y = random.randint(cy + m, cy + ch - m)
        v = random.randint(0, 15)
        noise.putpixel((x, y), (v, v, v, 8))
    img = Image.alpha_composite(img, noise)

    return img


if __name__ == "__main__":
    print("🎨 Generating Noto icon v2 (minimal notecard)...")
    icon = generate_icon()
    icon.save("/tmp/noto-v2-master.png")
    print(f"✅ Saved: /tmp/noto-v2-master.png ({icon.size[0]}x{icon.size[1]})")

    # Generate all iconset sizes
    ICON_TYPES = [
        ('ic11', 32),
        ('ic12', 64),
        ('ic07', 128),
        ('ic08', 256),
        ('ic09', 512),
        ('ic10', 1024),
    ]

    entries = b''
    for code, size in ICON_TYPES:
        resized = icon.resize((size, size), Image.LANCZOS)
        buf = io.BytesIO()
        resized.save(buf, format='PNG')
        png_data = buf.getvalue()
        entry_size = 8 + len(png_data)
        entries += code.encode('ascii') + struct.pack('>I', entry_size) + png_data
        print(f"  {code}: {size}x{size} -> {len(png_data)} bytes")

    total_size = 8 + len(entries)
    icns_data = b'icns' + struct.pack('>I', total_size) + entries

    with open("/tmp/noto-v2.icns", 'wb') as f:
        f.write(icns_data)
    print(f"\n✅ ICNS: /tmp/noto-v2.icns ({total_size} bytes)")

    # Also generate preview
    preview = Image.new('RGB', (1024 + 200, 240), (245, 245, 245))
    pd = ImageDraw.Draw(preview)
    x = 20
    for s in [1024, 128, 64, 32, 16]:
        r = icon.resize((s, s), Image.LANCZOS)
        preview.paste(r, (x, 20))
        pd.text((x, 20 + s + 5), f'{s}x{s}', fill=(120, 120, 120))
        x += s + 20
    preview.save("/tmp/noto-v2-preview.png")
    print("✅ Preview: /tmp/noto-v2-preview.png")
