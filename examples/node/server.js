// A dependency-free static file server that demonstrates loading
// @caraveo/arcmark-viewer and a .arc document in a browser.
//
// Run:  npm start   (then open http://localhost:4321)
//
// It serves three things:
//   /                      -> index.html (uses the web component)
//   /arcmark-viewer.js     -> the installed viewer module
//   /commerce.arc          -> the example ArcMark document
//
// No external dependencies are required; this uses only Node built-ins.

import { createServer } from "node:http";
import { readFile } from "node:fs/promises";
import { extname, resolve, dirname } from "node:path";
import { fileURLToPath } from "node:url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = process.env.PORT ? Number(process.env.PORT) : 4321;

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".arc": "application/xml; charset=utf-8",
  ".svg": "image/svg+xml; charset=utf-8",
};

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

const viewerPath = resolve(__dirname, "node_modules/@caraveo/arcmark-viewer/src/arcmark-viewer.js");

const server = createServer(async (req, res) => {
  const url = new URL(req.url, `http://localhost:${PORT}`);
  const path = url.pathname;

  if (path === "/" || path === "/index.html") return sendFile(res, resolve(__dirname, "index.html"));
  if (path === "/arcmark-viewer.js") return sendFile(res, viewerPath);
  if (path === "/commerce.arc") return sendFile(res, resolve(__dirname, "..", "commerce.arc"));

  res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
  res.end("Not found");
});

server.listen(PORT, () => {
  console.log(`ArcMark Node example running at http://localhost:${PORT}`);
  console.log("Open the URL in a browser to see the Commerce Domain diagram.");
});