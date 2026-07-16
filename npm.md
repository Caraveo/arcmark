# ArcMark npm package

## `@caraveo/arcmark-viewer` v1.0.2

`@caraveo/arcmark-viewer` is ArcMark's public npm package for showing a portable ArcMark system design in a browser. It is a small, dependency-free web component: author a diagram in ArcMark Studio, save the `.arc` document, and render the same source of truth in a documentation site, engineering portal, product surface, or Electron app.

## Install

```bash
npm install @caraveo/arcmark-viewer
```

```js
import "@caraveo/arcmark-viewer";
```

```html
<arcmark-diagram src="/diagrams/commerce.arc"></arcmark-diagram>
```

Alternatively, assign an ArcMark XML string directly:

```js
document.querySelector("arcmark-diagram").data = arcDocumentText;
```

The element emits `arcmark-load` when a diagram is ready and `arcmark-error` when it cannot fetch or parse the source. It runs in the browser, so in server-rendered applications load it on the client.

## What it includes

- ArcMark Standard v1.0.0 XML parsing.
- Entity, service, event, field, and relationship rendering.
- A browser-native custom element with no runtime npm dependencies.
- A public package name: `@caraveo/arcmark-viewer`.

## Quality and publishing

```bash
cd packages/arcmark-viewer
npm test
npm pack --dry-run
npm publish --access public
```

The package has its own semantic versioning, independent from ArcMark Studio. Every npm release is tracked with a matching Git tag in the form `arcmark-npm-vX.Y.Z`.
