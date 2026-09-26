#!/usr/bin/env python3
"""Create Still's original pixel-art sprite package.

Every pixel in these PNGs is generated from the geometry below.  The script is
kept with the source so the art can be audited and regenerated without a third-
party asset, model, or reference image.  The palette deliberately contains 32
colors shared by rooms, objects, and small UI illustrations.
"""
from __future__ import annotations

import json
import shutil
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "Still" / "Assets.xcassets"
SOURCES = ROOT / "Still" / "Resources" / "Sprites"

# Still's authored 32-color pixel palette. No sampled reference-app colors.
P = {
    "ink": "#4A2F33", "ink2": "#624556", "night": "#25294A", "night2": "#3A4165",
    "plum": "#6A5075", "lavender": "#A79ACF", "mist": "#D7D0EA", "paper": "#FFF5E8",
    "cream": "#F4E3CF", "peach": "#F4C8B4", "coral": "#D98272", "rust": "#AF5C54",
    "sun": "#FFD98A", "gold": "#DCA958", "wood": "#B87B59", "wooddark": "#85523F",
    "floor": "#D7A77D", "floordark": "#A8755C", "sage": "#86AA89", "leaf": "#4E7B62",
    "mint": "#B9DDC2", "sky": "#A9D5E7", "blue": "#7098C0", "rain": "#DCEEFF",
    "rose": "#DEA7B8", "pink": "#F3C5D6", "clay": "#C9795D", "snow": "#F6FBFC",
    "grey": "#99A1B4", "charcoal": "#50566D", "black": "#2B2630", "white": "#FFFFFF",
}

ROOMS = {
    "RainyBedroom": {"wall": P["plum"], "side": P["lavender"], "sky": P["night2"], "floor": P["floor"], "leaf": P["leaf"], "accent": P["rose"], "weather": "rain", "layout": "bedroom"},
    "LibraryLight": {"wall": P["wood"], "side": P["peach"], "sky": P["sun"], "floor": P["floor"], "leaf": P["sage"], "accent": P["blue"], "weather": "sun", "layout": "library"},
    "TrainWindow": {"wall": P["grey"], "side": P["mist"], "sky": P["sky"], "floor": P["floor"], "leaf": P["sage"], "accent": P["gold"], "weather": "hills", "layout": "train"},
    "NightCity": {"wall": P["plum"], "side": P["night2"], "sky": P["night"], "floor": P["floordark"], "leaf": P["leaf"], "accent": P["lavender"], "weather": "city", "layout": "city"},
    "AutumnWindow": {"wall": P["wooddark"], "side": P["wood"], "sky": P["coral"], "floor": P["floordark"], "leaf": P["gold"], "accent": P["sun"], "weather": "leaves", "layout": "bedroom"},
    "SnowDay": {"wall": P["blue"], "side": P["sky"], "sky": P["mist"], "floor": P["floordark"], "leaf": P["sage"], "accent": P["snow"], "weather": "snow", "layout": "bedroom"},
    "SpringRain": {"wall": P["sage"], "side": P["mint"], "sky": P["sky"], "floor": P["floor"], "leaf": P["leaf"], "accent": P["rose"], "weather": "sprout", "layout": "library"},
    "AlarmSleep": {"wall": P["night2"], "side": P["plum"], "sky": P["night"], "floor": P["floordark"], "leaf": P["leaf"], "accent": P["lavender"], "weather": "moon", "layout": "bedroom"},
}

OBJECTS = [
    "PencilCup", "DeskLamp", "WovenRug", "TrailingPlant", "Radio", "FloorCushion", "Telescope", "Candle", "Globe", "StringLights",
    "Bookends", "BookStack", "RecordPlayer", "ArtPoster", "PaperStars", "CeramicBird", "TinyClock", "WateringCan", "Pinboard", "CatBed",
]
BREAKS = ["Sudoku", "Picross", "WordSearch", "ShortRead", "Doodle", "Breathing", "Stretch", "BrainDump", "DoNothing", "Tea"]


def rgba(hex_value: str) -> tuple[int, int, int, int]:
    hex_value = hex_value.lstrip("#")
    return (int(hex_value[0:2], 16), int(hex_value[2:4], 16), int(hex_value[4:6], 16), 255)


