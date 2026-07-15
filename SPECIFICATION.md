# ArcMark Diagram Format 1.0

## Status

This document defines ArcMark 1.0, an XML-based interchange format for UML-inspired system diagrams. An ArcMark document MUST use the `.arc` filename extension and SHOULD use UTF-8 encoding. It is validated by `arcmark.xsd`.

## Identifier and file association

| Item | Value |
| --- | --- |
| Filename extension | `.arc` |
| Uniform Type Identifier | `com.arcmark.diagram` |
| Conforms to | `public.xml` |
| Root element | `arcmark` |
| Current version | `1.0` |

The `.arc` suffix identifies an ArcMark diagram, not a generic XML file. The underlying syntax is XML for compatibility with standard validators and tooling.

## Document structure

```xml
<?xml version="1.0" encoding="UTF-8"?>
<arcmark version="1.0">
  <diagram title="Commerce Domain">
    <nodes>
      <node id="n_customer" name="Customer" kind="entity" x="180" y="220">
        <field name="customerId" type="UUID"/>
        <field name="email" type="String"/>
      </node>
    </nodes>
    <relationships>
      <relationship from="n_customer" to="n_order" type="places"/>
    </relationships>
  </diagram>
</arcmark>
```

## Semantics

`arcmark` is the document root. Its required `version` attribute specifies the ArcMark format version.

`diagram` contains one model and has the required user-facing `title` attribute.

`nodes` contains one or more `node` elements. A node has a globally unique XML `id`, `name`, a `kind`, and canvas coordinates `x` and `y`. Valid kinds are `entity`, `service`, and `event`.

`field` is optional and can occur zero or more times under a node. Its `name` and `type` attributes describe a property, operation, or payload item.

`relationships` contains zero or more directed `relationship` elements. `from` and `to` are required ID references to nodes; `type` is a required relationship label such as `places`, `calls`, or `emits`. Renderers MUST treat `from` as the source and `to` as the destination; the visual direction is shown with an arrowhead at `to`.

## Compatibility rules

- Readers MUST reject a document with a root other than `arcmark`.
- Readers MUST support the three ArcMark 1.0 node kinds.
- Readers SHOULD preserve unknown attributes and elements when possible to support forward compatibility.
- Coordinates are decimal canvas units, with the top-left canvas origin at `(0, 0)`.
- IDs MUST be XML `ID` values and relationship endpoints MUST resolve to defined node IDs.

## Schema

The authoritative XSD is [arcmark.xsd](Sources/ArcMarkStudio/Resources/arcmark.xsd). Tools can validate a `.arc` file using any XML Schema 1.0-compatible validator.
