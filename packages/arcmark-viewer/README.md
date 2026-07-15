# @caraveo/arcmark-viewer

`@caraveo/arcmark-viewer` is the web delivery layer for Universal System Design: a dependency-free, read-only web component that turns an ArcMark `.arc` document into a useful diagram inside a Node.js web project.

ArcMark Studio is where a team authors the system model; this component is how that same portable model can appear in product documentation, internal portals, developer tools, and customer-facing architecture pages. It accepts the ArcMark Standard v1.0.0 `.arc` format without needing a server-side renderer.

## Install

```bash
npm install @caraveo/arcmark-viewer
```

For local development, install it from this repository:

```bash
npm install /path/to/Universal\ Systems\ Design/packages/arcmark-viewer
```

## Use with a file URL

```js
import "@caraveo/arcmark-viewer";
```

```html
<arcmark-diagram src="/diagrams/commerce.arc"></arcmark-diagram>
```

## Use with an XML string

```js
import "@caraveo/arcmark-viewer";

document.querySelector("arcmark-diagram").data = arcDocumentText;
```

The component emits `arcmark-load` with the parsed diagram model and `arcmark-error` when fetching or parsing fails. This makes it easy to connect a diagram to surrounding application UI, analytics, or documentation metadata.

It is a browser component, so use it in client-side code in Next.js, Vite, Express-rendered pages, Electron, and similar Node.js projects. For server-side rendering, load it only after the page reaches the browser. For a clean relationship-first export, create a **System Design Overview** from ArcMark Studio and export SVG, PNG, JPEG, or PDF.

## Verify the package

```bash
npm test
npm pack --dry-run
```

The test suite exercises ArcMark XML parsing with a browser-compatible DOM implementation. The published package itself remains dependency-free at runtime.
