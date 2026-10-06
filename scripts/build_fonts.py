#!/usr/bin/env python3
"""Builds the static Fraunces instances bundled with Halo Day.

Usage: python3 -m venv /tmp/halo-fonts && /tmp/halo-fonts/bin/pip install fonttools
       /tmp/halo-fonts/bin/python scripts/build_fonts.py
Downloads the OFL variable fonts from google/fonts, pins the axes, renames the
families so they cannot collide with an installed Fraunces, and refuses to write
a font that lacks any Vietnamese glyph.
"""
import io, pathlib, sys, urllib.request
from fontTools.ttLib import TTFont
from fontTools.varLib import instancer

BASE = "https://raw.githubusercontent.com/google/fonts/main/ofl/fraunces/"
OUT = pathlib.Path(__file__).resolve().parent.parent / "Shared" / "Fonts"
VIETNAMESE = ("ĂăÂâĐđÊêÔôƠơƯư"
    "ẠạẢảẤấẦầẨẩẪẫẬậẮắẰằẲẳẴẵẶặẸẹẺẻẼẽẾếỀềỂểỄễỆệỈỉỊịỌọỎỏỐốỒồỔổỖỗỘộỚớỜờỞởỠỡỢợỤụỦủỨứỪừỬửỮữỰựỲỳỴỵỶỷỸỹ"
    "ÀàÁáÃãÈèÉéÌìÍíĨĩÒòÓóÕõÙùÚúŨũÝý")
INSTANCES = [
    ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"opsz": 72, "wght": 340, "SOFT": 100, "WONK": 0}, "Display", "Regular"),
    ("Fraunces[SOFT,WONK,opsz,wght].ttf", {"opsz": 24, "wght": 420, "SOFT": 50, "WONK": 0}, "Text", "Regular"),
    ("Fraunces-Italic[SOFT,WONK,opsz,wght].ttf", {"opsz": 24, "wght": 360, "SOFT": 100, "WONK": 0}, "Italic", "Italic"),
]

def fetch(name):
    url = BASE + urllib.request.quote(name)
    with urllib.request.urlopen(url) as response:
        return response.read()

def rename(font, flavour, style):
    family = f"Halo Fraunces {flavour}"
    postscript = f"HaloFraunces-{flavour}"
    table = font["name"]
    for name_id in (1, 2, 3, 4, 6, 16, 17, 21, 22, 25):
        table.removeNames(nameID=name_id)
    for name_id, value in ((1, family), (2, style), (3, f"{postscript};halo-day"), (4, f"{family} {style}"), (6, postscript)):
        table.setName(value, name_id, 3, 1, 0x409)
        table.setName(value, name_id, 1, 0, 0)

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cache = {}
    for source, axes, flavour, style in INSTANCES:
        if source not in cache:
            cache[source] = fetch(source)
        font = instancer.instantiateVariableFont(TTFont(io.BytesIO(cache[source])), axes)
        missing = [c for c in VIETNAMESE if ord(c) not in font.getBestCmap()]
        if missing:
            sys.exit(f"{flavour}: missing Vietnamese glyphs {''.join(missing)} — use the New York fallback instead")
        rename(font, flavour, style)
        font.save(OUT / f"HaloFraunces-{flavour}.ttf")
        print("wrote", OUT / f"HaloFraunces-{flavour}.ttf")
    (OUT / "OFL.txt").write_bytes(fetch("OFL.txt"))

if __name__ == "__main__":
    main()