def image(size: tuple[int, int], fill: str | tuple[int, int, int, int] = "#00000000") -> Image.Image:
    # Pillow needs a true alpha-zero tuple for transparent sprite canvases;
    # the six-digit palette helper deliberately returns opaque display colors.
    if isinstance(fill, str) and len(fill.lstrip("#")) == 8:
        value = fill.lstrip("#")
        resolved = (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), int(value[6:8], 16))
    else:
        resolved = rgba(fill) if isinstance(fill, str) else fill
    return Image.new("RGBA", size, resolved)


def rect(d: ImageDraw.ImageDraw, xy: tuple[int, int, int, int], color: str, outline: str | None = None) -> None:
    d.rectangle(xy, fill=rgba(color), outline=rgba(outline) if outline else None)


def px(d: ImageDraw.ImageDraw, x: int, y: int, color: str, w: int = 1, h: int = 1) -> None:
    rect(d, (x, y, x + w - 1, y + h - 1), color)


def line(d: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str, width: int = 1) -> None:
    d.line(points, fill=rgba(color), width=width)


def poly(d: ImageDraw.ImageDraw, points: list[tuple[int, int]], color: str, outline: str | None = None) -> None:
    d.polygon(points, fill=rgba(color))
    if outline:
        line(d, points + [points[0]], outline)


