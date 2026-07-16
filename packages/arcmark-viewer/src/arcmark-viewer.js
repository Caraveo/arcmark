const COLORS = { entity: "#23b8d4", service: "#8b5cf6", event: "#f59e0b" };
const STANDARD_VERSION = "1.1.0";
const SUPPORTED_VERSIONS = new Set(["1.0.0", "1.1.0"]);
const NODE_KINDS = new Set(["entity", "service", "event"]);

function requiredAttribute(element, name, context) {
  const value = element.getAttribute(name);
  if (!value) throw new Error(`${context} requires a ${name} attribute.`);
  return value;
}

function coordinate(element, name, nodeID) {
  const value = requiredAttribute(element, name, `Node ${nodeID}`);
  const number = Number(value);
  if (!Number.isFinite(number)) throw new Error(`Node ${nodeID} has a non-numeric ${name} coordinate.`);
  return number;
}

/** Parse and validate an ArcMark Standard `.arc` document. Supports v1.0.0 and v1.1.0. */
export function parseArcMark(xml) {
  const doc = new DOMParser().parseFromString(xml, "application/xml");
  if (doc.querySelector("parsererror")) throw new Error("The ArcMark document is not valid XML.");
  const root = doc.documentElement;
  if (root?.tagName !== "arcmark") throw new Error("Expected an ArcMark document with an <arcmark> root.");
  const version = requiredAttribute(root, "version", "The <arcmark> element");
  if (!SUPPORTED_VERSIONS.has(version)) throw new Error(`Unsupported ArcMark version ${version}. Expected ${STANDARD_VERSION}.`);
  const diagrams = [...root.querySelectorAll(":scope > diagram")];
  if (diagrams.length !== 1) throw new Error("An ArcMark document requires exactly one <diagram>.");
  const diagram = diagrams[0];
  const title = requiredAttribute(diagram, "title", "The <diagram> element");
  const owner = diagram.getAttribute("owner") || null;
  const creatorID = diagram.getAttribute("creator-id") || null;
  const nodesElement = diagram.querySelector(":scope > nodes");
  if (!nodesElement) throw new Error("A diagram requires a <nodes> element.");
  const nodes = [...nodesElement.querySelectorAll(":scope > node")].map((element) => {
    const id = requiredAttribute(element, "id", "A node");
    const name = requiredAttribute(element, "name", `Node ${id}`);
    const kind = requiredAttribute(element, "kind", `Node ${id}`);
    if (!NODE_KINDS.has(kind)) throw new Error(`Node ${id} has an unsupported kind: ${kind}.`);
    const fields = [...element.querySelectorAll(":scope > field")].map((field) => ({
      name: requiredAttribute(field, "name", `A field on node ${id}`),
      type: requiredAttribute(field, "type", `A field on node ${id}`)
    }));
    return { id, name, kind, x: coordinate(element, "x", id), y: coordinate(element, "y", id), fields };
  });
  if (!nodes.length) throw new Error("A diagram requires at least one node.");
  const nodeIDs = new Set(nodes.map((node) => node.id));
  if (nodeIDs.size !== nodes.length) throw new Error("Node IDs must be unique.");
  const relationshipsElement = diagram.querySelector(":scope > relationships");
  if (!relationshipsElement) throw new Error("A diagram requires a <relationships> element.");
  const relationships = [...relationshipsElement.querySelectorAll(":scope > relationship")].map((element) => {
    const from = requiredAttribute(element, "from", "A relationship");
    const to = requiredAttribute(element, "to", "A relationship");
    const type = requiredAttribute(element, "type", "A relationship");
    if (!nodeIDs.has(from) || !nodeIDs.has(to)) throw new Error(`Relationship ${type} references an unknown node.`);
    return { from, to, type };
  });
  return { title, owner, creatorID, version, nodes, relationships };
}

