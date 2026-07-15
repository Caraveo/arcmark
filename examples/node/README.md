# Node.js example

A dependency-free static server that loads `@caraveo/arcmark-viewer` and renders the shared `commerce.arc` document in a browser.

## Run

```bash
cd examples/node
npx --yes npm@latest run install:viewer   # install the local viewer into node_modules/
npm start                                    # serves http://localhost:4321
```

Open <http://localhost:4321> in a browser. The page loads the web component, fetches `commerce.arc`, and fires the `arcmark-load` event with the parsed model.

## What it shows

- Serving a `.arc` file with the correct `application/xml` content type.
- Loading `@caraveo/arcmark-viewer` as an ES module.
- Using the `arcmark-diagram` element with the `src` attribute.
- Listening for `arcmark-load` / `arcmark-error` events.

No runtime dependencies are required; the server uses only Node built-ins (`node:http`, `node:fs/promises`).