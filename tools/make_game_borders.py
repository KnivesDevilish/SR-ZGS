#!/usr/bin/env python3
"""Builds docs/borders: the pictures the launcher offers as 4:3 borders and the
runtime draws beside a 4:3 game on a wide screen, and their borders.txt
(format in external/ModernGekko/tools/game_borders.hpp).

A 4:3 game on a 16:9 screen leaves a bar on each side, 240 x 1080 at
1920 x 1080. Each picture holds what both bars show, at that size:

  Sonic.png, Jet.png  480 x 1080: the left bar's picture on the left half and
      the right bar's on the right half. They come from the two artworks,
      which stay outside the repository: the left half shows the characters on
      the artwork's left; the right half the one on its right, under the
      artwork's logo, made smaller to fit and set on a dark header that hides
      the part of the logo that would be cut off. A bar is seldom exactly
      240 x 1080, so these are shown whole (fit = contain), as large as the bar
      allows, and the rest of the bar shows their backdrop:
  Sonic Backdrop.png, Jet Backdrop.png  240 x 540: the same halves, blurred
      and darkened, made from Sonic.png and Jet.png.
  Green Grid.png  480 x 1312: two walls of a green grid seen in perspective,
      with a neon line along the game's side; the cells slide up. Drawn here.
  Blue Grid.png  1920 x 1080: a blue sky and a green grid floor; the floor
      slides outward in both bars. Drawn here.

A grid slides by whole repeats of its cells, so each picture has grid to spare
around the part a bar shows, and borders.txt gives the size of the repeat,
which grows steadily toward the viewer. Both grids are drawn from that size,
so the numbers written match the pictures exactly.

Run from the repository root (needs Python 3, Pillow and NumPy):
    python3 tools/make_game_borders.py [--sonic ARTWORK] [--jet ARTWORK]
The grids, the backdrops and borders.txt are always written; Sonic.png and
Jet.png only from the artworks given (1195 x 896, the logo at the top right;
the columns and boxes below are in their pixels), otherwise the ones already
in docs/borders are kept and the backdrops made from them.
"""

import argparse
import pathlib
import random
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

OUTPUT = pathlib.Path("docs/borders")
BAR_WIDTH = 240
BAR_HEIGHT = 1080
# The grids are drawn this many times larger and then reduced, which smooths
# their lines.
SUPERSAMPLE = 3

# ---------------------------------------------------------------- artworks

# Per artwork: the column the left half is centred on, the column the right
# half is centred on, and the box around the logo (x0, y0, x1, y1).
ARTWORKS = {
    "sonic": ("Sonic.png", 280, 905, (916, 0, 1195, 158)),
    "jet": ("Jet.png", 210, 1000, (916, 0, 1195, 160)),
}
LOGO_WIDTH = 228
LOGO_TOP = 14
# The header is solid down to this row of the bar, then fades out by FADE_END.
HEADER_END = 190
FADE_END = 260


def artwork_bar(artwork, centre):
    """The 240 x 1080 window of the artwork centred on a column, the artwork
    scaled to the bar's height."""
    scale = BAR_HEIGHT / artwork.height
    half = BAR_WIDTH / scale / 2
    box = (centre - half, 0, centre + half, artwork.height)
    return artwork.transform((BAR_WIDTH, BAR_HEIGHT), Image.Transform.EXTENT, box,
                             Image.Resampling.BICUBIC)


