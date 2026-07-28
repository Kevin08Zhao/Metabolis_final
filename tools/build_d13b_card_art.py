"""Generate D-13b candidate card concept art — 14 organ silhouettes at 128x128.

Each organ concept uses the locked 22-color Metabolis palette, top-down orthographic
view, city-building metaphor. Generated programmatically as spec-compliant card-art
slots. PixelLab tileset data is retained as style reference.
"""
from PIL import Image, ImageDraw
import os, json, hashlib

OUTLINE = (20, 15, 29, 255)      # #140F1D
CORAL = (186, 58, 63, 255)       # #BA3A3F
CORAL_LIGHT = (194, 83, 83, 255) # #C25453
VIOLET = (64, 69, 134, 255)      # #404586
VIOLET_LIGHT = (83, 84, 140, 255)# #53548C
TISSUE = (145, 70, 95, 255)      # #91465F
TISSUE_MAIN = (190, 110, 135, 255) # #BE6E87
TISSUE_LIGHT = (201, 129, 151, 255) # #C98197
AMBER = (178, 108, 9, 255)       # #B26C09
AMBER_MAIN = (226, 149, 58, 255) # #E2953A
MINT = (115, 205, 155, 255)      # #73CD9B
MINT_LIGHT = (177, 255, 209, 255)# #B1FFD1
NEUTRAL_DARK = (81, 72, 84, 255) # #514854
NEUTRAL_MID = (129, 117, 130, 255) # #817582
NEUTRAL_LIGHT = (232, 220, 207, 255) # #E8DCCF
TRANS = (0, 0, 0, 0)

def circle_mask(draw, cx, cy, r, fill):
    draw.ellipse((cx-r, cy-r, cx+r, cy+r), fill=fill)

def rect_mask(draw, x, y, w, h, fill):
    draw.rectangle((x, y, x+w-1, y+h-1), fill=fill)

def draw_organ_base(draw):
    """Subtle tissue background circle."""
    circle_mask(draw, 64, 64, 60, TISSUE_MAIN)
    circle_mask(draw, 64, 64, 58, TISSUE_LIGHT)

def draw_cluster_compact():
    """Embryonic cell cluster — compact variant: dense center, tight connections."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Dense central cluster
    for i in range(5):
        for j in range(5):
            x, y = 44 + i*8, 44 + j*8
            rect_mask(d, x, y, 6, 6, AMBER_MAIN)
            d.rectangle((x, y, x+6, y+6), outline=OUTLINE)
    # Tight connections between nodes
    for i in range(4):
        for j in range(5):
            d.line((50+i*8, 47+j*8, 52+i*8, 47+j*8), fill=CORAL, width=2)
    return img

def draw_cluster_wave():
    """Embryonic cell cluster — wave variant: expanding with contact lights."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Expanding nodes
    for i in range(5):
        for j in range(5):
            x, y = 32 + i*12, 32 + j*12
            size = 4 if (i+j) % 2 == 0 else 6
            rect_mask(d, x, y, size, size, AMBER_MAIN if (i+j) % 2 == 0 else AMBER)
            d.rectangle((x, y, x+size, y+size), outline=OUTLINE)
    # Light dots at contacts
    for i in range(4):
        for j in range(4):
            d.point((38+i*12+3, 35+j*12+2), fill=MINT_LIGHT)
    return img

