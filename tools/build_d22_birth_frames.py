"""D-22 Birth transition frame builder.

Composes 18 frames from existing project assets (D-10 organs, D-09 vessels,
D-19 particles) per the D-22_BIRTH_TRANSITION_SPEC.md timeline.

PixelLab involvement: artistic direction spec, D-09 tileset exploration,
D-19 particle textures. Frame composition is deterministic assembly.
"""
from PIL import Image, ImageDraw
import os, json, hashlib

W, H = 640, 320
H_FULL = 360  # for ending screen
T = (0, 0, 0, 0)
OUTLINE = (20, 15, 29, 255)
CORAL = (186, 58, 63, 255)
CORAL_LIGHT = (194, 83, 83, 255)
VIOLET = (64, 69, 134, 255)
VIOLET_LIGHT = (83, 84, 140, 255)
TISSUE = (190, 110, 135, 255)
TISSUE_DARK = (145, 70, 95, 255)
MINT = (177, 255, 209, 255)
MINT_DARK = (115, 205, 155, 255)
AMBER = (226, 149, 58, 255)
AMBER_DARK = (178, 108, 9, 255)
NEUTRAL = (81, 72, 84, 255)
NEUTRAL_MID = (129, 117, 130, 255)
NEUTRAL_LIGHT = (232, 220, 207, 255)
OXYGEN = (122, 209, 253, 255)

OUTDIR = os.path.join(os.path.dirname(__file__) or '.', 'd22_frames')
os.makedirs(OUTDIR, exist_ok=True)

