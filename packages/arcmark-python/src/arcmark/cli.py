"""Command-line renderer for ArcMark documents."""

from argparse import ArgumentParser
from pathlib import Path
from .diagram import ArcMarkDiagram, ArcMarkError


def main() -> None:
    parser = ArgumentParser(description="Render an ArcMark .arc document as SVG.")
    parser.add_argument("input", type=Path, help="Input .arc file")
    parser.add_argument("-o", "--output", type=Path, required=True, help="Output .svg file")
    args = parser.parse_args()
    try:
        args.output.write_text(ArcMarkDiagram.from_file(args.input).to_svg(), encoding="utf-8")
    except (OSError, ArcMarkError) as error:
        parser.error(str(error))