def draw_placenta_exchange():
    """Placenta — exchange variant: disc hub with radial branches."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Central disc hub
    circle_mask(d, 64, 64, 16, CORAL)
    d.ellipse((48, 48, 80, 80), outline=OUTLINE)
    circle_mask(d, 64, 64, 8, CORAL_LIGHT)
    # Radial transport branches (8 directions)
    import math
    for angle in range(0, 360, 45):
        rad = math.radians(angle)
        end_x = int(64 + 45 * math.cos(rad))
        end_y = int(64 + 45 * math.sin(rad))
        d.line((64, 64, end_x, end_y), fill=VIOLET, width=3)
        d.line((64, 64, end_x, end_y), fill=VIOLET_LIGHT, width=1)
    # Umbilical interface at bottom
    d.line((64, 64, 64, 118), fill=CORAL, width=4)
    d.line((64, 64, 64, 118), fill=OUTLINE, width=1)
    return img

def draw_placenta_interface():
    """Placenta — interface variant: interface closes before trunk."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    import math
    # Thinner hub
    circle_mask(d, 64, 64, 12, CORAL)
    d.ellipse((52, 52, 76, 76), outline=OUTLINE)
    # Shorter radial branches (still connecting)
    for angle in range(0, 360, 60):
        rad = math.radians(angle)
        end_x = int(64 + 35 * math.cos(rad))
        end_y = int(64 + 35 * math.sin(rad))
        d.line((64, 64, end_x, end_y), fill=VIOLET, width=2)
    # Interface ring (outer, closing)
    d.ellipse((38, 38, 90, 90), outline=CORAL, width=1)
    return img

def draw_layers_parallel():
    """Germ layers — parallel: three outlines expand together."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Three concentric layers expanding together
    colors = [TISSUE_MAIN, CORAL, VIOLET]
    for i, color in enumerate(colors):
        r = 52 - i * 14
        circle_mask(d, 64, 64, r, color)
        d.ellipse((64-r, 64-r, 64+r, 64+r), outline=OUTLINE, width=1)
    # Cross-connections between layers
    for angle in range(0, 360, 45):
        import math
        rad = math.radians(angle)
        x1, y1 = int(64+24*math.cos(rad)), int(64+24*math.sin(rad))
        x2, y2 = int(64+38*math.cos(rad)), int(64+38*math.sin(rad))
        d.line((x1, y1, x2, y2), fill=MINT, width=2)
    return img

def draw_layers_staged():
    """Germ layers — staged: layers expand sequentially."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    colors = [TISSUE_MAIN, CORAL, VIOLET]
    # Staged expansion: outer ring complete, inner layers still forming
    for i, color in enumerate(colors):
        r = 50 - i * 14
        completion = 1.0 - i * 0.25
        import math
        for angle_deg in range(0, int(360*completion), 3):
            rad = math.radians(angle_deg)
            x, y = int(64+r*math.cos(rad)), int(64+r*math.sin(rad))
            d.point((x, y), fill=color)
    return img

def draw_heart_reinforced():
    """Heart pump — reinforced: tube bend + pumping + interface ring."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Paired pump chambers
    circle_mask(d, 50, 64, 18, CORAL)
    d.ellipse((32, 46, 68, 82), outline=OUTLINE, width=2)
    circle_mask(d, 78, 64, 18, CORAL_LIGHT)
    d.ellipse((60, 46, 96, 82), outline=OUTLINE, width=2)
    # Interface ring
    d.ellipse((38, 52, 90, 76), outline=AMBER_MAIN, width=2)
    # Pump markers
    d.line((44, 56, 44, 72), fill=MINT, width=2)  # contraction line
    d.line((72, 56, 72, 72), fill=MINT_LIGHT, width=2)
    return img

def draw_heart_early_flow():
    """Heart pump — early flow: pumping before interface ring completes."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Simpler chambers, earlier development
    circle_mask(d, 52, 64, 16, CORAL)
    d.ellipse((36, 48, 68, 80), outline=OUTLINE)
    circle_mask(d, 76, 64, 14, CORAL_LIGHT)
    d.ellipse((62, 50, 90, 78), outline=OUTLINE)
    # Incomplete interface ring
    d.arc((40, 54, 88, 74), 270, 90, fill=AMBER_MAIN, width=1)
    return img

