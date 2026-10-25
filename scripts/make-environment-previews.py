"""Assemble controlled-time GPU frames; requires Pillow (bundled in Codex)."""
from pathlib import Path
from PIL import Image
root = Path(__file__).resolve().parents[1] / "outputs" / "validation"
for prefix, output in [("nature-frame", "living-environment.gif"), ("water-frame", "moving-water.gif")]:
    frames = [Image.open(root / f"{prefix}-{i:02d}.png").convert("RGB").resize((800, 500)) for i in range(30)]
    palette = frames[0].quantize(colors=128)
    frames = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    frames[0].save(root / output, save_all=True, append_images=frames[1:] + frames[-2:0:-1], duration=100, loop=0)
    for frame in frames:
        frame.close()
print("Rendered forest and water previews assembled.")
