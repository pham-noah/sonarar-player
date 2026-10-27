"""Draw PersonaR's EQUALIZER-P logo and every launcher/splash asset — no external art, no icon package.

This is the sibling of `make_brand.py` (the teal/blue P with the gold play triangle). That script is untouched and
keeps drawing the old mark; this one draws the new one into the SAME files. Run whichever brand you want shipped.

THE MARK. An aurora-blue squircle tile with four white rounded bars forming a P — a tall stem, then three bars that
trace the bowl, like an equalizer. The geometry below is the logo's own 100-unit grid, copied from the SVG, so the
PNGs here are the same drawing as `personar-logo.svg` and cannot drift from it.

ONE RULE, EVERY ASSET: THE BARS ARE ALWAYS 60% OF THE TILE THEY SIT ON. What differs per asset is only how big
that tile is on the canvas:

    legacy launcher icon     tile = 100% of canvas       the tile IS the icon
    adaptive foreground      tile = 72/108 = 66.7%       the platform only guarantees the central 72dp of the
                                                         108dp canvas; the platform draws the tile (the
                                                         background) and the mask, we draw only the bars
    system splash / boot     tile = 52%                  see below

WHY 52% FOR THE SPLASH. Android 12+ masks the splash icon to a CIRCLE about two-thirds of the canvas wide. Our tile
is a rounded square (corner radius 24% of its side), whose farthest point from the centre is 0.608 x its side. That
has to stay inside the circle's radius of 0.333 canvas, so the side can be at most 0.55 of the canvas. 0.52 leaves
a margin. The Flutter boot screen draws `logo_mark.png` into the same 132dp box, so the logo is the same size on
both sides of the handover.

WHY THE ADAPTIVE BARS CLEAR THE CIRCLE. At 66.7% of the canvas the tile's visible area is 72dp, and the bars'
farthest corner is 42.4 units from the tile centre against a circle radius of 50 units, so they fit.

ADAPTIVE BACKGROUND. The adaptive icon's background is now a gradient, so this script also writes
`mipmap-*/ic_launcher_bg.png` (108dp). Point the adaptive icon at it, replacing the old colour:

    <adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
        <background android:drawable="@mipmap/ic_launcher_bg"/>
        <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    </adaptive-icon>

SPLASH BACKGROUND. The splash and boot screens draw the tile on a dark field. The tile is blue, so use a dark navy
(`#0B1226` suits it); the old `#04080F` also works.

Palette (the logo's own):
    deep blue  #1F4FFF   top-left of the aurora ramp
    cyan       #2BB0F7   bottom-right of the aurora ramp
    white      #FFFFFF   the bars

Outputs (relative to the Flutter project root):
    assets/brand/logo_mark.png                                    the boot screen's asset
    android/.../mipmap-*/ic_launcher.png                          legacy icon, per density
    android/.../mipmap-*/ic_launcher_foreground.png               adaptive foreground (bars only)
    android/.../mipmap-*/ic_launcher_bg.png                       adaptive background (aurora gradient)
    android/.../drawable-*/splash_logo.png                        system splash + pre-31 launch
"""
from __future__ import annotations

import os
from PIL import Image, ImageDraw, ImageOps

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

BLUE = (0x1F, 0x4F, 0xFF)
CYAN = (0x2B, 0xB0, 0xF7)
WHITE = (255, 255, 255, 255)

_BARS = ((24, 20, 11, 60), (39, 20, 11, 36), (54, 20, 11, 42), (69, 26, 11, 28))

LEGACY_TILE_FRAC = 1.0

def _ramp(px: int) -> Image.Image:
    """The aurora gradient, deep blue at the top-left to cyan at the bottom-right, as an RGBA square."""

    return ImageOps.colorize(diag, BLUE, CYAN).convert("RGBA")

def _layer(canvas_px: int, tile_frac: float, *, tile: bool, bars: bool) -> Image.Image:
    """THE ONLY FUNCTION THAT SIZES THE LOGO: a tile of `tile_frac` of the canvas, centred, with the bars on it.

    `tile=False` draws the bars alone at the position they would have on the tile, for the adaptive foreground,
    where the platform supplies the tile.
    """
    n = canvas_px * SS
    side = round(n * tile_frac)
    x0 = y0 = (n - side) // 2
    out = Image.new("RGBA", (n, n), (0, 0, 0, 0))
    if tile:
        mask = Image.new("L", (side, side), 0)
        ImageDraw.Draw(mask).rounded_rectangle(
            [0, 0, side - 1, side - 1], radius=side * _TILE_RADIUS, fill=255,
        )
        out.paste(_ramp(side), (x0, y0), mask)
    if bars:
        d = ImageDraw.Draw(out)
        u = side / 100
        for bx, by, bw, bh in _BARS:
            d.rounded_rectangle(
                [x0 + bx * u, y0 + by * u, x0 + (bx + bw) * u, y0 + (by + bh) * u],
                radius=_BAR_RADIUS * u, fill=WHITE,
            )
    return out.resize((canvas_px, canvas_px), Image.LANCZOS)

def main() -> None:
    res = os.path.join(ROOT, "android/app/src/main/res")
    brand = os.path.join(ROOT, "assets/brand")
    os.makedirs(brand, exist_ok=True)

    def save(img: Image.Image, path: str, label: str, note: str) -> None:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        img.save(path)
        print(f"{label:9}{os.path.relpath(path, ROOT):56} {note}")

    for name, px in (("mdpi", 48), ("hdpi", 72), ("xhdpi", 96), ("xxhdpi", 144), ("xxxhdpi", 192)):
        save(_layer(px, LEGACY_TILE_FRAC, tile=True, bars=True),
             os.path.join(res, f"mipmap-{name}", "ic_launcher.png"), "icon", f"{px}x{px}")

    for name, px in (("mdpi", 108), ("hdpi", 162), ("xhdpi", 216), ("xxhdpi", 324), ("xxxhdpi", 432)):
        save(_layer(px, ADAPTIVE_TILE_FRAC, tile=False, bars=True),
             os.path.join(res, f"mipmap-{name}", "ic_launcher_foreground.png"), "adaptive", f"{px}x{px}")
        save(_ramp(px), os.path.join(res, f"mipmap-{name}", "ic_launcher_bg.png"), "adaptive", f"{px}x{px} background")

    for name, scale in (("mdpi", 1), ("hdpi", 1.5), ("xhdpi", 2), ("xxhdpi", 3), ("xxxhdpi", 4)):
        px = round(132 * scale)
        save(_layer(px, SPLASH_TILE_FRAC, tile=True, bars=True),
             os.path.join(res, f"drawable-{name}", "splash_logo.png"), "splash", f"{px}x{px} = 132dp")

    save(_layer(264, SPLASH_TILE_FRAC, tile=True, bars=True),
         os.path.join(brand, "logo_mark.png"), "mark", "264x264")

if __name__ == "__main__":
    main()