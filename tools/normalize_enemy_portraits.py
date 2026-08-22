from pathlib import Path
import sys

from PIL import Image


CANVAS = (96, 128)
CONTENT = (88, 120)


def normalize(source: Path, destination: Path) -> None:
    image = Image.open(source).convert("RGBA")
    alpha_box = image.getchannel("A").getbbox()
    if alpha_box is None:
        raise ValueError(f"Image has no visible pixels: {source}")
    image = image.crop(alpha_box)
    scale = min(CONTENT[0] / image.width, CONTENT[1] / image.height)
    resized = image.resize(
        (max(1, round(image.width * scale)), max(1, round(image.height * scale))),
        Image.Resampling.LANCZOS,
    )
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    position = ((CANVAS[0] - resized.width) // 2, CANVAS[1] - resized.height - 4)
    canvas.alpha_composite(resized, position)
    destination.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(destination, optimize=True)


if __name__ == "__main__":
    if len(sys.argv) != 3:
        raise SystemExit("Usage: normalize_enemy_portraits.py SOURCE DESTINATION")
    normalize(Path(sys.argv[1]), Path(sys.argv[2]))
