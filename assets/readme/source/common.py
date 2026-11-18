"""Shared palette, typography and drawing primitives for the README SVGs."""

from pathlib import Path
from xml.etree import ElementTree as ET

ROOT = Path(__file__).resolve().parents[3]
OUT = ROOT / "assets/readme"
WIDTH = 1200
SVG_NS = "http://www.w3.org/2000/svg"
SUFFIXES = {"zh-CN": ".zh-CN.svg", "en": ".svg", "ja": ".ja.svg"}
IMAGES = ("hero", "changes", "workflow", "gates", "lineup")

SANS = "-apple-system, BlinkMacSystemFont, 'Segoe UI', 'PingFang SC', 'Hiragino Sans', 'Noto Sans CJK SC', sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"
BG, CARD, INK, MUTED, LINE = "#F7F4EE", "#FFFFFF", "#2B2A3D", "#8A8798", "#E4DED3"
GOLD, CORAL, TEAL = "#F2B544", "#E07A5F", "#3E9C9E"


class Drawing:
    def __init__(self, height, lang, title, desc):
        self.svg = ET.Element("svg", {
            "xmlns": SVG_NS, "xml:lang": lang, "width": str(WIDTH), "height": str(height),
            "viewBox": f"0 0 {WIDTH} {height}", "role": "img", "aria-labelledby": "title desc",
        })
        self.add("title", title, id="title")
        self.add("desc", desc, id="desc")
        self.rect("base", 0, 0, WIDTH, height, BG, radius=28)

    def add(self, tag, content=None, **attributes):
        element = ET.SubElement(self.svg, tag, {
            name.replace("_", "-"): str(value) for name, value in attributes.items()
        })
        element.text = content

    def rect(self, name, x, y, width, height, fill=CARD, *, radius=18, stroke=None, dash=None):
        attributes = {"id": name, "x": x, "y": y, "width": width, "height": height, "fill": fill, "rx": radius}
        if stroke:
            attributes.update(stroke=stroke, stroke_width=2)
        if dash:
            attributes["stroke_dasharray"] = dash
        self.add("rect", **attributes)

    def text(self, card, content, x, y, size, *, weight=600, color=INK, anchor="start", mono=False):
        # Link each line to the actual backing rect, not to duplicate bounds or a copied color.
        self.add("text", content, data_card=card, x=x, y=y, font_size=size,
                 font_weight=weight, fill=color, text_anchor=anchor, font_family=MONO if mono else SANS)

    def star(self, x, y, r, color=GOLD):
        self.add("path", d=f"M{x},{y-r} Q{x},{y} {x+r},{y} Q{x},{y} {x},{y+r} "
                 f"Q{x},{y} {x-r},{y} Q{x},{y} {x},{y-r} Z", fill=color)

    def path(self, d, *, color=GOLD, width=2.5, dash=None):
        attributes = {"stroke_dasharray": dash} if dash else {}
        self.add("path", d=d, fill="none", stroke=color, stroke_width=width,
                 stroke_linecap="round", stroke_linejoin="round", **attributes)

    def write(self, name, lang):
        ET.indent(self.svg)
        (OUT / (name + SUFFIXES[lang])).write_text(
            ET.tostring(self.svg, encoding="unicode") + "\n", encoding="utf-8"
        )
