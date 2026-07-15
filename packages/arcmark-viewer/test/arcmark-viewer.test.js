import assert from "node:assert/strict";
import test from "node:test";
import { DOMParser } from "linkedom";

globalThis.DOMParser = DOMParser;

const { parseArcMark } = await import("../src/arcmark-viewer.js");

test("parses a complete ArcMark Standard document", () => {
  const model = parseArcMark(`<?xml version="1.0" encoding="UTF-8"?>
<arcmark version="1.0.0">
  <diagram title="Commerce Domain">
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
