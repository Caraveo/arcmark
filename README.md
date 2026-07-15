<p align="center">
  <img src="Assets/arcmark-logo.png" width="100%" alt="ArcMark logo">
</p>

# ArcMark Studio

ArcMark Studio is a native macOS workspace for designing systems as connected, portable models—not disposable drawings.

## Universal System Design

Software systems are understood differently by architects, engineers, operators, and the tools they use. **Universal System Design** is ArcMark's vision for closing that gap: describe a system once as a clear graph of entities, services, events, fields, and directed relationships; then carry that same meaning from a hands-on canvas to documentation, codebases, automation, and the web.

The goal is straightforward: make system design durable, inspectable, and easy to share. A diagram should be a useful source of truth that can travel with a project—not an image that loses meaning the moment it leaves the whiteboard.

## The ArcMark Standard

**ArcMark Standard v1.0.0** is the open, XML-based model behind an ArcMark diagram. Documents use the intentional `.arc` extension, are UTF-8 encoded, and are defined by the bundled [`arcmark.xsd`](Sources/ArcMarkStudio/Resources/arcmark.xsd) schema and [format specification](SPECIFICATION.md).

An ArcMark document stores the things a system needs to communicate:

- Nodes for entities, services, and events.
- Fields that describe each node's shape.
- Directed, typed relationships that describe how the system behaves.
- Canvas coordinates for editing without making presentation layout part of the model.

Because the model is plain structured data, the same `.arc` file can power a native editor, a documentation site, an API workflow, or automated analysis.

## ArcMark Studio

ArcMark Studio is the Mac-native editor for the standard. Build a system naturally on a draggable SwiftUI canvas, connect nodes directly, edit fields in place, name the diagram, and save the result as an `.arc` document that macOS recognizes as an ArcMark file.

### Canvas editor

![ArcMark Studio canvas editor](Assets/arcmark-studio-canvas.png)

### Extract: System Design Overview

**Extract** turns the semantic graph behind the canvas into a clean, relationship-first **System Design Overview**. It makes its own layout decisions, so the overview is not constrained by the way the working canvas happens to be arranged.

![Commerce Domain system design overview](Assets/commerce-domain-extract.png)

The extract engine keeps the overview simple and readable:

- Flows favor left-to-right and then top-to-bottom placement.
- Branches receive their own rows, leaving room for each connection.
- Relationships route with crisp 90-degree turns instead of crossing through nodes.
- Cycles are grouped as an unlabeled loop area; the return edge is implied by the enclosure while the remaining relationships remain visible.
- Nodes become clean, title-only cards with one-pixel borders, ideal for sharing a system at a glance.

Export the overview as SVG, PNG, JPEG, or PDF. SVG and PNG use transparent backgrounds, making them ready for design docs, slides, wikis, pull requests, and print workflows.

## Use ArcMark anywhere

### Node.js: `@arcmark/viewer`

The Node.js package provides a small, dependency-free browser web component for displaying a generic ArcMark document in any web project. Use it in a Next.js, Vite, Express, Electron, or static site front end to load a `.arc` file by URL or pass XML directly. It is intentionally read-only: ArcMark Studio is where the model is authored, and the viewer is where it is shared.

```js
import "@arcmark/viewer";

document.querySelector("arcmark-diagram").data = arcDocumentText;
```

See [`packages/arcmark-viewer`](packages/arcmark-viewer) for installation, event, and integration details.

### Python: `arcmark`

The Python package lets automation, build tooling, data pipelines, and backend services read, check, and render ArcMark documents. Use it to validate relationships, inspect architecture in CI, generate documentation, or produce SVG directly from an `.arc` source of truth.

```python
from arcmark import ArcMarkDiagram

diagram = ArcMarkDiagram.from_file("commerce.arc")
svg = diagram.to_svg()
```

See [`packages/arcmark-python`](packages/arcmark-python) for the API and CLI.

## Run ArcMark Studio

```bash
swift run
```

To build a release executable:

```bash
swift build -c release
```

## macOS document support

ArcMark Studio registers the `com.arcmark.diagram` Uniform Type Identifier, declares itself as the Editor for that type, and claims `.arc` files in [`ArcMarkStudio-Info.plist`](ArcMarkStudio-Info.plist). When packaging the executable as an `.app`, macOS Launch Services associates `.arc` files with ArcMark Studio and shows it in **Open With**.
