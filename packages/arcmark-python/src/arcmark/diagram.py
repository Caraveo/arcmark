"""Parser and generic SVG renderer for ArcMark 1.0 diagrams."""

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path
from xml.etree import ElementTree as ET
from html import escape


class ArcMarkError(ValueError):
    """Raised when an ArcMark document is malformed or incompatible."""


@dataclass(frozen=True)
class ArcMarkField:
    name: str
    type: str


@dataclass(frozen=True)
class ArcMarkNode:
    id: str
    name: str
    kind: str
    x: float
    y: float
    fields: tuple[ArcMarkField, ...] = ()


@dataclass(frozen=True)
class ArcMarkRelationship:
    from_id: str
    to_id: str
    type: str


@dataclass(frozen=True)
class ArcMarkDiagram:
    """An immutable ArcMark diagram with file/XML readers and SVG output."""

    title: str
    nodes: tuple[ArcMarkNode, ...]
    relationships: tuple[ArcMarkRelationship, ...]
    version: str = "1.0.0"

    @classmethod
    def from_file(cls, path: str | Path) -> "ArcMarkDiagram":
        """Read a UTF-8 `.arc` document from disk."""
        return cls.from_xml(Path(path).read_text(encoding="utf-8"))

    @classmethod
    def from_xml(cls, xml: str) -> "ArcMarkDiagram":
        """Parse and validate the structural requirements of ArcMark 1.0."""
        try:
            root = ET.fromstring(xml)
        except ET.ParseError as error:
            raise ArcMarkError(f"Invalid XML: {error}") from error
        if root.tag != "arcmark":
            raise ArcMarkError("Expected an <arcmark> root element.")
        version = root.get("version")
        if not version:
            raise ArcMarkError("The <arcmark> element requires a version.")
        diagram = root.find("diagram")
        if diagram is None or not diagram.get("title"):
            raise ArcMarkError("Expected a <diagram> with a title.")
        nodes_element = diagram.find("nodes")
        if nodes_element is None:
            raise ArcMarkError("A diagram requires a <nodes> element.")
        nodes: list[ArcMarkNode] = []
        allowed_kinds = {"entity", "service", "event"}
        for element in nodes_element.findall("node"):
            attrs = element.attrib
            missing = [name for name in ("id", "name", "kind", "x", "y") if not attrs.get(name)]
            if missing:
                raise ArcMarkError(f"Node is missing required attribute(s): {', '.join(missing)}.")
            if attrs["kind"] not in allowed_kinds:
                raise ArcMarkError(f"Unsupported node kind: {attrs['kind']}.")
            try:
                x, y = float(attrs["x"]), float(attrs["y"])
            except ValueError as error:
                raise ArcMarkError(f"Node {attrs['id']} has non-numeric coordinates.") from error
            fields = tuple(ArcMarkField(field.get("name", ""), field.get("type", "")) for field in element.findall("field"))
            if any(not field.name or not field.type for field in fields):
                raise ArcMarkError(f"Node {attrs['id']} has a field missing a name or type.")
            nodes.append(ArcMarkNode(attrs["id"], attrs["name"], attrs["kind"], x, y, fields))
        ids = {node.id for node in nodes}
        if len(ids) != len(nodes):
            raise ArcMarkError("Node IDs must be unique.")
        relationships_element = diagram.find("relationships")
        relationships: list[ArcMarkRelationship] = []
        if relationships_element is not None:
            for element in relationships_element.findall("relationship"):
                from_id, to_id, relation_type = element.get("from"), element.get("to"), element.get("type")
                if not from_id or not to_id or not relation_type:
                    raise ArcMarkError("Every relationship requires from, to, and type attributes.")
                if from_id not in ids or to_id not in ids:
                    raise ArcMarkError(f"Relationship {relation_type} references an unknown node.")
                relationships.append(ArcMarkRelationship(from_id, to_id, relation_type))
        return cls(diagram.attrib["title"], tuple(nodes), tuple(relationships), version)

    def to_svg(self) -> str:
        """Render a portable, self-contained SVG suitable for an HTML response or file."""
        colors = {"entity": "#23b8d4", "service": "#8b5cf6", "event": "#f59e0b"}
        width = max(720, int(max((node.x + 220 for node in self.nodes), default=720)))
        height = max(420, int(max((node.y + 170 for node in self.nodes), default=420)))
        lookup = {node.id: node for node in self.nodes}
        edges = []
        for relationship in self.relationships:
            source, target = lookup[relationship.from_id], lookup[relationship.to_id]
            x1, y1, x2, y2 = source.x + 200, source.y + 58, target.x, target.y + 58
            edges.append(f'<path marker-end="url(#arrow)" d="M{x1} {y1} C{x1 + 70} {y1}, {x2 - 70} {y2}, {x2} {y2}"/><text x="{(x1+x2)/2}" y="{(y1+y2)/2-9}">{escape(relationship.type)}</text>')
        cards = []
        for node in self.nodes:
            color = colors.get(node.kind, colors["entity"])
            field_rows = "".join(f'<text class="field" x="{node.x+12}" y="{node.y+92+i*19}">{escape(field.name)} <tspan>{escape(field.type)}</tspan></text>' for i, field in enumerate(node.fields)) or f'<text class="empty" x="{node.x+12}" y="{node.y+92}">No fields</text>'
            card_height = max(116, 82 + len(node.fields) * 19)
            cards.append(f'<g><rect class="card" x="{node.x}" y="{node.y}" width="200" height="{card_height}" rx="9"/><circle cx="{node.x+15}" cy="{node.y+21}" r="4" fill="{color}"/><text class="name" x="{node.x+26}" y="{node.y+25}">{escape(node.name)}</text><text class="kind" x="{node.x+188}" y="{node.y+25}">{escape(node.kind.upper())}</text><path class="rule" d="M{node.x} {node.y+42}H{node.x+200}"/>{field_rows}</g>')
        edge_markup = "".join(f'<g class="edge">{edge}</g>' for edge in edges)
        return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {width} {height}" width="{width}" height="{height}" role="img" aria-label="{escape(self.title)}"><defs><marker id="arrow" viewBox="0 0 10 10" refX="8" refY="5" markerWidth="7" markerHeight="7" orient="auto"><path d="M 0 0 L 10 5 L 0 10 z" fill="#6876a6"/></marker></defs><style>.bg{{fill:#f7f9fc}}.edge{{fill:none;stroke:#6876a6;stroke-width:2;stroke-dasharray:6 5}}text{{font-family:system-ui,sans-serif;fill:#4c576f;font-size:12px;text-anchor:middle}}.card{{fill:#fff;stroke:#dbe1eb;filter:drop-shadow(0 3px 5px #17203320)}}.name{{fill:#172033;font-size:13px;font-weight:700;text-anchor:start}}.kind{{fill:#718096;font-size:8px;font-weight:700}}.rule{{stroke:#edf0f5}}.field{{fill:#344054;text-anchor:start}}.field tspan{{fill:#667085;font-family:ui-monospace,monospace}}.empty{{fill:#98a2b3;text-anchor:start}}</style><rect class="bg" width="100%" height="100%"/>{edge_markup}{''.join(cards)}</svg>'''
