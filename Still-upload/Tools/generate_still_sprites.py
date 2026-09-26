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
    "ink": "#3C2C3A", "ink2": "#624556", "night": "#25294A", "night2": "#3A4165",
    "plum": "#6A5075", "lavender": "#A79ACF", "mist": "#D7D0EA", "paper": "#FFF5E8",
    "cream": "#F4E3CF", "peach": "#F4C8B4", "coral": "#D98272", "rust": "#AF5C54",
    "sun": "#FFD98A", "gold": "#DCA958", "wood": "#B87B59", "wooddark": "#85523F",
    "floor": "#D7A77D", "floordark": "#A8755C", "sage": "#86AA89", "leaf": "#4E7B62",
    "mint": "#B9DDC2", "sky": "#A9D5E7", "blue": "#7098C0", "rain": "#DCEEFF",
    "rose": "#DEA7B8", "pink": "#F3C5D6", "clay": "#C9795D", "snow": "#F6FBFC",
    "grey": "#99A1B4", "charcoal": "#50566D", "black": "#2B2630", "white": "#FFFFFF",
}

ROOMS = {
    "RainyBedroom": {"wall": P["plum"], "side": P["lavender"], "sky": P["night2"], "floor": P["floor"], "leaf": P["leaf"], "accent": P["rose"], "weather": "rain"},
    "LibraryLight": {"wall": P["wood"], "side": P["peach"], "sky": P["sun"], "floor": P["floor"], "leaf": P["sage"], "accent": P["blue"], "weather": "sun"},
    "TrainWindow": {"wall": P["grey"], "side": P["mist"], "sky": P["sky"], "floor": P["floor"], "leaf": P["sage"], "accent": P["gold"], "weather": "hills"},
    "NightCity": {"wall": P["plum"], "side": P["night2"], "sky": P["night"], "floor": P["floordark"], "leaf": P["leaf"], "accent": P["lavender"], "weather": "city"},
    "AutumnWindow": {"wall": P["wooddark"], "side": P["wood"], "sky": P["coral"], "floor": P["floordark"], "leaf": P["gold"], "accent": P["sun"], "weather": "leaves"},
    "SnowDay": {"wall": P["blue"], "side": P["sky"], "sky": P["mist"], "floor": P["floordark"], "leaf": P["sage"], "accent": P["snow"], "weather": "snow"},
    "SpringRain": {"wall": P["sage"], "side": P["mint"], "sky": P["sky"], "floor": P["floor"], "leaf": P["leaf"], "accent": P["rose"], "weather": "sprout"},
    "AlarmSleep": {"wall": P["night2"], "side": P["plum"], "sky": P["night"], "floor": P["floordark"], "leaf": P["leaf"], "accent": P["lavender"], "weather": "moon"},
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


def room_sprite(name: str, cfg: dict[str, str]) -> Image.Image:
    # The outer canvas remains transparent: RoomHeroView supplies its warm page
    # halo, so the room floats as architecture rather than a dark rectangle.
    im = image((160, 132))
    d = ImageDraw.Draw(im)
    # Two fully opaque walls plus floor: no translucent pseudo-room plane.
    rect(d, (3, 7, 108, 75), cfg["wall"], P["ink"])
    d.polygon([(108, 7), (156, 30), (156, 99), (108, 75)], fill=rgba(cfg["side"]), outline=rgba(P["ink"]))
    d.polygon([(3, 76), (108, 76), (156, 100), (50, 129)], fill=rgba(cfg["floor"]), outline=rgba(P["ink"]))
    # Soft pixel radial glow, authored in concentric stepped blocks around lamp.
    for inset, color in [(0, P["sun"]), (4, P["gold"]), (9, P["peach"]), (15, P["floor"])]:
        d.polygon([(80-inset, 56-inset//2), (100+inset, 61-inset//3), (115+inset, 82+inset//3), (63-inset, 86+inset//3)], fill=rgba(color))
    # Window frame + unique outdoor scene.
    rect(d, (18, 18, 56, 58), P["ink"], P["ink"])
    rect(d, (21, 21, 53, 55), cfg["sky"])
    line(d, [(37, 21), (37, 55)], P["ink"], 2)
    line(d, [(21, 38), (53, 38)], P["ink"], 2)
    weather = cfg["weather"]
    if weather == "rain":
        for x, y in [(24, 24), (31, 30), (47, 25), (42, 42), (28, 46), (50, 48)]: line(d, [(x, y), (x-2, y+5)], P["rain"])
    elif weather == "sun":
        for x, y in [(24, 29), (29, 25), (46, 27), (49, 44), (26, 48)]: px(d, x, y, P["sun"], 3, 3)
    elif weather == "hills":
        d.polygon([(21, 48), (28, 39), (36, 47), (43, 35), (53, 48), (53, 55), (21, 55)], fill=rgba(P["sage"]))
        d.polygon([(21, 52), (31, 44), (39, 52), (49, 42), (53, 52), (53, 55), (21, 55)], fill=rgba(P["leaf"]))
    elif weather == "city":
        for x, h in [(24, 11), (30, 18), (37, 9), (43, 16), (49, 12)]:
            rect(d, (x, 55-h, x+4, 55), P["night"])
            px(d, x+1, 53-h, P["sun"])
    elif weather == "leaves":
        for x, y in [(25, 25), (34, 29), (48, 26), (29, 42), (44, 46)]: px(d, x, y, P["gold"], 3, 2)
    elif weather == "snow":
        for x, y in [(25, 24), (34, 30), (46, 25), (27, 44), (45, 47)]: px(d, x, y, P["snow"], 2, 2)
    elif weather == "sprout":
        for x, y in [(25, 45), (31, 39), (37, 48), (45, 37), (50, 43)]:
            px(d, x, y, P["leaf"], 4, 3)
    elif weather == "moon":
        px(d, 39, 27, P["mist"], 8, 8)
        px(d, 43, 25, cfg["sky"], 6, 7)
    # Desk / bed / shelf furniture included in every starter room.
    rect(d, (70, 67, 132, 75), P["wood"], P["ink"])
    d.polygon([(70, 67), (90, 57), (147, 73), (132, 75)], fill=rgba(P["wood"]), outline=rgba(P["ink"]))
    rect(d, (75, 75, 82, 105), P["wooddark"], P["ink"])
    rect(d, (124, 75, 131, 99), P["wooddark"], P["ink"])
    rect(d, (97, 46, 103, 67), P["ink"], P["ink"])
    d.polygon([(90, 46), (111, 46), (106, 56), (94, 56)], fill=rgba(P["sun"]), outline=rgba(P["ink"]))
    rect(d, (9, 83, 55, 103), P["mint"], P["ink"])
    rect(d, (12, 78, 45, 86), P["paper"], P["ink"])
    rect(d, (13, 104, 51, 115), P["floordark"], P["ink"])
    # Plant plus shelf form the room's consistent visual language.
    rect(d, (137, 48, 150, 62), P["clay"], P["ink"])
    for x, y in [(139, 47), (144, 43), (148, 47), (141, 39), (147, 38)]: px(d, x, y, cfg["leaf"], 6, 7)
    rect(d, (115, 24, 151, 29), P["wooddark"], P["ink"])
    for x, c in [(118, P["blue"]), (124, P["rose"]), (130, P["gold"]), (136, P["sage"]), (142, cfg["accent"])]: rect(d, (x, 16, x+4, 24), c, P["ink"])
    # Useful object hot-spots visible in the base room: calendar, shelf, window, plant, desk.
    rect(d, (62, 21, 75, 37), P["paper"], P["ink"])
    line(d, [(64, 26), (73, 26)], P["rose"])
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
