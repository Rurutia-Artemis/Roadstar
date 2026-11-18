#!/usr/bin/env python3
"""Validate the flat SVG format emitted by the README generators."""

import argparse
import math
import re
from xml.etree import ElementTree as ET

from common import IMAGES, OUT, ROOT, SUFFIXES, SVG_NS, WIDTH

MAX_BYTES = 40_000
DISPLAY_WIDTH = 880
MIN_RENDERED_SIZE = 11
PADDING = 12
MIN_CONTRAST = 4.5
READMES = ("README.md", "README.en.md", "README.ja.md")
ASSET_REFERENCE = re.compile(r"assets/readme/([^\s<>\"`()]+\.svg)\b")
UNSAFE_SOURCE = re.compile(r"@import|https?|<!DOCTYPE|<!ENTITY|<\?(?!xml\s)", re.IGNORECASE)
SVG_NAMESPACE_DECL = re.compile(r"""\s+xmlns=(["'])http://www\.w3\.org/2000/svg\1""")
ALLOWED_TAGS = {"svg", "title", "desc", "rect", "path", "circle", "text"}


def number(element, key):
    value = float(element.attrib[key])
    if not math.isfinite(value):
        raise ValueError(f"{key} must be finite")
    return value


def luminance(color):
    if not re.fullmatch(r"#[0-9a-fA-F]{6}", color):
        raise ValueError(f"expected an opaque #RRGGBB fill, got {color!r}")
    channels = [int(color[index:index + 2], 16) / 255 for index in (1, 3, 5)]
    linear = [c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4 for c in channels]
    return sum(c * weight for c, weight in zip(linear, (0.2126, 0.7152, 0.0722)))


def contrast_ratio(foreground, background):
    dark, light = sorted((luminance(foreground), luminance(background)))
    return (light + 0.05) / (dark + 0.05)


def check_text(element, cards, viewbox):
    label = (element.text or "").strip()
    if not label or len(element):
        yield "text must consist of one non-empty line without nested elements"
        return
    try:
        box = cards[element.attrib["data-card"]]
        x, y, size = (number(element, key) for key in ("x", "y", "font-size"))
        left, top, width, height = (number(box, key) for key in ("x", "y", "width", "height"))
        anchor = {"start": 0, "middle": 0.5, "end": 1}[element.attrib["text-anchor"]]
        ratio = contrast_ratio(element.get("fill", ""), box.get("fill", ""))
    except (KeyError, ValueError) as error:
        yield f"{label!r}: missing or invalid text/card geometry or fill ({error})"
        return

    rendered_size = size * DISPLAY_WIDTH / viewbox[2]
    if rendered_size < MIN_RENDERED_SIZE:
        yield f"{label!r}: font renders at {rendered_size:.2f}px (< {MIN_RENDERED_SIZE}px)"

    # Treat all non-ASCII glyphs as full-width, including CJK punctuation.
    text_width = size * sum(0.6 if char.isascii() else 1 for char in label)
    start = x - text_width * anchor
    end = start + text_width
    canvas_x, canvas_y, canvas_w, canvas_h = viewbox
    if width <= 0 or height <= 0 or not (
        canvas_x <= left < left + width <= canvas_x + canvas_w
        and canvas_y <= top < top + height <= canvas_y + canvas_h
    ):
        yield f"{label!r}: backing card {box.get('id')!r} is outside the viewBox"
    if min(start - left, left + width - end) < PADDING or not top <= y - size < y <= top + height:
        yield f"{label!r}: overflows {box.get('id')!r} or has less than {PADDING} units of side padding"
    if ratio < MIN_CONTRAST:
        yield f"{label!r}: contrast {ratio:.2f}:1 against {box.get('id')!r} (< {MIN_CONTRAST}:1)"


def check_svg(path):
    try:
        if path.stat().st_size > MAX_BYTES:
            yield f"exceeds {MAX_BYTES} bytes"
            return
        source = path.read_text(encoding="utf-8")
    except (OSError, UnicodeError) as error:
        yield f"cannot read SVG: {error}"
        return

    match = UNSAFE_SOURCE.search(SVG_NAMESPACE_DECL.sub("", source, count=1))
    if match:
        yield f"forbidden markup or external reference: {match[0]!r}"
        return

    try:
        svg = ET.fromstring(source)
    except ET.ParseError as error:
        yield f"invalid XML: {error}"
        return
    if svg.tag != f"{{{SVG_NS}}}svg":
        yield "root must be an SVG element"
        return
    try:
        viewbox = tuple(map(float, re.split(r"[ ,]+", svg.get("viewBox", "").strip())))
        if (len(viewbox) != 4 or not all(map(math.isfinite, viewbox))
                or viewbox[2] != WIDTH or viewbox[3] <= 0):
            raise ValueError
        if number(svg, "width") != viewbox[2] or number(svg, "height") != viewbox[3]:
            raise ValueError
    except (KeyError, ValueError):
        yield f"expected numeric dimensions matching a {WIDTH}-wide viewBox"
        return

    # Explicit geometry and opaque fills keep the width and contrast checks
    # meaningful; styles, transforms and nested drawing elements are unsupported.
    ids = set()
    cards = {}
    text_count = 0
    for element in svg.iter():
        namespace, _, tag = element.tag.rpartition("}")
        if namespace != "{" + SVG_NS or tag not in ALLOWED_TAGS or (tag == "svg" and element is not svg):
            yield f"forbidden SVG element <{tag}>"
            continue
        if any(key in element.attrib for key in (
            "style", "class", "transform", "clip-path", "mask", "filter", "display",
            "visibility", "opacity", "fill-opacity", "letter-spacing", "textLength", "dx", "dy",
        )) or any(key.lower().startswith("on") for key in element.attrib):
            yield f"<{tag}> uses unsupported styling, geometry or events"
        if tag != "svg" and len(element):
            yield f"<{tag}> must not contain child elements"
        identifier = element.get("id")
        if identifier:
            if identifier in ids:
                yield f"duplicate id {identifier!r}"
            ids.add(identifier)
            if tag == "rect":
                cards[identifier] = element
        if tag == "text":
            text_count += 1
            yield from check_text(element, cards, viewbox)

    if not text_count:
        yield "SVG has no text to check"


def check_readmes(all_readmes):
    referenced = set()
    problems = []
    for name in READMES if all_readmes else READMES[:1]:
        try:
            content = (ROOT / name).read_text(encoding="utf-8")
        except (OSError, UnicodeError) as error:
            problems.append(f"{name}: cannot read README: {error}")
            continue
        for asset in sorted(set(ASSET_REFERENCE.findall(content))):
            referenced.add(asset)
            if not (OUT / asset).is_file():
                problems.append(f"{name}: missing asset assets/readme/{asset}")

    if all_readmes:
        for path in sorted(OUT.glob("*.svg")):
            if path.name not in referenced:
                problems.append(f"{path.relative_to(ROOT)}: not referenced by any README")
    return problems


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--all", action="store_true", help="check all READMEs and flag unreferenced SVGs")
    args = parser.parse_args()
    assets = [OUT / (name + suffix) for name in IMAGES for suffix in SUFFIXES.values()]
    problems = [f"{path.relative_to(ROOT)}: {reason}" for path in assets for reason in check_svg(path)]
    problems.extend(check_readmes(args.all))
    if problems:
        print("\n".join(problems))
        return 1
    references = "three READMEs; no unreferenced SVGs" if args.all else "README.md references"
    print(f"PASS {len(assets)} SVGs; {references}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
