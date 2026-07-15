# Python example

Read, inspect, and render the shared `commerce.arc` document with the `arcmark` package.

## Run

From this directory:

```bash
python render_svg.py        # writes ../commerce.svg
python inspect_model.py     # prints the diagram graph
```

Both scripts add the local checkout of `arcmark` to `sys.path`, so they run without `pip install`. In a real project you would `pip install arcmark` and drop the `sys.path.insert` line.

## What it shows

- `ArcMarkDiagram.from_file()` reads and structurally validates a `.arc` document.
- `to_svg()` produces a self-contained SVG suitable for docs, CI artifacts, or HTTP responses.
- The parsed model (nodes, fields, relationships) can be inspected directly for analysis or gates.