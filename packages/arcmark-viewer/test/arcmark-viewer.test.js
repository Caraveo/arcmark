import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import test from "node:test";
import { DOMParser } from "linkedom";

globalThis.DOMParser = DOMParser;

const { parseArcMark } = await import("../src/arcmark-viewer.js");

test("parses a complete ArcMark Standard document", () => {
  const model = parseArcMark(`<?xml version="1.0" encoding="UTF-8"?>
<arcmark version="1.1.0">
  <diagram title="Commerce Domain" owner="Commerce Team" creator-id="u_jon">
    <nodes>
      <node id="customer" name="Customer" kind="entity" x="120" y="80">
        <field name="customerId" type="UUID"/>
      </node>
      <node id="billing" name="Billing Service" kind="service" x="420" y="80"/>
    </nodes>
    <relationships>
      <relationship from="customer" to="billing" type="charges"/>
    </relationships>
  </diagram>
</arcmark>`);

  assert.equal(model.title, "Commerce Domain");
  assert.equal(model.version, "1.1.0");
  assert.equal(model.owner, "Commerce Team");
  assert.equal(model.creatorID, "u_jon");
  assert.deepEqual(model.nodes, [
    {
      id: "customer",
      name: "Customer",
      kind: "entity",
      x: 120,
      y: 80,
      fields: [{ name: "customerId", type: "UUID" }]
    },
    {
      id: "billing",
      name: "Billing Service",
      kind: "service",
      x: 420,
      y: 80,
      fields: []
    }
  ]);
  assert.deepEqual(model.relationships, [{ from: "customer", to: "billing", type: "charges" }]);
});

test("rejects a document without an ArcMark root", () => {
  assert.throws(
    () => parseArcMark("<diagram title=\"Not ArcMark\"/>") ,
    /Expected an ArcMark document/
  );
});

test("rejects unsupported versions and broken relationship references", () => {
  assert.throws(
    () => parseArcMark("<arcmark version=\"2.0.0\"><diagram title=\"Future\"><nodes><node id=\"a\" name=\"A\" kind=\"entity\" x=\"0\" y=\"0\"/></nodes><relationships/></diagram></arcmark>"),
    /Unsupported ArcMark version/
  );
  assert.throws(
    () => parseArcMark("<arcmark version=\"1.0.0\"><diagram title=\"Broken\"><nodes><node id=\"a\" name=\"A\" kind=\"entity\" x=\"0\" y=\"0\"/></nodes><relationships><relationship from=\"a\" to=\"missing\" type=\"calls\"/></relationships></diagram></arcmark>"),
    /unknown node/
  );
  assert.throws(
    () => parseArcMark("<arcmark version=\"1.0.0\"><diagram title=\"First\"><nodes><node id=\"a\" name=\"A\" kind=\"entity\" x=\"0\" y=\"0\"/></nodes><relationships/></diagram><diagram title=\"Second\"><nodes><node id=\"b\" name=\"B\" kind=\"entity\" x=\"0\" y=\"0\"/></nodes><relationships/></diagram></arcmark>"),
    /exactly one/
  );
});

test("parses the checked-in Commerce Domain example", () => {
  const exampleURL = new URL("../../../examples/commerce.arc", import.meta.url);
  const model = parseArcMark(readFileSync(fileURLToPath(exampleURL), "utf8"));

  assert.equal(model.title, "Commerce Domain");
  assert.equal(model.version, "1.1.0");
  assert.equal(model.owner, "Commerce Team");
  assert.equal(model.creatorID, "u_jon");
  assert.equal(model.nodes.length, 5);
  assert.equal(model.relationships.length, 5);
});
