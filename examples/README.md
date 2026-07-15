# ArcMark examples

Runnable examples for the two delivery packages, sharing a single `.arc` document:

- [`commerce.arc`](commerce.arc) — an ArcMark Standard v1.0.0 document modeling a small commerce domain (entities, services, an event, and directed relationships).
- [`node/`](node) — a dependency-free static server that loads `@caraveo/arcmark-viewer` and renders `commerce.arc` in a browser.
- [`python/`](python) — scripts that read, inspect, and render `commerce.arc` with the `arcmark` package.

## Run

### Node.js

```bash
cd node
npm install ../../packages/arcmark-viewer   # one time, pulls in the local viewer
npm start                                     # http://localhost:4321
```

### Python

```bash
cd python
python render_svg.py        # writes ../commerce.svg
python inspect_model.py     # prints the graph to stdout
```

The Python scripts wire the local `arcmark` checkout onto `sys.path`, so they run from a repository clone without `pip install`.

See each folder's `README.md` for details.