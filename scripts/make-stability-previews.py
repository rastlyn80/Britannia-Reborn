"""Assemble moving-camera captures using one shared GIF palette."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1] / "outputs" / "validation"
for prefix in ("stable-tavern", "stable-doorway", "stable-banks"):
    paths = sorted(root.glob(prefix + "-[0-9][0-9].png"))
    if len(paths) != 24:
        raise RuntimeError(f"Expected 24 frames for {prefix}, got {len(paths)}")
    frames = [Image.open(path).convert("RGB").resize((800, 500), Image.Resampling.LANCZOS) for path in paths]
    samples = Image.new("RGB", (160, 100 * len(frames)))
    for index, frame in enumerate(frames):
        samples.paste(frame.resize((160, 100)), (0, index * 100))
    palette = samples.quantize(colors=256)
    encoded = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    encoded[0].save(root / (prefix + ".gif"), save_all=True, append_images=encoded[1:], duration=85, loop=0, disposal=2)
    print(root / (prefix + ".gif"))
