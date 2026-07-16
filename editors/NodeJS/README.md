# ArcMark Editor

A dependency-free Node.js web editor for authoring **ArcMark Standard v1.1.0** `.arc` system diagrams in the browser. Build entities, services, and events on a draggable canvas, connect them with directed relationships, set document ownership metadata, and live-preview the rendered result with `@caraveo/arcmark-viewer`.

```bash
npm install
npm start        # http://localhost:4200
```

On macOS, double-click **`ArcMark Editor.command`** in Finder for quick access — it installs on first run and opens the editor in your default browser.

## What it does

- **Canvas authoring** — add entity/service/event nodes, drag to position, edit fields in place.
- **Directed relationships** — select a node, click **Connect**, then click the destination to link them.
- **Document metadata** — set the diagram `title`, `owner`, and `creator-id` (ArcMark Standard v1.1.0 ownership fields).
- **Live render preview** — a side panel renders the document with `@caraveo/arcmark-viewer` as you edit. The viewer renders the model; it does not expose the raw `.arc` source.
- **Open & save** — import any `.arc` file from disk and download the edited document as `.arc`. You can also save directly into the bundled `diagrams/` folder via the local server.

## Requirements

- Node.js 18 or newer.

## Architecture

The server (`server.js`) uses only Node.js built-ins — there are no server-side runtime dependencies. The editor UI (`public/`) is vanilla HTML/CSS/JS with no build step. The render preview is provided by [`@caraveo/arcmark-viewer`](https://www.npmjs.com/package/@caraveo/arcmark-viewer), tracked as the single runtime dependency.

| Path | Role |
| --- | --- |
| `server.js` | Local HTTP server, built-ins only |
| `public/index.html` | Editor shell |
| `public/editor.js` | Authoring logic + ArcMark v1.1.0 serialization |
| `public/editor.css` | Editor styling |
| `diagrams/` | Server-side saved `.arc` documents |
| `ArcMark Editor.command` | macOS quick-access launcher |

> The viewer dependency currently resolves to the local `@caraveo/arcmark-viewer` package via a `file:` path so the editor runs before the npm package is published. Once `@caraveo/arcmark-viewer@1.0.4` is on npm, swap `package.json` to `"^1.0.4"`.

## ArcMark Standard

Editor output targets **ArcMark Standard v1.1.0** and reads both `1.0.0` and `1.1.0` documents. See the [ArcMark specification](https://github.com/Caraveo/arcmark/blob/main/SPECIFICATION.md) for the full format.

## License

MIT © Caraveo