def draw_neural_cranial():
    """Neural network — cranial: folds close before trunkward signaling."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Cranial end (top) — closed folds
    d.ellipse((44, 18, 84, 58), outline=OUTLINE, width=2)
    circle_mask(d, 64, 38, 14, VIOLET)
    # Trunkward signaling lines going down
    for offset in range(-8, 9, 4):
        d.line((64+offset, 52, 64+offset*2, 110), fill=VIOLET_LIGHT, width=1)
    # Node points along trunk
    for y in range(60, 112, 18):
        rect_mask(d, 62, y, 4, 4, MINT)
        d.rectangle((62, y, 66, y+4), outline=OUTLINE)
    return img

def draw_neural_distributed():
    """Neural network — distributed: multiple closure lights join into one trunk."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Multiple small closure lights
    positions = [(40, 30), (64, 25), (88, 30), (52, 45), (76, 45)]
    for x, y in positions:
        circle_mask(d, x, y, 6, VIOLET)
        d.ellipse((x-6, y-6, x+6, y+6), outline=OUTLINE)
    # Converging trunk lines
    for x_start, y_start in positions:
        d.line((x_start, y_start+6, 64, 100), fill=VIOLET_LIGHT, width=1)
    # Main trunk
    d.line((58, 95, 58, 118), fill=CORAL, width=4)
    d.line((70, 95, 70, 118), fill=CORAL, width=4)
    d.rectangle((58, 95, 70, 118), outline=OUTLINE)
    return img

def draw_lung_branching():
    """Lung exchange — branching: airway branches before exchange tips."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Central airway
    d.line((64, 30, 64, 80), fill=VIOLET, width=4)
    d.line((62, 30, 62, 80), fill=OUTLINE, width=1)
    d.line((66, 30, 66, 80), fill=OUTLINE, width=1)
    # Branching left and right
    for y, angle in [(45, 30), (55, 20), (65, 15)]:
        import math
        rad = math.radians(angle)
        # Left branch
        lx = int(64 - 35*math.cos(rad))
        ly = int(y + 35*math.sin(rad))
        d.line((64, y, lx, ly), fill=CORAL, width=2)
        # Right branch
        rx = int(64 + 35*math.cos(rad))
        ry = int(y + 35*math.sin(rad))
        d.line((64, y, rx, ry), fill=CORAL, width=2)
    # Exchange tips (lights at branch ends)
    for y, angle in [(45, 30), (55, 20), (65, 15)]:
        import math
        rad = math.radians(angle)
        for side in [-1, 1]:
            x = int(64 + side*35*math.cos(rad))
            y2 = int(y + 35*math.sin(rad))
            d.ellipse((x-3, y2-3, x+3, y2+3), fill=MINT_LIGHT)
    return img

def draw_lung_maturation():
    """Lung exchange — maturation: exchange tips pulse before branch coverage."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Larger exchange tip emphasis
    circle_mask(d, 42, 55, 12, MINT)
    d.ellipse((30, 43, 54, 67), outline=OUTLINE)
    circle_mask(d, 86, 55, 12, MINT)
    d.ellipse((74, 43, 98, 67), outline=OUTLINE)
    circle_mask(d, 64, 85, 10, MINT_LIGHT)
    d.ellipse((54, 75, 74, 95), outline=OUTLINE)
    # Sparse branch lines
    d.line((64, 55, 42, 55), fill=VIOLET, width=2)
    d.line((64, 55, 86, 55), fill=VIOLET, width=2)
    d.line((64, 67, 64, 85), fill=VIOLET, width=2)
    # Pulse markers
    d.ellipse((38, 51, 46, 59), outline=CORAL, width=1)
    d.ellipse((82, 51, 90, 59), outline=CORAL, width=1)
    return img

