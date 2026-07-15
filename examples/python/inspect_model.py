#!/usr/bin/env python3
"""Inspect an ArcMark document and print its graph as plain text.

Useful as a CI gate or to summarize a system model in a build log.

Run from this directory:
    python inspect.py

Or against any .arc file:
    python inspect.py path/to/input.arc
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

    try:
        diagram = ArcMarkDiagram.from_file(arc_path)
    except (OSError, ArcMarkError) as error:
        print(f"Could not read {arc_path}: {error}", file=sys.stderr)
        return 1

    print(f"Diagram: {diagram.title}  (ArcMark {diagram.version})")
    print(f"Nodes ({len(diagram.nodes)}):")
    for node in diagram.nodes:
        fields = ", ".join(f"{f.name}: {f.type}" for f in node.fields) or "no fields"
        print(f"  [{node.kind:7}] {node.name} ({node.id}) @ ({node.x:g}, {node.y:g}) -> {fields}")

    print(f"Relationships ({len(diagram.relationships)}):")
    by_id = {node.id: node for node in diagram.nodes}
    for rel in diagram.relationships:
        print(f"  {by_id[rel.from_id].name} --{rel.type}--> {by_id[rel.to_id].name}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))