def room_sprite(name: str, cfg: dict[str, str]) -> Image.Image:
    """Author a single-point-perspective room, not a symbolic box.

    The old room base relied on one giant desktop and a broad translucent-looking
    plane. This construction deliberately gives every room three readable planes
    (back wall, side wall, floor), converging floorboards, furniture front/side
    faces, contact shadows, and a scene-specific focal layout.
    """
    im = image((160, 132))
    d = ImageDraw.Draw(im)
    # Perspective shell: all three planes meet at an intentional room corner.
    back = [(10, 10), (108, 10), (108, 76), (10, 76)]
    side = [(108, 10), (153, 31), (153, 98), (108, 76)]
    floor = [(10, 76), (108, 76), (153, 98), (52, 128)]
    poly(d, back, cfg["wall"], P["ink"])
    poly(d, side, cfg["side"], P["ink"])
    poly(d, floor, cfg["floor"], P["ink"])
    # Baseboards and converging floorboards make the floor read as depth, not a
    # detached parallelogram.
    line(d, [(11, 75), (108, 75), (152, 97)], P["wooddark"], 2)
    for x in (18, 39, 62, 85, 102):
        line(d, [(x, 77), (52 + (x - 10) // 2, 127)], P["floordark"])
    for points in ([(18, 84), (114, 84), (143, 98)], [(27, 95), (122, 95), (128, 101)], [(38, 108), (110, 108)]):
        line(d, points, P["floordark"])

    # A small dithered wall bounce, behind the lamp only, keeps the light in the
    # architecture. It never overlays the floor as a flat tan oval.
    for x, y, size, color in [(90, 44, 10, P["peach"]), (94, 48, 7, P["sun"]), (87, 52, 4, P["gold"]), (104, 53, 4, P["gold"]), (101, 40, 3, P["sun"])]:
        px(d, x, y, color, size, max(2, size // 2))

    def draw_window(frame: list[tuple[int, int]], inside: list[tuple[int, int]], divider: bool = True) -> None:
        poly(d, frame, P["ink"])
        poly(d, inside, cfg["sky"])
        if divider:
            x1, y1 = inside[0]; x2, y2 = inside[2]
            line(d, [((x1 + x2) // 2, y1), ((x1 + x2) // 2, y2)], P["ink"], 2)
            line(d, [(x1, (y1 + y2) // 2), (x2, (y1 + y2) // 2)], P["ink"], 2)

    weather = cfg["weather"]
    layout = cfg["layout"]

    if layout == "train":
        draw_window([(15, 18), (84, 18), (84, 58), (15, 58)], [(19, 22), (80, 22), (80, 54), (19, 54)], False)
        poly(d, [(19, 50), (33, 37), (50, 48), (67, 34), (80, 50), (80, 54), (19, 54)], P["sage"])
        poly(d, [(19, 53), (40, 42), (55, 52), (74, 43), (80, 53)], P["leaf"])
        # Rail-car seat: seat, front face, and backrest are distinct planes.
        poly(d, [(17, 69), (69, 72), (83, 83), (32, 82)], P["rose"], P["ink"])
        poly(d, [(32, 82), (83, 83), (83, 94), (32, 93)], P["coral"], P["ink"])
        poly(d, [(18, 53), (57, 55), (68, 73), (18, 69)], P["lavender"], P["ink"])
        poly(d, [(94, 64), (130, 70), (142, 76), (105, 72)], P["wood"], P["ink"])
        poly(d, [(105, 72), (142, 76), (142, 81), (105, 77)], P["wooddark"], P["ink"])
        rect(d, (112, 77, 117, 101), P["wooddark"], P["ink"])
        rect(d, (135, 80, 140, 96), P["wooddark"], P["ink"])
        poly(d, [(116, 31), (145, 44), (145, 47), (116, 34)], P["wooddark"], P["ink"])
        for x, c in [(120, P["blue"]), (126, P["gold"]), (132, P["rose"]), (138, cfg["accent"])]: rect(d, (x, 36, x + 3, 43), c, P["ink"])
    elif layout == "city":
        draw_window([(116, 28), (148, 43), (148, 76), (116, 63)], [(120, 33), (144, 45), (144, 71), (120, 61)], False)
        for x, y, h in [(122, 55, 13), (128, 49, 19), (134, 57, 12), (140, 51, 18)]:
            rect(d, (x, y, x + 3, y + h), P["night"], P["ink"])
            px(d, x + 1, y + 3, P["sun"], 1, 2)
        # Back-wall desk facing the skyline and a foreground chair establish a
        # different, deeper composition from the bedroom.
        poly(d, [(61, 67), (106, 71), (126, 79), (80, 76)], P["wood"], P["ink"])
        poly(d, [(80, 76), (126, 79), (126, 85), (80, 82)], P["wooddark"], P["ink"])
        rect(d, (84, 83, 90, 106), P["wooddark"], P["ink"])
        rect(d, (118, 84, 124, 99), P["wooddark"], P["ink"])
        poly(d, [(69, 91), (90, 94), (101, 103), (79, 101)], P["blue"], P["ink"])
        poly(d, [(79, 101), (101, 103), (101, 113), (79, 111)], P["charcoal"], P["ink"])
        rect(d, (26, 24, 39, 39), P["paper"], P["ink"])
        line(d, [(28, 30), (37, 30)], P["lavender"])
        line(d, [(28, 35), (36, 35)], P["rose"])
    elif layout == "library":
        draw_window([(18, 20), (53, 20), (53, 61), (18, 61)], [(22, 24), (49, 24), (49, 57), (22, 57)])
        for x, y in [(25, 28), (31, 31), (43, 28), (28, 47), (45, 46)]: px(d, x, y, P["sun"], 3, 3)
        # Tall back-wall shelving, a reading chair, and a compact writing table.
        rect(d, (62, 19, 99, 67), P["wooddark"], P["ink"])
        for y in (30, 42, 54): line(d, [(64, y), (97, y)], P["ink"], 2)
        for x, y, c in [(66, 23, P["blue"]), (72, 21, P["rose"]), (78, 24, P["gold"]), (85, 22, P["sage"]), (91, 23, cfg["accent"]), (67, 44, P["sun"]), (74, 45, P["blue"]), (81, 43, P["rose"]), (89, 45, P["mint"])]:
            rect(d, (x, y, x + 4, y + 7), c, P["ink"])
        poly(d, [(20, 78), (49, 80), (63, 90), (31, 91)], P["sage"], P["ink"])
        poly(d, [(31, 91), (63, 90), (63, 104), (31, 106)], P["leaf"], P["ink"])
        poly(d, [(100, 70), (126, 74), (139, 81), (111, 78)], P["wood"], P["ink"])
        poly(d, [(111, 78), (139, 81), (139, 86), (111, 83)], P["wooddark"], P["ink"])
        rect(d, (114, 84, 119, 103), P["wooddark"], P["ink"])
        rect(d, (133, 86, 138, 99), P["wooddark"], P["ink"])
        rect(d, (104, 53, 109, 70), P["ink"], P["ink"])
        poly(d, [(98, 53), (114, 53), (111, 60), (101, 60)], P["sun"], P["ink"])
    else:
        draw_window([(17, 18), (57, 18), (57, 60), (17, 60)], [(21, 22), (53, 22), (53, 56), (21, 56)])
        if weather == "rain":
            for x, y in [(24, 25), (31, 30), (48, 25), (43, 42), (27, 47), (50, 48)]: line(d, [(x, y), (x - 2, y + 5)], P["rain"])
        elif weather == "leaves":
            for x, y in [(25, 25), (34, 29), (48, 26), (29, 42), (44, 46)]: px(d, x, y, P["gold"], 3, 2)
        elif weather == "snow":
            for x, y in [(25, 24), (34, 30), (46, 25), (27, 44), (45, 47)]: px(d, x, y, P["snow"], 2, 2)
        elif weather == "moon":
            px(d, 39, 27, P["mist"], 8, 8)
            px(d, 43, 25, cfg["sky"], 6, 7)
        # Bed on the left: mattress top, front panel, headboard, pillow and
        # blanket are separate planes rather than one long flat rectangle.
        poly(d, [(14, 92), (57, 94), (77, 106), (34, 111)], P["floordark"])
        poly(d, [(16, 78), (54, 80), (69, 89), (31, 91)], P["paper"], P["ink"])
        poly(d, [(31, 91), (69, 89), (69, 100), (31, 103)], P["mint"], P["ink"])
        poly(d, [(15, 76), (29, 77), (29, 101), (15, 99)], P["wooddark"], P["ink"])
        poly(d, [(21, 81), (40, 82), (47, 86), (28, 87)], P["cream"], P["ink"])
        line(d, [(44, 82), (62, 90)], P["blue"], 2)
        # Desk on the right with distinct top/front planes, legs and a small lamp.
        poly(d, [(77, 66), (120, 70), (139, 78), (94, 75)], P["wood"], P["ink"])
        poly(d, [(94, 75), (139, 78), (139, 84), (94, 81)], P["wooddark"], P["ink"])
        rect(d, (98, 82, 104, 106), P["wooddark"], P["ink"])
        rect(d, (132, 84, 138, 101), P["wooddark"], P["ink"])
        rect(d, (113, 51, 118, 69), P["ink"], P["ink"])
        poly(d, [(107, 51), (124, 51), (121, 58), (110, 58)], P["sun"], P["ink"])
        # A plant sits in the back corner; its pot has a front face and shadow.
        poly(d, [(133, 57), (147, 59), (147, 69), (136, 68)], P["clay"], P["ink"])
        for x, y in [(135, 55), (141, 51), (146, 55), (138, 47), (145, 46)]: px(d, x, y, cfg["leaf"], 5, 6)

    # The shared calendar and side shelf deliberately remain predictable room
    # buttons, while each surrounding room layout is distinct.
    rect(d, (63, 22, 76, 38), P["paper"], P["ink"])
    line(d, [(65, 27), (74, 27)], P["rose"])
    line(d, [(65, 32), (72, 32)], P["lavender"])
    poly(d, [(116, 27), (149, 42), (149, 46), (116, 32)], P["wooddark"], P["ink"])
    for x, y, c in [(119, 20, P["blue"]), (126, 23, P["rose"]), (133, 26, P["gold"]), (140, 29, cfg["accent"])]:
        rect(d, (x, y, x + 4, y + 8), c, P["ink"])
    return im


def object_sprite(name: str) -> Image.Image:
    im = image((32, 32))
    d = ImageDraw.Draw(im)
    # Each object is deliberately recognisable at 32px and uses shared Still palette.
    if name == "PencilCup":
        rect(d, (12, 15, 21, 26), P["clay"], P["ink"])
        for x, c in [(12, P["gold"]), (16, P["blue"]), (20, P["rose"])]: line(d, [(x, 16), (x+1, 5)], c, 2)
    elif name == "DeskLamp":
        rect(d, (14, 16, 17, 27), P["wooddark"], P["ink"]); rect(d, (9, 26, 22, 28), P["wood"], P["ink"])
        d.polygon([(8, 10), (23, 10), (20, 16), (11, 16)], fill=rgba(P["sun"]), outline=rgba(P["ink"]))
    elif name == "WovenRug":
        d.polygon([(5, 15), (20, 9), (28, 16), (13, 24)], fill=rgba(P["rose"]), outline=rgba(P["ink"]))
        for x in range(9, 23, 4): line(d, [(x, 14), (x+7, 18)], P["paper"])
    elif name == "TrailingPlant":
        rect(d, (11, 20, 23, 26), P["clay"], P["ink"])
        for x, y in [(12, 14), (17, 9), (21, 14), (9, 10), (23, 7)]: px(d, x, y, P["leaf"], 6, 7)
    elif name == "Radio":
        rect(d, (6, 12, 26, 24), P["wood"], P["ink"]); rect(d, (9, 15, 16, 21), P["charcoal"], P["ink"]); px(d, 21, 16, P["sun"], 3, 3)
    elif name == "FloorCushion":
        d.ellipse((5, 12, 27, 24), fill=rgba(P["pink"]), outline=rgba(P["ink"])); line(d, [(7, 18), (24, 18)], P["paper"])
    elif name == "Telescope":
        line(d, [(6, 12), (22, 7)], P["charcoal"], 5); line(d, [(18, 12), (12, 27)], P["wooddark"], 2); line(d, [(18, 12), (25, 27)], P["wooddark"], 2)
    elif name == "Candle":
        rect(d, (12, 15, 20, 27), P["paper"], P["ink"]); d.polygon([(16, 5), (21, 14), (16, 17), (12, 14)], fill=rgba(P["sun"]), outline=rgba(P["ink"]))
    elif name == "Globe":
        d.ellipse((8, 5, 24, 21), fill=rgba(P["blue"]), outline=rgba(P["ink"])); line(d, [(16, 5), (16, 21)], P["mist"]); line(d, [(10, 14), (22, 14)], P["mist"]); rect(d, (13, 21, 19, 26), P["wooddark"], P["ink"])
    elif name == "StringLights":
        line(d, [(3, 10), (28, 13)], P["wooddark"])
        for x, y in [(7, 11), (13, 12), (19, 13), (25, 13)]: px(d, x, y, P["sun"], 3, 3)
    elif name == "Bookends":
        rect(d, (6, 11, 10, 26), P["blue"], P["ink"]); rect(d, (22, 11, 26, 26), P["blue"], P["ink"])
        for x, c in [(11, P["rose"]), (15, P["gold"]), (19, P["sage"])]: rect(d, (x, 14, x+3, 25), c, P["ink"])
    elif name == "BookStack":
        for y, c in [(19, P["blue"]), (15, P["rose"]), (11, P["gold"])]: rect(d, (7, y, 25, y+5), c, P["ink"])
    elif name == "RecordPlayer":
        rect(d, (5, 13, 27, 25), P["wood"], P["ink"]); d.ellipse((9, 15, 19, 23), fill=rgba(P["charcoal"]), outline=rgba(P["ink"])); line(d, [(21, 15), (24, 11)], P["ink"], 2)
    elif name == "ArtPoster":
        rect(d, (7, 4, 25, 27), P["wooddark"], P["ink"]); rect(d, (10, 7, 22, 24), P["pink"], P["ink"]); px(d, 13, 11, P["sun"], 6, 6); px(d, 16, 17, P["leaf"], 4, 4)
    elif name == "PaperStars":
        for x, y in [(8, 9), (18, 6), (21, 18), (11, 21)]:
            d.polygon([(x, y-3), (x+2, y), (x, y+3), (x-2, y)], fill=rgba(P["sun"]), outline=rgba(P["ink"]))
    elif name == "CeramicBird":
        d.ellipse((7, 13, 23, 23), fill=rgba(P["blue"]), outline=rgba(P["ink"])); d.polygon([(22, 16), (29, 19), (22, 21)], fill=rgba(P["gold"]), outline=rgba(P["ink"])); px(d, 13, 15, P["white"], 2, 2)
    elif name == "TinyClock":
        d.ellipse((7, 9, 25, 27), fill=rgba(P["paper"]), outline=rgba(P["ink"])); line(d, [(16, 18), (16, 12)], P["ink"], 2); line(d, [(16, 18), (21, 20)], P["ink"], 2)
    elif name == "WateringCan":
        rect(d, (8, 14, 22, 25), P["blue"], P["ink"]); line(d, [(22, 16), (29, 12)], P["blue"], 4); line(d, [(10, 14), (7, 9), (15, 8)], P["blue"], 2)
    elif name == "Pinboard":
        rect(d, (5, 5, 27, 27), P["wood"], P["ink"])
        for x, y, c in [(8, 9, P["paper"]), (17, 8, P["pink"]), (12, 17, P["mint"])]: rect(d, (x, y, x+7, y+6), c, P["ink"]); px(d, x+3, y, P["coral"], 2, 2)
    elif name == "CatBed":
        d.ellipse((4, 12, 28, 26), fill=rgba(P["rose"]), outline=rgba(P["ink"])); d.ellipse((9, 16, 23, 23), fill=rgba(P["paper"]), outline=rgba(P["ink"]))
    return im


def mini_icon(label: str) -> Image.Image:
    im = image((32, 32))
    d = ImageDraw.Draw(im)
    rect(d, (2, 2, 29, 29), P["lavender"], P["ink"])
    if label == "Sudoku":
        for y in range(3):
            for x in range(3): rect(d, (7+x*6, 7+y*6, 11+x*6, 11+y*6), P["paper"] if (x+y)%2 else P["mist"], P["ink"])
    elif label == "Picross":
        for y in range(4):
            for x in range(4):
                if (x+y) % 3 == 0: rect(d, (5+x*5, 5+y*5, 8+x*5, 8+y*5), P["ink"])
    elif label == "WordSearch":
        for y, word in enumerate(["CALM", "TEA", "REST"]):
            for x, _ in enumerate(word): px(d, 5+x*5, 7+y*6, P["paper"], 3, 3)
    elif label == "ShortRead":
        rect(d, (8, 5, 24, 27), P["paper"], P["ink"]); line(d, [(12, 10), (21, 10)], P["blue"]); line(d, [(12, 15), (21, 15)], P["rose"]); line(d, [(12, 20), (19, 20)], P["sage"])
    elif label == "Doodle":
        line(d, [(7, 23), (14, 11), (22, 8), (25, 16)], P["paper"], 3); px(d, 7, 23, P["gold"], 4, 4)
    elif label == "Breathing":
        for inset, c in [(4, P["paper"]), (9, P["sky"]), (14, P["lavender"])]: d.rectangle((inset, inset, 31-inset, 31-inset), outline=rgba(c), width=2)
    elif label == "Stretch":
        line(d, [(16, 7), (16, 18), (9, 25)], P["paper"], 3); line(d, [(16, 16), (24, 11)], P["paper"], 3); d.ellipse((13, 3, 19, 9), fill=rgba(P["gold"]), outline=rgba(P["ink"]))
    elif label == "BrainDump":
        rect(d, (7, 5, 24, 27), P["paper"], P["ink"]); line(d, [(11, 11), (21, 11)], P["blue"]); line(d, [(11, 16), (20, 16)], P["rose"]); line(d, [(11, 21), (18, 21)], P["sage"])
    elif label == "DoNothing":
        d.ellipse((7, 15, 25, 24), fill=rgba(P["paper"]), outline=rgba(P["ink"])); px(d, 10, 10, P["sun"], 5, 5); px(d, 19, 9, P["sun"], 4, 4)
    else:
        rect(d, (9, 11, 23, 25), P["wood"], P["ink"]); px(d, 11, 7, P["sun"], 10, 5); line(d, [(23, 13), (28, 10)], P["ink"], 2)
    return im


def special_sprite(name: str) -> Image.Image:
    if name == "StillPixelBird": return object_sprite("CeramicBird")
    if name == "StillFocusCardSprite":
        im = image((80, 48)); d = ImageDraw.Draw(im); rect(d, (2, 4, 77, 43), P["night"], P["paper"]); rect(d, (8, 10, 20, 22), P["sun"]); line(d, [(8, 32), (42, 32)], P["lavender"], 2); return im
    if name == "StillEmptyTasks":
        im = image((64, 64)); d = ImageDraw.Draw(im); rect(d, (14, 10, 49, 53), P["paper"], P["ink"]); line(d, [(20, 22), (43, 22)], P["rose"], 2); line(d, [(20, 31), (38, 31)], P["blue"], 2); px(d, 36, 43, P["leaf"], 8, 7); return im
    if name == "StillEmptyDoodles":
        im = image((64, 64)); d = ImageDraw.Draw(im); rect(d, (10, 14, 53, 52), P["paper"], P["ink"]); line(d, [(18, 43), (28, 22), (41, 18), (47, 32)], P["rose"], 4); px(d, 16, 41, P["gold"], 6, 7); return im
    if name == "StillEmptyReminders":
        im = image((64, 64)); d = ImageDraw.Draw(im); d.ellipse((17, 17, 47, 47), fill=rgba(P["sky"]), outline=rgba(P["ink"])); line(d, [(32, 32), (32, 22)], P["ink"], 3); line(d, [(32, 32), (41, 36)], P["ink"], 3); px(d, 28, 11, P["sun"], 8, 6); return im
    return image((32, 32))


def save_asset(name: str, im: Image.Image, filename: str | None = None) -> None:
    filename = filename or f"{name}.png"
    folder = ASSETS / f"{name}.imageset"
    folder.mkdir(parents=True, exist_ok=True)
    target = folder / filename
    im.save(target, optimize=False)
    (folder / "Contents.json").write_text(json.dumps({"images": [{"filename": filename, "idiom": "universal", "scale": "1x"}, {"idiom": "universal", "scale": "2x"}, {"idiom": "universal", "scale": "3x"}], "info": {"author": "xcode", "version": 1}}, indent=2) + "\n")


def validate_palette(name: str, im: Image.Image) -> None:
    allowed = {rgba(color) for color in P.values()} | {(0, 0, 0, 0)}
    unexpected = set(im.convert("RGBA").getdata()).difference(allowed)
    if unexpected:
        raise ValueError(f"{name} used colors outside Still's authored palette: {sorted(unexpected)[:4]}")


def label(d: ImageDraw.ImageDraw, x: int, y: int, text: str, color: str = "#FFF5E8") -> None:
    d.text((x, y), text, fill=rgba(color))


def make_contact_sheet() -> Image.Image:
    cell_w, cell_h = 176, 158
    cols = 4
    room_names = list(ROOMS)
    # Eleven rows for the standard cells, then four tall rows that preserve the
    # existing six-pose × four-coat cat sheet at a readable pixel scale.
    rows = 16
    sheet = image((cols*cell_w + 12, rows*cell_h + 12), P["night"])
    d = ImageDraw.Draw(sheet)
    assets: list[tuple[str, Image.Image]] = [(f"Room{name}", room_sprite(name, ROOMS[name])) for name in room_names]
    assets += [(f"Object{name}", object_sprite(name)) for name in OBJECTS]
    assets += [(f"Break{name}", mini_icon(name)) for name in BREAKS]
    assets += [("FocusCard", special_sprite("StillFocusCardSprite")), ("Bird", special_sprite("StillPixelBird")), ("EmptyTasks", special_sprite("StillEmptyTasks")), ("EmptyDoodles", special_sprite("StillEmptyDoodles")), ("EmptyReminders", special_sprite("StillEmptyReminders"))]
    for idx, (name, im) in enumerate(assets):
        x = 8 + (idx % cols)*cell_w
        y = 8 + (idx // cols)*cell_h
        thumb = im.copy()
        if thumb.width <= 80: thumb = thumb.resize((thumb.width*2, thumb.height*2), Image.Resampling.NEAREST)
        sheet.alpha_composite(thumb, (x + (cell_w-thumb.width)//2, y + 8))
        label(d, x+6, y+cell_h-24, name[:23])
    cat_sheet = Image.open(SOURCES / "still-cat-contact-sheet.png").convert("RGBA")
    cat_x = 8
    cat_y = 8 + 11 * cell_h
    sheet.alpha_composite(cat_sheet, (cat_x, cat_y))
    label(d, cat_x + 6, cat_y + cat_sheet.height + 2, "CatCoats — 6 poses × 4 coats")
    return sheet


def main() -> None:
    SOURCES.mkdir(parents=True, exist_ok=True)
    for name, cfg in ROOMS.items():
        im = room_sprite(name, cfg)
        validate_palette(f"room {name}", im)
        im.save(SOURCES / f"still-room-{name.lower()}.png")
        save_asset(f"StillRoom{name}", im)
    for name in OBJECTS:
        im = object_sprite(name)
        validate_palette(f"object {name}", im)
        im.save(SOURCES / f"still-object-{name.lower()}.png")
        save_asset(f"StillObject{name}", im)
    for name in BREAKS:
        im = mini_icon(name)
        validate_palette(f"break {name}", im)
        im.save(SOURCES / f"still-break-{name.lower()}.png")
        save_asset(f"StillBreak{name}", im)
    for name in ["StillPixelBird", "StillFocusCardSprite", "StillEmptyTasks", "StillEmptyDoodles", "StillEmptyReminders"]:
        im = special_sprite(name)
        validate_palette(name, im)
        im.save(SOURCES / f"{name}.png")
        save_asset(name, im)
    contact = make_contact_sheet()
    contact.save(SOURCES / "still-sprite-contact-sheet.png")
    save_asset("StillSpriteContactSheet", contact, "still-sprite-contact-sheet.png")
    print(f"Generated {len(ROOMS)} rooms, {len(OBJECTS)} objects, {len(BREAKS)} break icons and contact sheet.")

if __name__ == "__main__":
    main()
