"""Cuts the static Bricolage Grotesque instances the Mob ramp needs.

Figma sets variable fonts at an automatic optical size (opsz equal to the font
size), so each Bricolage Mob style gets an instance at its own size and weight,
read from design/tokens.json. Run from the repo root with the Google Fonts file:

    python3 tool/gen_fonts.py "BricolageGrotesque[opsz,wdth,wght].ttf"

then list any new instance in pubspec.yaml and run tool/gen_tokens.dart.
"""

import json
import sys

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

WEIGHTS = {'Medium': 500, 'SemiBold': 600, 'Bold': 700, 'ExtraBold': 800}


def rename(font, family, style):
    names = font['name']
    for record in list(names.names):
        if record.nameID in (16, 17, 21, 22, 25):
            names.removeNames(nameID=record.nameID)
    full = f'{family} {style}'
    for name_id, value in {
        1: family,
        2: 'Regular',
        4: full,
        6: full.replace(' ', ''),
        16: family,
        17: style,
    }.items():
        names.setName(value, name_id, 3, 1, 0x409)


def main(variable_font):
    styles = json.load(open('design/tokens.json'))['textStyles']
    cuts = sorted({
        (int(s['fontSize']), WEIGHTS[s['fontStyle']])
        for s in styles
        if s['name'].startswith('Mob/') and s['fontFamily'] == 'Bricolage Grotesque'
    })
    style_names = {w: n for n, w in WEIGHTS.items()}
    for size, weight in cuts:
        font = instantiateVariableFont(
            TTFont(variable_font),
            {'opsz': size, 'wght': weight, 'wdth': 100},
        )
        font['OS/2'].usWeightClass = weight
        rename(font, f'Bricolage Grotesque {size}pt', style_names[weight])
        path = f'assets/fonts/BricolageGrotesque-{size}pt.ttf'
        font.save(path)
        print(path, weight)


if __name__ == '__main__':
    main(sys.argv[1])