function esc(value) { return String(value).replace(/[&<>'"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[c])); }
function nodeMarkup(node) {
  const color = COLORS[node.kind] || COLORS.entity;
  const fields = node.fields.length ? node.fields.map((f) => `<div class="field"><span>${esc(f.name)}</span><code>${esc(f.type)}</code></div>`).join("") : `<div class="empty">No fields</div>`;
  return `<article class="node" style="left:${node.x}px;top:${node.y}px"><header><i style="background:${color}"></i><strong>${esc(node.name)}</strong><small>${esc(node.kind)}</small></header><section>${fields}</section></article>`;
}

const BaseElement = globalThis.HTMLElement || class {};

/** A generic, read-only ArcMark renderer. Set `src` or assign XML to `data`. The component renders the model visually and does not expose the raw `.arc` source; `data` returns the parsed model, not the input XML. */
export class ArcMarkDiagram extends BaseElement {
  static get observedAttributes() { return ["src", "title"]; }
  constructor() { super(); this.attachShadow({ mode: "open" }); this._model = null; }
  connectedCallback() { this._render(); if (this.src) this.load(this.src); }
  attributeChangedCallback(name, oldValue, newValue) { if (name === "src" && newValue && newValue !== oldValue) this.load(newValue); else if (name === "title") this._render(); }
  get src() { return this.getAttribute("src"); }
  set src(value) { this.setAttribute("src", value); }
  get data() { return this._model; }
  set data(xml) { try { this._model = parseArcMark(xml); this._render(); this.dispatchEvent(new CustomEvent("arcmark-load", { detail: this._model })); } catch (error) { this._error = error; this._render(); this.dispatchEvent(new CustomEvent("arcmark-error", { detail: error })); } }
  async load(url) { try { const response = await fetch(url); if (!response.ok) throw new Error(`Could not load ${url} (${response.status}).`); this.data = await response.text(); } catch (error) { this._error = error; this._render(); this.dispatchEvent(new CustomEvent("arcmark-error", { detail: error })); } }
  _render() {
    const model = this._model;
    const nodes = model?.nodes || [];
    const maxX = Math.max(640, ...nodes.map((n) => n.x + 190)); const maxY = Math.max(360, ...nodes.map((n) => n.y + 150));
    const byID = new Map(nodes.map((n) => [n.id, n]));
    const lines = (model?.relationships || []).map((r) => { const a = byID.get(r.from), b = byID.get(r.to); if (!a || !b) return ""; const x1 = a.x + 190, y1 = a.y + 52, x2 = b.x, y2 = b.y + 52, labelX = (x1 + x2) / 2, labelY = (y1 + y2) / 2 - 8; return `<path marker-end="url(#arrow)" d="M${x1} ${y1} C${x1 + 60} ${y1}, ${x2 - 60} ${y2}, ${x2} ${y2}"/><text x="${labelX}" y="${labelY}">${esc(r.type)}</text>`; }).join("");
    this.shadowRoot.innerHTML = `<style>:host{display:block;font-family:ui-sans-serif,system-ui,sans-serif;color:#172033;-webkit-user-select:none;user-select:none}.wrap{overflow:auto;border:1px solid #dbe1eb;border-radius:12px;background:#f7f9fc}.title{padding:13px 16px;background:white;border-bottom:1px solid #dbe1eb;font-size:14px;font-weight:700}.owner{display:block;margin-top:3px;font-size:11px;font-weight:600;color:#718096}.canvas{position:relative;min-width:${maxX}px;min-height:${maxY}px;background-image:radial-gradient(#ccd5e1 1px,transparent 1px);background-size:24px 24px}.edges{position:absolute;inset:0;overflow:visible;width:100%;height:100%;pointer-events:none}.edges path{fill:none;stroke:#6876a6;stroke-width:2;stroke-dasharray:6 5}.edges text{font-size:12px;fill:#4c576f;text-anchor:middle}.node{position:absolute;width:188px;background:#fff;border:1px solid #dbe1eb;border-radius:9px;box-shadow:0 4px 12px #17203318;overflow:hidden}.node header{display:flex;align-items:center;gap:7px;padding:10px;border-bottom:1px solid #edf0f5;font-size:13px}.node header i{width:8px;height:8px;border-radius:50%;flex:none}.node header strong{overflow:hidden;text-overflow:ellipsis;white-space:nowrap}.node header small{margin-left:auto;color:#718096;font-size:9px;text-transform:uppercase}.node section{padding:8px 10px}.field{display:flex;justify-content:space-between;gap:6px;padding:3px 0;font-size:12px}.field code{color:#667085;font-size:11px}.empty{font-size:12px;color:#98a2b3}.error{padding:24px;color:#b42318;background:#fff5f4}</style><div class="wrap">${this._error ? `<div class="error">${esc(this._error.message)}</div>` : `<div class="title">${esc(this.getAttribute("title") || model?.title || "ArcMark Diagram")}${model?.owner ? `<span class="owner">Owner: ${esc(model.owner)}</span>` : ""}</div><div class="canvas"><svg class="edges" viewBox="0 0 ${maxX} ${maxY}" preserveAspectRatio="none"><defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#6876a6"/></marker></defs>${lines}</svg>${nodes.map(nodeMarkup).join("")}</div>`}</div>`;
  }
}

if (globalThis.customElements && !customElements.get("arcmark-diagram")) customElements.define("arcmark-diagram", ArcMarkDiagram);
