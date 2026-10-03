"""Derives the splash layers and native splash PNGs from the official logomark.

The grey boot state is authorised for the splash only (Figma Splash/Mark).
Geometry is never redrawn: every path is copied from assets/brand/iqly-logomark-cream.svg.

Run from the repo root:  python3 tool/gen_splash_assets.py   (needs cairosvg)
"""

import re
from pathlib import Path

import cairosvg

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "assets/brand/iqly-logomark-cream.svg"
OUT = ROOT / "assets/splash"

GREY = "#A1A1A1"
ORANGE = "#F58028"
CREAM = "#FBF6EE"
HEAD = '<svg xmlns="http://www.w3.org/2000/svg" width="1000" height="1000" viewBox="0 0 1000 1000" fill="none">'


def main() -> None:
    src = SOURCE.read_text()
    tile = re.search(r'<mask[^>]*>\s*<path d="([^"]+)"', src).group(1)
    paths = re.findall(r'<path d="([^"]+)" fill="#F58028"/>', src)
    assert len(paths) == 4, "expected the brush path and three bulb paths"
    brush, bulb = paths[0], paths[1:]

    def glyph(brush_fill: str, bulb_fill: str) -> str:
        body = f'<path d="{brush}" fill="{brush_fill}"/>' + "".join(
            f'<path d="{p}" fill="{bulb_fill}"/>' for p in bulb
        )
        mask = (
            '<mask id="m" style="mask-type:alpha" maskUnits="userSpaceOnUse" '
            f'x="0" y="0" width="1000" height="1000"><path d="{tile}" fill="#FFFFFF"/></mask>'
        )
        return f'{HEAD}{mask}<g mask="url(#m)">{body}</g></svg>\n'

    OUT.mkdir(parents=True, exist_ok=True)
    (OUT / "mark-base.svg").write_text(f'{HEAD}<path d="{tile}" fill="{CREAM}"/></svg>\n')
    (OUT / "mark-glyph-dark.svg").write_text(glyph(GREY, GREY))
    (OUT / "mark-glyph-spark.svg").write_text(glyph(GREY, ORANGE))
    (OUT / "mark-glyph-lit.svg").write_text(glyph(ORANGE, ORANGE))

    # Native splash: the Dark state (base at 90%, grey glyph), mark 88 of a 240 tile, at 4x.
    inner = src.split(">", 1)[1].rsplit("</svg>", 1)[0]
    dark = inner.replace('fill="#F58028"', f'fill="{GREY}"').replace(
        f'<path d="M0 0H1000V1000H0V0Z" fill="{CREAM}"/>',
        f'<path d="M0 0H1000V1000H0V0Z" fill="{CREAM}" fill-opacity="0.9"/>',
    )

    def canvas(size: int, mark: int) -> bytes:
        scale = mark / 1000
        off = (size - mark) / 2
        return (
            f'<svg xmlns="http://www.w3.org/2000/svg" width="{size}" height="{size}" viewBox="0 0 {size} {size}">'
            f'<g transform="translate({off},{off}) scale({scale})">{dark}</g></svg>'
        ).encode()

    cairosvg.svg2png(bytestring=canvas(960, 352), write_to=str(OUT / "native-splash.png"))
    cairosvg.svg2png(bytestring=canvas(1152, 352), write_to=str(OUT / "native-splash-android12.png"))


if __name__ == "__main__":
    main()
