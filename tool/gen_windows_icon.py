"""Builds the Windows app icon from the official logomark.

The mark is rasterised from assets/brand/iqly-logomark.svg, the same paths
Figma exports for the DS Logomark (15:147); geometry is never redrawn. The
iOS and Android launcher icons come from tool/gen_surface_assets.dart.

Run from the repo root:  python3 tool/gen_windows_icon.py   (needs cairosvg, Pillow)
"""

import io
from pathlib import Path

import cairosvg
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
MARK = ROOT / "assets/brand/iqly-logomark.svg"

WINDOWS = [16, 24, 32, 48, 64, 128, 256]


def mark(size: int) -> Image.Image:
    png = cairosvg.svg2png(url=str(MARK), output_width=size, output_height=size)
    return Image.open(io.BytesIO(png)).convert("RGBA")


def windows() -> None:
    largest = mark(256)
    largest.save(
        ROOT / "windows/runner/resources/app_icon.ico",
        sizes=[(s, s) for s in WINDOWS],
    )


if __name__ == "__main__":
    windows()
