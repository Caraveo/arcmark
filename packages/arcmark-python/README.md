# arcmark

`arcmark` is the Python toolkit for Universal System Design. It reads, checks, and renders ArcMark Standard v1.0.0 `.arc` documents so the system model authored in ArcMark Studio can participate in automation, documentation, and engineering workflows.

Use it when a diagram needs to become more than a picture: inspect a service graph in CI, validate relationship references before a release, generate SVG for a documentation site, or build your own architecture-aware tooling around a portable system model.

## Install

```bash
pip install arcmark
```

For local development:

```bash
pip install /path/to/Universal\ Systems\ Design/packages/arcmark-python
```

## Python API

```python
from arcmark import ArcMarkDiagram

diagram = ArcMarkDiagram.from_file("commerce.arc")
print(diagram.title)

# Return an SVG string: send it from Flask/FastAPI, or write it to a file.
svg = diagram.to_svg()
```

`from_xml()` and `from_file()` raise `ArcMarkError` for malformed documents, unsupported ArcMark versions or node types, duplicate IDs, and broken relationship references.

## CLI

```bash
arcmark commerce.arc --output commerce.svg
```

The package validates ArcMark's structural requirements without dependencies. Use the repository's `arcmark.xsd` with an XML Schema validator when full XSD validation is required. For presentation-ready, automatically arranged output, use ArcMark Studio's **Extract** view to generate a System Design Overview as SVG, PNG, JPEG, or PDF.
