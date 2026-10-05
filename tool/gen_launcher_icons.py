"""Builds the launcher icons from the official logomark.

The app icon in the Figma frames (B18 347:16308, B19 350:17773) is the DS
Logomark (Tone=On light, 15:147 in the design system file) at 68% on a white
tile. Geometry is never redrawn: the mark is rasterised from
assets/brand/iqly-logomark.svg, the same paths Figma exports for 15:147.

Writes the iOS AppIcon set (opaque), the Android legacy mipmaps (the adaptive
icon is a vector, see tool/gen_surface_assets.dart) and the Windows .ico.

Run from the repo root:  python3 tool/gen_launcher_icons.py   (needs cairosvg, Pillow)
"""

import io
import json
from pathlib import Path

import cairosvg
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
MARK = ROOT / "assets/brand/iqly-logomark.svg"
TILE = (255, 255, 255)
MARK_SCALE = 0.68

ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
WINDOWS = [16, 24, 32, 48, 64, 128, 256]


def mark(size: int) -> Image.Image:
    png = cairosvg.svg2png(url=str(MARK), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def on_tile(size: int, round_tile: bool) -> Image.Image:
    scale = 4
    big = size * scale
    canvas = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    if round_tile:
        ImageDraw.Draw(canvas).ellipse((0, 0, big - 1, big - 1), fill=TILE + (255,))
    else:
        canvas.paste(TILE + (255,), (0, 0, big, big))
    m = round(big * MARK_SCALE)
    offset = (big - m) // 2
    glyph = mark(m)
    canvas.alpha_composite(glyph, (offset, offset))
    return canvas.resize((size, size), Image.LANCZOS)


def ios() -> None:
    folder = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((folder / "Contents.json").read_text())
    for image in contents["images"]:
        points = float(image["size"].split("x")[0])
        px = round(points * int(image["scale"].rstrip("x")))
        on_tile(px, round_tile=False).convert("RGB").save(folder / image["filename"])


def android() -> None:
    for density, px in ANDROID.items():
        folder = ROOT / f"android/app/src/main/res/mipmap-{density}"
        icon = on_tile(px, round_tile=True)
        icon.save(folder / "ic_launcher.png")
        icon.save(folder / "ic_launcher_round.png")


def windows() -> None:
    largest = mark(256)
    largest.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in WINDOWS],
    )


if __name__ == "__main__":
    ios()
    android()
    windows()
