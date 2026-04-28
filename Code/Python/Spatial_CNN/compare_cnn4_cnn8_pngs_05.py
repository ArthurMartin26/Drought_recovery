# ======================================================
# compare_cnn4_cnn8_pngs.py
# Side-by-side comparison of CNN_4 vs CNN_8 PNG maps
# ======================================================

import pathlib
from PIL import Image, ImageDraw, ImageFont

PROJECT_ROOT = pathlib.Path(__file__).resolve().parents[3]

DIR_4 = PROJECT_ROOT / "Outputs" / "Figures" / "CNN_4"
DIR_8 = PROJECT_ROOT / "Outputs" / "Figures" / "CNN_8"
OUTDIR = PROJECT_ROOT / "Outputs" / "Figures" / "CNN_compare"
OUTDIR.mkdir(parents=True, exist_ok=True)

# Change if your filenames differ
def fname(z): 
    return f"{z}_spatial.png"

# list dimensions found in CNN_8 folder (z_0 ... z_7)
z_files = sorted([p.name for p in DIR_8.glob("z_*_spatial.png")])
z_dims = [p.replace("_spatial.png", "") for p in z_files]  # ["z_0", ...]

def add_label(img, text):
    img = img.copy()
    draw = ImageDraw.Draw(img)
    # default font is fine; avoids font issues on work laptops
    draw.rectangle([(0, 0), (img.size[0], 30)], fill=(255, 255, 255))
    draw.text((8, 6), text, fill=(0, 0, 0))
    return img

combined_paths = []

for z in z_dims:
    p4 = DIR_4 / fname(z)
    p8 = DIR_8 / fname(z)
    if not p8.exists():
        continue

    img8 = Image.open(p8).convert("RGB")
    img8 = add_label(img8, f"{z} | CNN_8")

    if p4.exists():
        img4 = Image.open(p4).convert("RGB")
        img4 = add_label(img4, f"{z} | CNN_4")
    else:
        # if z_4..z_7 don't exist in CNN_4, create a blank placeholder
        img4 = Image.new("RGB", img8.size, (240, 240, 240))
        img4 = add_label(img4, f"{z} | CNN_4 (not available)")

    # make heights match
    H = max(img4.size[1], img8.size[1])
    W = img4.size[0] + img8.size[0]
    canvas = Image.new("RGB", (W, H), (255, 255, 255))
    canvas.paste(img4, (0, 0))
    canvas.paste(img8, (img4.size[0], 0))

    out_path = OUTDIR / f"compare_{z}_CNN4_vs_CNN8.png"
    canvas.save(out_path, quality=95)
    combined_paths.append(out_path)

print(f"Saved {len(combined_paths)} side-by-side comparisons to:\n{OUTDIR}")