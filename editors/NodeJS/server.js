// A dependency-free local web server for the ArcMark editor.
//
// Run:  npm start        (then open http://localhost:4200)
//       npm run launch   (opens the browser automatically)
//
// Serves:
//   /                          -> public/index.html (the editor UI)
//   /public/*                  -> editor static assets
//   /viewer/arcmark-viewer.js  -> the installed @caraveo/arcmark-viewer module
//   /api/diagrams              -> GET list / POST save .arc files in ./diagrams
//
// Uses only Node built-ins; no runtime dependencies on the server side.

import { createServer } from "node:http";
import { readFile, writeFile, readdir, mkdir } from "node:fs/promises";
import { existsSync } from "node:fs";
import { extname, resolve, dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT ? Number(process.env.PORT) : 4200;
const DIAGRAMS_DIR = resolve(__dirname, "diagrams");

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".arc": "application/xml; charset=utf-8",
  ".svg": "image/svg+xml; charset=utf-8",
  ".png": "image/png",
  ".json": "application/json; charset=utf-8",
};

function viewerPath() {
  return resolve(__dirname, "node_modules/@caraveo/arcmark-viewer/src/arcmark-viewer.js");
}

async function sendFile(res, path, fallbackType) {
  try {
    const data = await readFile(path);
    res.writeHead(200, { "Content-Type": TYPES[extname(path)] || fallbackType || "application/octet-stream" });
    res.end(data);
  } catch {
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
  }
}

async function readBody(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  return Buffer.concat(chunks).toString("utf8");
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const pathname = url.pathname;

  try {
    if (pathname === "/" || pathname === "/index.html") {
      return await sendFile(res, resolve(__dirname, "public/index.html"));
    }
    if (pathname === "/viewer/arcmark-viewer.js") {
      return await sendFile(res, viewerPath());
    }
    if (pathname === "/api/diagrams" && req.method === "GET") {
      if (!existsSync(DIAGRAMS_DIR)) await mkdir(DIAGRAMS_DIR, { recursive: true });
      const files = await readdir(DIAGRAMS_DIR);
      const arcs = files.filter((f) => f.endsWith(".arc"));
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      return res.end(JSON.stringify(arcs));
    }
    if (pathname === "/api/diagrams" && req.method === "POST") {
      if (!existsSync(DIAGRAMS_DIR)) await mkdir(DIAGRAMS_DIR, { recursive: true });
      const body = JSON.parse(await readBody(req));
      const name = (body.name || "diagram").trim().replace(/\.arc$/i, "");
      const safe = name.replace(/[^A-Za-z0-9._-]+/g, "_");
      const path = join(DIAGRAMS_DIR, `${safe}.arc`);
      await writeFile(path, body.xml, "utf8");
      res.writeHead(200, { "Content-Type": "application/json; charset=utf-8" });
      return res.end(JSON.stringify({ ok: true, path: safe + ".arc" }));
    }
    if (pathname.startsWith("/api/diagrams/") && req.method === "GET") {
      const name = decodeURIComponent(pathname.slice("/api/diagrams/".length));
      const path = join(DIAGRAMS_DIR, name.endsWith(".arc") ? name : `${name}.arc`);
      return await sendFile(res, path);
    }
    if (pathname.startsWith("/public/")) {
      return await sendFile(res, resolve(__dirname, pathname.slice(1)));
    }
    res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("Not found");
  } catch (error) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end(`Server error: ${error.message}`);
  }
});

server.listen(PORT, "127.0.0.1", async () => {
  if (!existsSync(DIAGRAMS_DIR)) await mkdir(DIAGRAMS_DIR, { recursive: true });
  const uri = `http://localhost:${PORT}`;
  console.log(`ArcMark editor running at ${uri}`);
  if (process.argv.includes("--open")) {
    try { const { default: open } = await import("node:child_process").then(() => ({})); } catch {}
    try {
      const { exec } = await import("node:child_process");
      exec(process.platform === "darwin" ? `open ${uri}` : process.platform === "win32" ? `start ${uri}` : `xdg-open ${uri}`);
    } catch {}
  }
});