def with_logo(picture, artwork, logo_box):
    # The header takes the colour of the picture's top: the artwork's own dark
    # background, whatever bright logo is in it.
    top = np.asarray(picture.crop((0, 0, BAR_WIDTH, HEADER_END))).reshape(-1, 3)
    darkest_first = top[np.argsort(top.sum(axis=1), kind="stable")]
    header_colour = tuple(int(v) for v in darkest_first[len(darkest_first) // 4])
    header = Image.new("RGB", picture.size, header_colour)
    mask = Image.new("L", picture.size, 0)
    draw = ImageDraw.Draw(mask)
    for y in range(FADE_END):
        opacity = 1.0 if y < HEADER_END else (FADE_END - y) / (FADE_END - HEADER_END)
        draw.line((0, y, BAR_WIDTH, y), fill=round(255 * opacity))
    picture = Image.composite(header, picture, mask)

    logo = artwork.crop(logo_box)
    logo = logo.resize((LOGO_WIDTH, round(logo.height * LOGO_WIDTH / logo.width)),
                       Image.Resampling.LANCZOS)
    edge = Image.new("L", logo.size, 0)
    ImageDraw.Draw(edge).rectangle((8, 8, logo.width - 9, logo.height - 9), fill=255)
    picture.paste(logo, ((BAR_WIDTH - LOGO_WIDTH) // 2, LOGO_TOP),
                  edge.filter(ImageFilter.GaussianBlur(4)))
    return picture


def make_artwork_border(key, path):
    name, left_centre, right_centre, logo_box = ARTWORKS[key]
    artwork = Image.open(path).convert("RGB")
    border = Image.new("RGB", (BAR_WIDTH * 2, BAR_HEIGHT))
    border.paste(artwork_bar(artwork, left_centre), (0, 0))
    border.paste(with_logo(artwork_bar(artwork, right_centre), artwork, logo_box), (BAR_WIDTH, 0))
    return name, border


# The backdrop: each half at half size, blurred on its own (so the halves
# don't bleed into each other) and darkened, so the sharp picture in front
# stands out from it.
BACKDROP_BLUR = 10
BACKDROP_LIGHT = 0.42


def backdrop_name(name):
    return name.replace(".png", " Backdrop.png")


def make_backdrop(border):
    half_width, half_height = BAR_WIDTH // 2, BAR_HEIGHT // 2
    backdrop = Image.new("RGB", (half_width * 2, half_height))
    for i in range(2):
        half = border.crop((i * BAR_WIDTH, 0, (i + 1) * BAR_WIDTH, BAR_HEIGHT))
        half = half.resize((half_width, half_height), Image.Resampling.LANCZOS)
        # Blurred with its edges repeated around it, so they don't darken.
        padded = Image.new("RGB", (half_width + 8 * BACKDROP_BLUR, half_height + 8 * BACKDROP_BLUR))
        padded.paste(half.resize(padded.size, Image.Resampling.BILINEAR), (0, 0))
        padded.paste(half, (4 * BACKDROP_BLUR, 4 * BACKDROP_BLUR))
        padded = padded.filter(ImageFilter.GaussianBlur(BACKDROP_BLUR))
        half = padded.crop((4 * BACKDROP_BLUR, 4 * BACKDROP_BLUR,
                            4 * BACKDROP_BLUR + half_width, 4 * BACKDROP_BLUR + half_height))
        half = Image.eval(half, lambda v: round(v * BACKDROP_LIGHT))
        backdrop.paste(half, (i * half_width, 0))
    return backdrop


# ------------------------------------------------------------------ grids

def gradient(stops, length):
    """Colours along length pixels through (position, (r, g, b)) stops."""
    positions = [p for p, _ in stops]
    colours = np.array([c for _, c in stops], dtype=float)
    at = np.arange(length) + 0.5
    return np.stack([np.interp(at, positions, colours[:, i]) for i in range(3)], axis=1)


def add_glow(base, layer, radius, strength):
    """Adds a blurred copy of layer (an RGB image of light on black) to base."""
    glow = np.asarray(layer.filter(ImageFilter.GaussianBlur(radius)), dtype=float)
    return base + glow * strength


def finish(canvas):
    """The supersampled float canvas, reduced to the picture."""
    canvas = np.clip(canvas, 0, 255).astype(np.uint8)
    image = Image.fromarray(canvas)
    return image.resize((image.width // SUPERSAMPLE, image.height // SUPERSAMPLE),
                        Image.Resampling.LANCZOS)


# Green grid: one wall per bar, the neon line on the game's side. On the left
# wall, column x (from the bar's outer edge, 0 to 240) repeats every
# GREEN_REPEAT - GREEN_SHRINK * x pixels: the wall goes away from the viewer
# toward the game, so its cells get smaller.
GREEN_REPEAT = 113.8
GREEN_SHRINK = 13.7 / BAR_WIDTH
# Grid to spare above and below the part shown: more than the largest repeat.
GREEN_MARGIN = 116
GREEN_HEIGHT = BAR_HEIGHT + 2 * GREEN_MARGIN
GREEN_BACKGROUND = [(0, (24, 46, 0)), (BAR_WIDTH * 0.85, (33, 62, 0)), (BAR_WIDTH, (40, 72, 0))]
GREEN_LINE = (80, 112, 0)
GREEN_NEON = (253, 255, 16)
GREEN_NEON_GLOW = (150, 210, 0)
# The neon line's core, in the bar's columns.
GREEN_NEON_LEFT = 227.5
GREEN_NEON_RIGHT = 237.5


def green_wall():
    """The left bar's wall; the right bar's is its mirror image."""
    s = SUPERSAMPLE
    width, height = BAR_WIDTH * s, GREEN_HEIGHT * s
    across = gradient([(p * s, c) for p, c in GREEN_BACKGROUND], width)
    down = 0.88 + 0.12 * np.sin(np.pi * (np.arange(height) + 0.5) / height)
    canvas = across[None, :, :] * down[:, None, None]

    lines = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(lines)
    centre = GREEN_HEIGHT / 2
    repeat_at = lambda x: GREEN_REPEAT - GREEN_SHRINK * x
    # Lines along the wall: rays toward the vanishing point past the game,
    # half a repeat off the middle.
    for n in range(-12, 12):
        k = n + 0.5
        start = (0, (centre + k * repeat_at(0)) * s)
        end = (BAR_WIDTH * s, (centre + k * repeat_at(BAR_WIDTH)) * s)
        draw.line([start, end], fill=GREEN_LINE, width=round(1.7 * s))
    # Lines across the wall, closer together toward the vanishing point.
    vanishing = GREEN_REPEAT / GREEN_SHRINK
    for j in range(4):
        x = vanishing - vanishing / (1 + (j + 0.45) * 0.0505)
        if x < GREEN_NEON_LEFT - 8:
            draw.line([(x * s, 0), (x * s, height)], fill=GREEN_LINE, width=round(1.7 * s))
    canvas = canvas + np.asarray(lines, dtype=float) * 0.85
    canvas = add_glow(canvas, lines, 2 * s, 0.3)

    neon = Image.new("RGB", (width, height))
    ImageDraw.Draw(neon).rectangle(
        (GREEN_NEON_LEFT * s, 0, GREEN_NEON_RIGHT * s, height), fill=GREEN_NEON_GLOW)
    canvas = add_glow(canvas, neon, 4 * s, 1.0)
    canvas = add_glow(canvas, neon, 14 * s, 0.5)
    core = np.zeros((height, width), dtype=float)
    core[:, round(GREEN_NEON_LEFT * s):round(GREEN_NEON_RIGHT * s)] = 1.0
    canvas = canvas * (1 - core[:, :, None]) + np.array(GREEN_NEON) * core[:, :, None]
    return finish(canvas)


def make_green_grid():
    wall = green_wall()
    picture = Image.new("RGB", (BAR_WIDTH * 2, GREEN_HEIGHT))
    picture.paste(wall, (0, 0))
    picture.paste(wall.transpose(Image.Transpose.FLIP_LEFT_RIGHT), (BAR_WIDTH, 0))
    width = BAR_WIDTH * 2
    # Column i of the right half is column width - i of the left wall, so it
    # repeats every GREEN_REPEAT - GREEN_SHRINK * (width - i).
    entry = {
        "left": f"0 {GREEN_MARGIN} {BAR_WIDTH} {GREEN_MARGIN + BAR_HEIGHT}",
        "right": f"{BAR_WIDTH} {GREEN_MARGIN} {width} {GREEN_MARGIN + BAR_HEIGHT}",
        "left_motion": f"up 0 {BAR_WIDTH - 1} {GREEN_REPEAT:.4f} {-GREEN_SHRINK:.6f}",
        "right_motion": f"up {BAR_WIDTH} {width - 1} "
                        f"{GREEN_REPEAT - GREEN_SHRINK * width:.4f} {GREEN_SHRINK:.6f}",
    }
    return picture, entry


# Blue grid: a sky over a grid floor, 1920 x 1080. The floor's lines run toward
# BLUE_VANISHING; row y of the floor repeats every BLUE_SPREAD * (y -
# BLUE_VANISHING[1]) pixels. Each bar shows a 240-pixel slice: the left one
# BLUE_SLICE pixels left of the middle, the right one as far right, with
# enough floor beside them for the largest repeat.
BLUE_WIDTH = 1920
BLUE_HEIGHT = 1080
BLUE_VANISHING = (960.0, 540.0)
BLUE_SPREAD = 0.88
BLUE_HORIZON = 706
BLUE_SLICE = 240
BLUE_SKY = [(0, (0, 3, 5)), (190, (0, 40, 42)), (380, (0, 52, 58)), (560, (0, 40, 64)),
            (640, (0, 110, 170)), (672, (0, 108, 245)), (690, (48, 150, 255)),
            (700, (90, 200, 255)), (BLUE_HORIZON, (130, 255, 235))]
BLUE_FLOOR = [(BLUE_HORIZON, (0, 190, 95)), (BLUE_HORIZON + 30, (0, 82, 68)),
              (900, (0, 56, 60)), (BLUE_HEIGHT, (0, 62, 66))]
BLUE_LINE = (58, 255, 147)


def make_blue_grid():
    s = SUPERSAMPLE
    width, height = BLUE_WIDTH * s, BLUE_HEIGHT * s
    sky = gradient([(p * s, c) for p, c in BLUE_SKY + BLUE_FLOOR], height)
    canvas = np.repeat(sky[:, None, :], width, axis=1)

    # The sky: faint scanlines, a faint grid and a few stars.
    sky_lines = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(sky_lines)
    for y in range(4, BLUE_HORIZON - 6, 6):
        fade = (y / BLUE_HORIZON) ** 1.5
        draw.line([(0, y * s), (width, y * s)], fill=(0, round(64 * fade), round(70 * fade)),
                  width=s)
    for x in range(round(BLUE_VANISHING[0]) % 166, BLUE_WIDTH, 166):
        draw.line([(x * s, 40 * s), (x * s, (BLUE_HORIZON - 30) * s)], fill=(0, 52, 52),
                  width=round(1.5 * s))
    for y in range(120, BLUE_HORIZON - 40, 166):
        draw.line([(0, y * s), (width, y * s)], fill=(0, 52, 52), width=round(1.5 * s))
    stars = random.Random(20261106)
    for _ in range(140):
        x, y = stars.uniform(0, BLUE_WIDTH), stars.uniform(10, BLUE_HORIZON - 60)
        r = stars.choice((0.8, 1.0, 1.3))
        light = stars.choice(((0, 124, 170), (90, 200, 230), (160, 230, 255)))
        draw.ellipse(((x - r) * s, (y - r) * s, (x + r) * s, (y + r) * s), fill=light)
    canvas = canvas + np.asarray(sky_lines, dtype=float)

    # The floor: lines toward the vanishing point, thicker nearer the viewer,
    # and lines across it at even steps of depth.
    floor = Image.new("RGB", (width, height))
    draw = ImageDraw.Draw(floor)
    vx, vy = BLUE_VANISHING
    for n in range(-24, 25):
        top = (vx + n * BLUE_SPREAD * (BLUE_HORIZON - vy), BLUE_HORIZON)
        bottom = (vx + n * BLUE_SPREAD * (BLUE_HEIGHT - vy), BLUE_HEIGHT)
        steps = 24
        for i in range(steps):
            a, b = i / steps, (i + 1) / steps
            p0 = (top[0] + (bottom[0] - top[0]) * a, top[1] + (bottom[1] - top[1]) * a)
            p1 = (top[0] + (bottom[0] - top[0]) * b, top[1] + (bottom[1] - top[1]) * b)
            thickness = 1.5 + 6.0 * a
            draw.line([(p0[0] * s, p0[1] * s), (p1[0] * s, p1[1] * s)], fill=BLUE_LINE,
                      width=max(1, round(thickness * s)))
    for m in range(1, 12):
        y = vy + (BLUE_HORIZON - vy) * 1.0 / (1.0 - m * 0.12)
        if y >= BLUE_HEIGHT:
            break
        thickness = 1.0 + 2.5 * (y - BLUE_HORIZON) / (BLUE_HEIGHT - BLUE_HORIZON)
        draw.line([(0, y * s), (width, y * s)], fill=(10, 150, 95),
                  width=max(1, round(thickness * s)))
    # The lines cover the floor under them (adding them would tint them with
    # the floor's blue), and glow a little.
    cover = np.asarray(floor.convert("L"), dtype=float)[:, :, None] / 255.0
    cover = np.clip(cover * 1.6, 0.0, 1.0)
    canvas = canvas * (1 - cover) + np.asarray(floor, dtype=float) * cover
    canvas = add_glow(canvas, floor, 3 * s, 0.45)

    # The horizon: a bright line with a glow above and below.
    horizon = Image.new("RGB", (width, height))
    ImageDraw.Draw(horizon).rectangle((0, (BLUE_HORIZON - 2) * s, width, (BLUE_HORIZON + 2) * s),
                                      fill=(110, 255, 220))
    canvas = add_glow(canvas, horizon, 5 * s, 0.8)
    canvas = add_glow(canvas, horizon, 26 * s, 0.6)
    canvas[(BLUE_HORIZON - 2) * s:(BLUE_HORIZON + 2) * s, :, :] = (150, 255, 225)
    picture = finish(canvas)

    left = BLUE_WIDTH / 2 - BLUE_SLICE - BAR_WIDTH
    right = BLUE_WIDTH / 2 + BLUE_SLICE
    spread_start = -BLUE_SPREAD * vy
    entry = {
        "left": f"{left:g} 0 {left + BAR_WIDTH:g} {BLUE_HEIGHT}",
        "right": f"{right:g} 0 {right + BAR_WIDTH:g} {BLUE_HEIGHT}",
        "left_motion": f"left {BLUE_HORIZON} {BLUE_HEIGHT - 1} {spread_start:.4f} {BLUE_SPREAD:.6f}",
        "right_motion": f"right {BLUE_HORIZON} {BLUE_HEIGHT - 1} {spread_start:.4f} "
                        f"{BLUE_SPREAD:.6f}",
    }
    return picture, entry


# ------------------------------------------------------------- borders.txt

BORDERS = [
    ("sonic", "Sonic.png", {"": "Sonic, Knuckles & Tails", "es": "Sonic, Knuckles y Tails",
                            "ja": "ソニック、ナックルズ、テイルス"}),
    ("jet", "Jet.png", {"": "Jet, Wave & Storm", "es": "Jet, Wave y Storm",
                        "ja": "ジェット、ウェーブ、ストーム"}),
    ("green-grid", "Green Grid.png", {"": "Green grid", "es": "Grid verde",
                                      "ja": "緑のグリッド"}),
    ("blue-grid", "Blue Grid.png", {"": "Blue grid", "es": "Grid azul", "ja": "青のグリッド"}),
]


def borders_text(grids):
    lines = [
        "# The 4:3 borders: the pictures beside a 4:3 game on a wide screen, in the",
        "# order the launcher lists them. Written by tools/make_game_borders.py, which",
        "# also draws the two grids; the format is in",
        "# external/ModernGekko/tools/game_borders.hpp.",
    ]
    for border_id, picture, names in BORDERS:
        lines += ["", f"[{border_id}]"]
        for language, name in names.items():
            lines.append(f"name{'.' + language if language else ''} = {name}")
        if border_id in grids:
            entry = grids[border_id]
            lines += [f"left = {picture} {entry['left']}", f"right = {picture} {entry['right']}",
                      f"left_motion = {entry['left_motion']}",
                      f"right_motion = {entry['right_motion']}"]
        else:
            # The halves of a 480 x 1080 picture, shown whole, and the halves
            # of its 240 x 540 backdrop.
            backdrop = backdrop_name(picture)
            half_width, half_height = BAR_WIDTH // 2, BAR_HEIGHT // 2
            lines += [f"left = {picture} 0 0 {BAR_WIDTH} {BAR_HEIGHT}",
                      f"right = {picture} {BAR_WIDTH} 0 {BAR_WIDTH * 2} {BAR_HEIGHT}",
                      "fit = contain",
                      f"left_backdrop = {backdrop} 0 0 {half_width} {half_height}",
                      f"right_backdrop = {backdrop} {half_width} 0 {half_width * 2} {half_height}"]
    return "\n".join(lines) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--sonic", help="the artwork with Sonic, Knuckles and Tails")
    parser.add_argument("--jet", help="the artwork with Jet, Wave and Storm")
    arguments = parser.parse_args()
    OUTPUT.mkdir(parents=True, exist_ok=True)

    for key in ("sonic", "jet"):
        path = getattr(arguments, key)
        name = ARTWORKS[key][0]
        if path:
            name, picture = make_artwork_border(key, path)
            picture.save(OUTPUT / name, optimize=True)
            print(f"{OUTPUT / name}: {picture.width} x {picture.height}")
        elif (OUTPUT / name).exists():
            picture = Image.open(OUTPUT / name).convert("RGB")
        else:
            sys.exit(f"{OUTPUT / name} is missing: give its artwork with --{key}")
        backdrop = make_backdrop(picture)
        backdrop.save(OUTPUT / backdrop_name(name), optimize=True)
        print(f"{OUTPUT / backdrop_name(name)}: {backdrop.width} x {backdrop.height}")
    grids = {}
    for border_id, make in (("green-grid", make_green_grid), ("blue-grid", make_blue_grid)):
        picture, grids[border_id] = make()
        name = next(file for key, file, _ in BORDERS if key == border_id)
        picture.save(OUTPUT / name, optimize=True)
        print(f"{OUTPUT / name}: {picture.width} x {picture.height}")
    (OUTPUT / "borders.txt").write_text(borders_text(grids), encoding="utf-8", newline="\n")
    print(f"{OUTPUT / 'borders.txt'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
