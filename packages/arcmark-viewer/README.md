# @arcmark/viewer

A dependency-free, read-only web component for displaying ArcMark `.arc` diagrams in a Node.js web project.

## Install

```bash
npm install @arcmark/viewer
```

Until it is published, install it from this repository:

```bash
npm install /path/to/Universal\ Systems\ Design/packages/arcmark-viewer
```

## Use with a file URL

```js
import "@arcmark/viewer";
```

```html
<arcmark-diagram src="/diagrams/commerce.arc"></arcmark-diagram>
```

## Use with an XML string

```js
import "@arcmark/viewer";

document.querySelector("arcmark-diagram").data = arcDocumentText;
```

The component emits `arcmark-load` with the parsed diagram model and `arcmark-error` when fetching or parsing fails.

It is a browser component, so use it in client-side code in Next.js, Vite, Express-rendered pages, Electron, and similar Node.js projects. For server-side rendering, load it only after the page reaches the browser.
