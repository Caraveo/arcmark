# arcmark

`arcmark` is a dependency-free Python package for reading, checking, and rendering ArcMark `.arc` diagram documents.

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

`from_xml()` and `from_file()` raise `ArcMarkError` for malformed documents, unsupported node types, duplicate IDs, and broken relationship references.

## CLI

```bash
arcmark commerce.arc --output commerce.svg
```

The package validates ArcMark's structural requirements without dependencies. Use the repository's `arcmark.xsd` with an XML Schema validator when full XSD validation is required.