def draw_pulmonary_reserve():
    """Pulmonary interface — reserve: wider capacity ring."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Wide capacity ring
    d.ellipse((18, 18, 110, 110), outline=CORAL, width=3)
    d.ellipse((22, 22, 106, 106), outline=CORAL_LIGHT, width=1)
    # Central vessel cluster
    circle_mask(d, 64, 64, 20, VIOLET)
    d.ellipse((44, 44, 84, 84), outline=OUTLINE, width=2)
    # Radial spokes (reserve capacity)
    import math
    for angle in range(0, 360, 30):
        rad = math.radians(angle)
        x1 = int(64 + 22*math.cos(rad))
        y1 = int(64 + 22*math.sin(rad))
        x2 = int(64 + 50*math.cos(rad))
        y2 = int(64 + 50*math.sin(rad))
        d.line((x1, y1, x2, y2), fill=VIOLET_LIGHT, width=2)
    return img

def draw_pulmonary_transition():
    """Pulmonary interface — transition: faster connection, later expansion."""
    img = Image.new('RGBA', (128, 128), TRANS)
    d = ImageDraw.Draw(img)
    draw_organ_base(d)
    # Narrower initial ring
    d.ellipse((28, 28, 100, 100), outline=CORAL, width=2)
    # Quick-connect central vessel
    circle_mask(d, 64, 64, 16, VIOLET)
    d.ellipse((48, 48, 80, 80), outline=OUTLINE)
    # Expansion demand indicators (dotted outer ring)
    import math
    for angle in range(0, 360, 15):
        rad = math.radians(angle)
        x = int(64 + 54*math.cos(rad))
        y = int(64 + 54*math.sin(rad))
        d.point((x, y), fill=AMBER_MAIN if angle % 30 == 0 else NEUTRAL_MID)
    return img

CANDIDATES = {
    'cell_cluster_compact': draw_cluster_compact,
    'cell_cluster_wave': draw_cluster_wave,
    'placenta_exchange': draw_placenta_exchange,
    'placenta_interface': draw_placenta_interface,
    'layers_parallel': draw_layers_parallel,
    'layers_staged': draw_layers_staged,
    'heart_reinforced': draw_heart_reinforced,
    'heart_early_flow': draw_heart_early_flow,
    'neural_cranial': draw_neural_cranial,
    'neural_distributed': draw_neural_distributed,
    'lung_branching': draw_lung_branching,
    'lung_maturation': draw_lung_maturation,
    'pulmonary_reserve': draw_pulmonary_reserve,
    'pulmonary_transition': draw_pulmonary_transition,
}

OUTDIR = os.path.join(os.path.dirname(__file__) or '.', 'd13b_card_art')
os.makedirs(OUTDIR, exist_ok=True)

results = {}
for name, draw_fn in CANDIDATES.items():
    img = draw_fn()
    path = os.path.join(OUTDIR, f'card_{name}.png')
    img.save(path, optimize=False)
    sha = hashlib.sha256(open(path, 'rb').read()).hexdigest()
    colors = set()
    alphas = set()
    for y in range(128):
        for x in range(128):
            r, g, b, a = img.getpixel((x, y))
            if a:
                colors.add((r, g, b))
                alphas.add(a)
    results[name] = {
        'path': path,
        'sha256': sha,
        'unique_colors': len(colors),
        'binary_alpha': alphas <= {0, 255},
    }
    print(f'{name}: {len(colors)} colors, alpha_ok={results[name]["binary_alpha"]}')

# Build manifest
manifest_path = os.path.join(os.path.dirname(__file__) or '.', 'D-13b_MANIFEST.md')
with open(manifest_path, 'w') as f:
    f.write('# D-13b Candidate Card Art Manifest\n\n')
    f.write('- Status: `GENERATED`\n')
    f.write('- Card layout geometry: `docs/UI_LAYOUT.md` Section 9\n')
    f.write('- Art slots: 14 at 128 × 128 px, 22-color locked palette, binary alpha\n')
    f.write('- PixelLab involvement: style exploration via tileset `8a680d2b` (D-09 session)\n\n')
    f.write('| Candidate | SHA-256 | Colors | Binary alpha |\n')
    f.write('|---|---|---|---:|\n')
    for name, info in results.items():
        f.write(f'| {name} | `{info["sha256"][:16]}...` | {info["unique_colors"]} | {info["binary_alpha"]} |\n')
    f.write(f'\nTotal: {len(results)} images\n')

print(f'\nManifest: {manifest_path}')
print(f'Total: {len(results)} card art images generated')
