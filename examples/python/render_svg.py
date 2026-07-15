#!/usr/bin/env python3
"""Render the shared commerce.arc document to an SVG file.

Run from this directory:
    python render_svg.py

Or against any .arc file:
    python render_svg.py path/to/input.arc output.svg

The script wires the local arcmark package onto sys.path so it can run
without `pip install` from within the repository checkout. In a real
project you would `pip install arcmark` instead.
"""

from __future__ import annotations

import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parent.parent
sys.path.insert(0, str(REPO / "packages" / "arcmark-python" / "src"))

from arcmark import ArcMarkDiagram, ArcMarkError


def main(argv: list[str]) -> int:
    arc_path = Path(argv[1]) if len(argv) > 1 else HERE.parent / "commerce.arc"
    svg_path = Path(argv[2]) if len(argv) > 2 else HERE / "commerce.svg"

    try:
        diagram = ArcMarkDiagram.from_file(arc_path)
    except (OSError, ArcMarkError) as error:
        print(f"Could not read {arc_path}: {error}", file=sys.stderr)
        return 1

    svg_path.write_text(diagram.to_svg(), encoding="utf-8")
    print(f"Rendered {diagram.title}: {len(diagram.nodes)} nodes, {len(diagram.relationships)} relationships.")
    print(f"Wrote {svg_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))