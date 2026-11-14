#!/usr/bin/env python3
"""SR-Source: builds the Netplay lobby's background in layers (docs/lobby/)
from the banner's art: the backdrop (the light grey of SR-Source Artwork
Dev.png with the checkered flag of banner/background.png, which waves) and
the icon (cut out of SR-Source Artwork Dev.png, which floats), without the
text. 1920x1080, as the lobby window (16:9); the lobby's card takes the right
part, so the icon stays on the left, under the lobby's title (NETPLAY, which
the lobby writes over the background itself).

    python3 tools/make_lobby_layers.py            (from the repository root)

Needs Pillow and NumPy (pip install pillow numpy). Change FLAG_SCALE,
ICON_SCALE, ICON_MIDDLE or ICON_TOP below, run it, and build again.
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

W, H = 1920, 1080
BG = 220  # SR-Source Artwork Dev's grey, #DCDCDC
FLAG_SCALE = 1.5
ICON_SCALE = 1.2
# The lobby (ModernGekko's tools/netplay_lobby_ui.hpp, DrawLobby) leaves the
# left 40% of the window clear, inside its margins, and centres its title at
# the top of it: x 28 to 486 of 1200, the middle at 411 of 1920. The icon goes
# under the title, its middle there too.
ICON_MIDDLE = 411
ICON_TOP = 185


def color_to_alpha(rgb, bg):
    """GIMP's color to alpha against a grey: the least opaque colour that,
    over bg, gives the same pixel."""
    rgb = rgb.astype(np.float64)
    up = np.where(rgb > bg, (rgb - bg) / (255.0 - bg), 0.0)
    down = np.where(rgb < bg, (bg - rgb) / bg, 0.0)
    alpha = np.clip(np.maximum(up, down).max(axis=2), 0.0, 1.0)
    safe = np.where(alpha > 0, alpha, 1.0)[..., None]
    colour = np.clip((rgb - bg) / safe + bg, 0, 255)
    return np.dstack([colour, alpha * 255]).round().astype(np.uint8)


def main(repo, out):
    repo, out = Path(repo), Path(out)
    out.mkdir(parents=True, exist_ok=True)
    # The flag: the banner's backdrop is the same flag, white on #232323; as
    # black with its own transparency, it goes on the light grey.
    banner = np.array(Image.open(repo / "docs/banner/background.png").convert("L")).astype(np.float64)
    flag_alpha = np.clip((banner - 35.0) / (255.0 - 35.0), 0.0, 1.0)
    flag = np.zeros(banner.shape + (4,), np.uint8)
    flag[..., 3] = (flag_alpha * 255).round().astype(np.uint8)
    flag_image = Image.fromarray(flag, "RGBA")
    flag_image = flag_image.resize((round(flag_image.width * FLAG_SCALE),
                                    round(flag_image.height * FLAG_SCALE)), Image.LANCZOS)
    backdrop = Image.new("RGBA", (W, H), (BG, BG, BG, 255))
    # Its bottom right corner in the backdrop's, as in the banner.
    backdrop.alpha_composite(flag_image, (W - flag_image.width, H - flag_image.height))
    backdrop.save(out / "backdrop.png", optimize=True)

    # The icon, cut out of the light artwork.
    dev = np.array(Image.open(repo / "docs/SR-Source Artwork Dev.png").convert("RGB"))
    icon = color_to_alpha(dev[:, :545], BG)
    icon_image = Image.fromarray(icon, "RGBA")
    box = icon_image.getbbox()
    icon_image = icon_image.crop(box)
    icon_image = icon_image.resize((round(icon_image.width * ICON_SCALE),
                                    round(icon_image.height * ICON_SCALE)), Image.LANCZOS)
    # On the left, under the title, clear of the lobby's card (from about 42%
    # of the width).
    layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    left = ICON_MIDDLE - icon_image.width // 2
    top = ICON_TOP
    layer.alpha_composite(icon_image, (left, top))
    layer.save(out / "icon.png", optimize=True)
    (out / "layout.txt").write_text(
        "# The Netplay lobby's background in layers (ModernGekko's\n"
        "# tools/launcher_banner_layout.hpp): back to front, each picture 1920x1080.\n"
        "#   layer <picture> <depth> [wave|float]   depth: pixels it moves with the mouse\n"
        "# Made by tools/make_lobby_layers.py from SR-Source Artwork Dev.png and\n"
        "# banner/background.png.\n"
        "layer backdrop.png 10 wave\n"
        "layer icon.png 22 float\n", encoding="utf-8")
    print(f"lobby background: {out} (icon {icon_image.size[0]}x{icon_image.size[1]} at {left},{top})")


if __name__ == "__main__":
    root = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent
    main(root, Path(sys.argv[2]) if len(sys.argv) > 2 else root / "docs" / "lobby")
