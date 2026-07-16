// ArcMark editor — authoring logic for ArcMark Standard v1.1.0 .arc documents.
// Dependency-free vanilla JS. Renders a draggable node canvas, draws directed
// relationships, and drives a live <arcmark-diagram> preview of the document.

const KIND_COLORS = { entity: "#23b8d4", service: "#8b5cf6", event: "#f59e0b" };
const CARD_W = 160;
const CARD_H = 48;

const state = {
  title: "Untitled Diagram",
  owner: "",
  creatorID: "",
  nodes: [],     // { id, name, kind, x, y, fields: [{name,type}] }
  rels: [],      // { id, from, to, type }
  selected: null,
  connectSource: null,
};

const $ = (id) => document.getElementById(id);
const uid = () => "n" + Math.random().toString(36).slice(2, 10);

const canvas = $("canvas");
const preview = $("preview");

// ---------- serialization ----------
function esc(s) {
  return String(s).replace(/[&<>'"]/g, (c) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", "'": "&#39;", '"': "&quot;" }[c]));
}
function toXML() {
  const ns = state.nodes.map((n) => {
    const fields = n.fields.map((f) => `      <field name="${esc(f.name)}" type="${esc(f.type)}"/>`).join("\n");
    return `    <node id="${esc(n.id)}" name="${esc(n.name)}" kind="${n.kind}" x="${n.x}" y="${n.y}">\n${fields}\n    </node>`;
  }).join("\n");
  const rs = state.rels.map((r) => `    <relationship from="${esc(r.from)}" to="${esc(r.to)}" type="${esc(r.type)}"/>`).join("\n");
  const owner = state.owner.trim() ? ` owner="${esc(state.owner)}"` : "";
  const creator = state.creatorID.trim() ? ` creator-id="${esc(state.creatorID)}"` : "";
  return `<?xml version="1.0" encoding="UTF-8"?>
<arcmark version="1.1.0">
  <diagram title="${esc(state.title)}"${owner}${creator}>
  <nodes>
${ns}
  </nodes>
  <relationships>
${rs}
  </relationships>
  </diagram>
</arcmark>`;
}

// ---------- parsing (import) ----------
function parseArc(xml) {
  const doc = new DOMParser().parseFromString(xml, "application/xml");
  if (doc.querySelector("parsererror")) throw new Error("The file is not valid XML.");
  const root = doc.documentElement;
  if (root?.tagName !== "arcmark") throw new Error("Expected an <arcmark> root element.");
  const version = root.getAttribute("version");
  if (!["1.0.0", "1.1.0"].includes(version)) throw new Error(`Unsupported ArcMark version ${version}.`);
  const diagram = [...root.querySelectorAll(":scope > diagram")][0];
  if (!diagram) throw new Error("The document has no <diagram>.");
  const title = diagram.getAttribute("title") || "ArcMark Diagram";
  const owner = diagram.getAttribute("owner") || "";
  const creatorID = diagram.getAttribute("creator-id") || "";
  const nodes = [...(diagram.querySelector(":scope > nodes") || [])].filter((el) => el.tagName === "node").map((el) => {
    const id = el.getAttribute("id") || uid();
    return {
      id, name: el.getAttribute("name") || "Node", kind: el.getAttribute("kind") || "entity",
      x: Number(el.getAttribute("x")) || 0, y: Number(el.getAttribute("y")) || 180,
      fields: [...el.querySelectorAll(":scope > field")].map((f) => ({ name: f.getAttribute("name") || "", type: f.getAttribute("type") || "" })),
    };
  });
  const relsEl = diagram.querySelector(":scope > relationships");
  const rels = relsEl ? [...relsEl.querySelectorAll(":scope > relationship")].map((r, i) => ({
    id: "r" + i, from: r.getAttribute("from"), to: r.getAttribute("to"), type: r.getAttribute("type") || "relates to",
  })) : [];
  return { title, owner, creatorID, nodes, rels };
}

// ---------- rendering the canvas ----------
function renderCanvas() {
  canvas.innerHTML = "";
  const layer = document.createElementNS("http://www.w3.org/2000/svg", "svg");
  layer.setAttribute("class", "edge-layer");
  const maxX = Math.max(900, ...state.nodes.map((n) => n.x + CARD_W + 40));
  const maxY = Math.max(560, ...state.nodes.map((n) => n.y + CARD_H + 80));
  layer.setAttribute("viewBox", `0 0 ${maxX} ${maxY}`);
  layer.setAttribute("preserveAspectRatio", "none");
  const byID = new Map(state.nodes.map((n) => [n.id, n]));
  for (const r of state.rels) {
    const a = byID.get(r.from), b = byID.get(r.to);
    if (!a || !b) continue;
    const x1 = a.x + CARD_W, y1 = a.y + 26, x2 = b.x, y2 = b.y + 26;
    const path = document.createElementNS("http://www.w3.org/2000/svg", "path");
    path.setAttribute("marker-end", "url(#ea)");
    path.setAttribute("d", `M${x1} ${y1} C${x1 + 50} ${y1}, ${x2 - 50} ${y2}, ${x2} ${y2}`);
    layer.appendChild(path);
    const text = document.createElementNS("http://www.w3.org/2000/svg", "text");
    text.setAttribute("x", (x1 + x2) / 2); text.setAttribute("y", (y1 + y2) / 2 - 6);
    text.textContent = r.type;
    layer.appendChild(text);
  }
  const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
  defs.innerHTML = `<marker id="ea" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z" fill="#4f46e5"/></marker>`;
  layer.appendChild(defs);
  canvas.appendChild(layer);

  for (const n of state.nodes) {
    const card = document.createElement("div");
    card.className = "node-card" + (state.selected === n.id ? " selected" : "") + (state.connectSource === n.id ? " connecting-source" : "");
    card.style.left = n.x + "px"; card.style.top = n.y + "px";
    const fields = n.fields.length
      ? n.fields.map((f) => `<div class="field-row"><span>${esc(f.name)}</span><span class="ftype">${esc(f.type)}</span></div>`).join("")
      : `<div class="empty-f">No fields</div>`;
    card.innerHTML = `<header><span class="dot" style="background:${KIND_COLORS[n.kind]}"></span><span class="name">${esc(n.name)}</span><span class="kind">${n.kind}</span></header><div class="fields">${fields}</div>`;
    card.dataset.id = n.id;
    canvas.appendChild(card);
  }
  layer.style.width = maxX + "px"; layer.style.height = maxY + "px";
  refreshControls();
}

function renderSidebar() {
  $("titleInput").value = state.title;
  $("ownerInput").value = state.owner;
  $("creatorInput").value = state.creatorID;
  const list = $("nodeList");
  list.innerHTML = "";
  for (const n of state.nodes) {
    const li = document.createElement("li");
    if (state.selected === n.id) li.className = "selected";
    li.innerHTML = `<span class="dot" style="background:${KIND_COLORS[n.kind]}"></span><span class="name">${esc(n.name)}</span><span class="kind">${n.kind}</span>`;
    li.dataset.id = n.id;
    list.appendChild(li);
  }
}

function renderInspector() {
  const node = state.nodes.find((n) => n.id === state.selected);
  const insp = $("inspector");
  if (!node) {
    insp.innerHTML = `<div class="empty">Select a node to edit it.</div><div class="field-group"><label>Document owner</label><input id="iOwner" type="text" value="${esc(state.owner)}" /></div><div class="field-group"><label>Creator ID</label><input id="iCreator" type="text" value="${esc(state.creatorID)}" /></div>`;
    const io = $("iOwner"), ic = $("iCreator");
    if (io) io.addEventListener("input", () => { state.owner = io.value; $("ownerInput").value = io.value; updatePreview(); });
    if (ic) ic.addEventListener("input", () => { state.creatorID = ic.value; $("creatorInput").value = ic.value; updatePreview(); });
    return;
  }
  const fields = node.fields.map((f, i) => `<div class="field-row-editor"><input data-fi="${i}" data-prop="name" type="text" value="${esc(f.name)}" placeholder="name" /><input class="ftype" data-fi="${i}" data-prop="type" type="text" value="${esc(f.type)}" placeholder="type" /><button data-del-field="${i}" type="button">✕</button></div>`).join("");
  insp.innerHTML = `
    <div class="field-group"><label>Name</label><input id="iName" type="text" value="${esc(node.name)}" /></div>
    <div class="field-group"><label>Kind</label><select id="iKind"><option ${node.kind === "entity" ? "selected" : ""}>entity</option><option ${node.kind === "service" ? "selected" : ""}>service</option><option ${node.kind === "event" ? "selected" : ""}>event</option></select></div>
    <div class="field-group"><label>Fields</label>${fields}<button class="add-field" id="addField" type="button">+ Add field</button></div>
    <button class="delete-doc" id="deleteNode" type="button">Delete node</button>`;
  $("iName").addEventListener("input", (e) => { node.name = e.target.value; renderCanvas(); renderSidebar(); updatePreview(); });
  $("iKind").addEventListener("change", (e) => { node.kind = e.target.value; renderCanvas(); renderSidebar(); updatePreview(); });
  insp.querySelectorAll("[data-prop]").forEach((el) => el.addEventListener("input", (e) => { node.fields[+e.target.dataset.fi][e.target.dataset.prop] = e.target.value; renderCanvas(); updatePreview(); }));
  insp.querySelectorAll("[data-del-field]").forEach((el) => el.addEventListener("click", (e) => { node.fields.splice(+e.target.dataset.delField, 1); renderInspector(); renderCanvas(); updatePreview(); }));
  $("addField").addEventListener("click", () => { node.fields.push({ name: "field", type: "String" }); renderInspector(); renderCanvas(); updatePreview(); });
  $("deleteNode").addEventListener("click", () => deleteSelected());
}

function refreshControls() {
  const has = state.selected !== null;
  $("connectBtn").disabled = !has;
  $("deleteBtn").disabled = !has;
  const hint = $("hint");
  if (state.connectSource) { hint.textContent = "Now click the destination node"; hint.classList.add("connecting"); }
  else { hint.textContent = "Drag nodes · Click a node then Connect to link it"; hint.classList.remove("connecting"); }
}

// ---------- preview ----------
let previewTimer;
function updatePreview() {
  clearTimeout(previewTimer);
  previewTimer = setTimeout(() => {
    if (!state.nodes.length) { preview.removeAttribute("src"); try { preview._model = null; preview._render(); } catch {} return; }
    try { preview.data = toXML(); } catch {}
  }, 80);
}

function renderAll() { renderCanvas(); renderSidebar(); renderInspector(); updatePreview(); }

// ---------- mutations ----------
function addNode(kind) {
  const n = { id: uid(), name: `New ${kind[0].toUpperCase() + kind.slice(1)}`, kind, x: 280 + Math.round(Math.random() * 200), y: 180 + Math.round(Math.random() * 160), fields: [] };
  state.nodes.push(n); state.selected = n.id; renderAll();
}
function deleteSelected() {
  if (!state.selected) return;
  const id = state.selected;
  state.nodes = state.nodes.filter((n) => n.id !== id);
  state.rels = state.rels.filter((r) => r.from !== id && r.to !== id);
  state.selected = null; state.connectSource = null; renderAll();
}
function selectNode(id) { state.selected = id; state.connectSource = null; renderAll(); }

// ---------- canvas interactions ----------
canvas.addEventListener("mousedown", (e) => {
  const card = e.target.closest(".node-card");
  if (!card) { if (!state.connectSource) selectNode(null); return; }
  const id = card.dataset.id;
  if (state.connectSource && state.connectSource !== id) {
    state.rels.push({ id: uid(), from: state.connectSource, to: id, type: "relates to" });
    state.connectSource = null; renderAll(); return;
  }
  selectNode(id);
  const node = state.nodes.find((n) => n.id === id);
  const startX = e.clientX, startY = e.clientY, ox = node.x, oy = node.y;
  const onMove = (ev) => { node.x = Math.max(0, ox + ev.clientX - startX); node.y = Math.max(0, oy + ev.clientY - startY); card.style.left = node.x + "px"; card.style.top = node.y + "px"; };
  const onUp = () => { document.removeEventListener("mousemove", onMove); document.removeEventListener("mouseup", onUp); renderCanvas(); updatePreview(); };
  document.addEventListener("mousemove", onMove); document.addEventListener("mouseup", onUp);
});

$("nodeList").addEventListener("click", (e) => { const li = e.target.closest("li"); if (li) selectNode(li.dataset.id); });
document.querySelectorAll("[data-kind]").forEach((b) => b.addEventListener("click", () => addNode(b.dataset.kind)));
$("connectBtn").addEventListener("click", () => { if (state.selected) { state.connectSource = state.selected; refreshControls(); } });
$("deleteBtn").addEventListener("click", deleteSelected);

// ---------- document meta inputs ----------
$("titleInput").addEventListener("input", (e) => { state.title = e.target.value; updatePreview(); });
$("ownerInput").addEventListener("input", (e) => { state.owner = e.target.value; renderInspector(); updatePreview(); });
$("creatorInput").addEventListener("input", (e) => { state.creatorID = e.target.value; renderInspector(); updatePreview(); });

// ---------- new / open / save ----------
function newDoc() {
  Object.assign(state, { title: "Untitled Diagram", owner: "", creatorID: "", nodes: [], rels: [], selected: null, connectSource: null });
  renderAll();
}

$("newBtn").addEventListener("click", newDoc);

$("openBtn").addEventListener("click", () => $("fileInput").click());
$("fileInput").addEventListener("change", (e) => {
  const file = e.target.files[0]; if (!file) return;
  const reader = new FileReader();
  reader.onload = () => {
    try {
      const d = parseArc(reader.result);
      Object.assign(state, { title: d.title, owner: d.owner, creatorID: d.creatorID, nodes: d.nodes, rels: d.rels, selected: null, connectSource: null });
      renderAll();
    } catch (err) { alert("Could not open .arc: " + err.message); }
  };
  reader.readAsText(file);
  e.target.value = "";
});

$("saveBtn").addEventListener("click", () => {
  const blob = new Blob([toXML()], { type: "application/xml" });
  const a = document.createElement("a");
  a.href = URL.createObjectURL(blob);
  a.download = `${(state.title || "diagram").trim()}.arc`;
  a.click(); URL.revokeObjectURL(a.href);
});

$("saveToServerBtn").addEventListener("click", async () => {
  try {
    const res = await fetch("/api/diagrams", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify({ name: state.title, xml: toXML() }) });
    const out = await res.json();
    alert(`Saved to diagrams/${out.path}`);
  } catch (err) { alert("Save failed: " + err.message); }
});

// seed with the bundled commerce domain from the viewer dev area, then render
async function seed() {
  try {
    const res = await fetch("/viewer/arcmark-viewer.js"); // no-op availability check for viewer
    if (!res.ok) throw new Error("viewer missing");
  } catch {}
  // start empty so users get a blank canvas; preview handles empty documents gracefully
  renderAll();
}

seed();