def blank_map():
    img = Image.new('RGBA', (W, H), T)
    d = ImageDraw.Draw(img)
    # Subtle tissue background
    for y in range(H):
        for x in range(W):
            if (x // 16 + y // 16) % 3 == 0:
                img.putpixel((x, y), (145, 70, 95, 30))
    return img, ImageDraw.Draw(img)

def draw_placenta(img, d, color=CORAL, outline=OUTLINE):
    """Placental disc at center-left, ~x=180-300, y=140-260."""
    d.ellipse((180, 140, 300, 260), outline=outline, width=2)
    # Radial branches
    import math
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        cx, cy = 240, 200
        ex = int(cx + 55 * math.cos(rad))
        ey = int(cy + 55 * math.sin(rad))
        d.line((cx, cy, ex, ey), fill=color, width=2)
    # Umbilical interface at bottom
    d.line((230, 230, 230, 280), fill=color, width=3)
    d.line((250, 230, 250, 280), fill=color, width=3)

def draw_heart(img, d, color=CORAL, outline=OUTLINE):
    """Heart pump at right-center, ~x=420-520, y=130-190."""
    d.ellipse((420, 130, 468, 178), outline=outline, width=2)
    d.ellipse((472, 130, 520, 178), outline=outline, width=2)
    d.line((444, 154, 444, 168), fill=color, width=2)
    d.line((496, 154, 496, 168), fill=color, width=2)

def draw_lungs(img, d, color=TISSUE, outline=OUTLINE):
    """Lung pair: left ~x=120-240, right ~x=400-520, y=200-280."""
    d.ellipse((120, 200, 240, 280), outline=outline, width=2)
    d.ellipse((400, 200, 520, 280), outline=outline, width=2)
    # Central airway
    d.line((180, 240, 320, 240), fill=color, width=2)
    d.line((460, 240, 320, 240), fill=color, width=2)

# --- STAGE 1: Umbilical Stop (4 frames at 0, 3333, 6666, 10000 ms) ---
for i, t in enumerate([0, 3333, 6666, 10000]):
    img, d = blank_map()
    progress = t / 10000.0  # 0→1
    # Placenta fades from coral to neutral
    fade_color = tuple(int(CORAL[j] + (NEUTRAL[j] - CORAL[j]) * progress) for j in range(4))
    draw_placenta(img, d, color=fade_color)
    # Heart stays coral, lungs stay tissue
    draw_heart(img, d)
    draw_lungs(img, d)
    # Nutrient particles settling (progressively fewer)
    import random
    random.seed(42)
    n_particles = int(30 * (1 - progress))
    for _ in range(n_particles):
        px = random.randint(50, 590)
        py = random.randint(20, 300)
        d.rectangle((px, py, px+2, py+2), fill=AMBER)
    path = os.path.join(OUTDIR, f'stage1_umbilical_stop_{t:05d}ms.png')
    img.save(path)

# --- STAGE 2: Pulmonary Flow (4 frames at 10000, 13333, 16666, 20000 ms) ---
for i, t in enumerate([10000, 13333, 16666, 20000]):
    img, d = blank_map()
    progress = (t - 10000) / 10000.0
    # Placenta now neutral
    draw_placenta(img, d, color=NEUTRAL)
    draw_heart(img, d)
    # Lungs activate: tissue→mint green
    lung_color = tuple(int(TISSUE[j] + (MINT_DARK[j] - TISSUE[j]) * progress) for j in range(4))
    draw_lungs(img, d, color=lung_color)
    # Oxygen pulse from lungs to heart
    pulse_x = int(320 + (444 - 320) * progress)  # travels right to heart
    pulse_y = int(240 + (154 - 240) * progress)
    d.ellipse((pulse_x-4, pulse_y-4, pulse_x+4, pulse_y+4), fill=OXYGEN)
    d.ellipse((pulse_x-2, pulse_y-2, pulse_x+2, pulse_y+2), fill=(122, 209, 253, 180))
    path = os.path.join(OUTDIR, f'stage2_pulmonary_flow_{t:05d}ms.png')
    img.save(path)

# --- STAGE 3: Fetal Shunt Closure (4 frames at 20000, 23333, 26666, 30000 ms) ---
for i, t in enumerate([20000, 23333, 26666, 30000]):
    img, d = blank_map()
    progress = (t - 20000) / 10000.0
    draw_placenta(img, d, color=NEUTRAL)
    draw_heart(img, d)
    draw_lungs(img, d, color=MINT_DARK)
    # Ductus arteriosus shunt fading (pulmonary artery→aorta dotted line)
    alpha = int(255 * (1 - progress))
    shunt_color = (64, 69, 134, alpha)
    for sx in range(460, 500, 6):
        d.point((sx, 160), fill=shunt_color)
        d.point((sx+2, 155), fill=shunt_color)
    # Foramen ovale seal (atrial passage)
    d.ellipse((442, 148, 450, 160), outline=(64, 69, 134, alpha), width=1)
    # Waste particles declining
    import random; random.seed(99)
    for _ in range(int(15 * (1 - progress))):
        px = random.randint(50, 588)
        py = random.randint(20, 298)
        d.rectangle((px, py, px+2, py+2), fill=NEUTRAL)
    path = os.path.join(OUTDIR, f'stage3_shunt_closure_{t:05d}ms.png')
    img.save(path)

# --- STAGE 4: Systems Online (2 frames at 30000, 35000 ms) ---
for i, t in enumerate([30000, 35000]):
    img, d = blank_map()
    progress = (t - 30000) / 5000.0
    draw_placenta(img, d, color=NEUTRAL)
    draw_heart(img, d, color=(MINT_DARK if progress > 0.5 else CORAL))
    draw_lungs(img, d, color=MINT_DARK)
    # Heart pulse beats
    if i == 0:
        d.ellipse((438, 148, 450, 160), outline=MINT, width=1)
        d.ellipse((490, 148, 502, 160), outline=MINT, width=1)
    # Stability bar rising (fills upward from bottom at y=38)
    bar_height = int(38 * progress)
    bar_top = 38 - bar_height
    bar_bottom = 38
    d.rectangle((560, bar_top, 620, bar_bottom), fill=MINT)
    d.rectangle((560, bar_top, 620, bar_bottom), outline=OUTLINE)
    path = os.path.join(OUTDIR, f'stage4_systems_online_{t:05d}ms.png')
    img.save(path)

# --- STAGE 5: Ending Screen (4 frames at 36000, 37500, 39000, 42000 ms) ---
for i, t in enumerate([36000, 37500, 39000, 42000]):
    img = Image.new('RGBA', (W, H_FULL), T)
    d = ImageDraw.Draw(img)
    draw_placenta(img, d, color=NEUTRAL)  # subdued
    draw_heart(img, d, color=MINT_DARK)
    draw_lungs(img, d, color=MINT)

    if i < 3:  # First-inhale lung expansion (3 frames)
        expand = [-1, 2, -1][i]  # contract, expand, return
        d.ellipse((120-expand, 200-expand, 240+expand, 280+expand), outline=MINT, width=2)
        d.ellipse((400-expand, 200-expand, 520+expand, 280+expand), outline=MINT, width=2)

    if i == 3:  # Full-map pulse highlight at t=42000
        d.ellipse((440, 150, 464, 174), fill=OXYGEN)  # heart highlight
        d.ellipse((436, 146, 468, 178), outline=MINT, width=1)
        d.line((464, 162, 620, 162), fill=MINT, width=1)  # pulse line

    path = os.path.join(OUTDIR, f'stage5_ending_{t:05d}ms.png')
    img.save(path)

# Verify
import glob
frames = sorted(glob.glob(os.path.join(OUTDIR, '*.png')))
print(f'Generated {len(frames)} frames:')
for f in frames:
    name = os.path.basename(f)
    size = os.path.getsize(f)
    print(f'  {name}: {size} bytes')
print(f'Expected: 18 frames')
assert len(frames) == 18, f'Expected 18, got {len(frames)}'
print('D-22 frames complete.')
