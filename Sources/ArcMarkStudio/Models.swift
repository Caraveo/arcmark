import Foundation
import SwiftUI
import AppKit

enum NodeKind: String, CaseIterable, Identifiable { case entity, service, event; var id: String { rawValue }
    var color: Color { switch self { case .entity: .cyan; case .service: .purple; case .event: .orange } }
}

struct Field: Identifiable, Hashable { var id = UUID(); var name: String; var type: String }
struct DiagramNode: Identifiable, Hashable {
    var id = UUID(); var name: String; var kind: NodeKind; var position: CGPoint; var fields: [Field]
}
struct Relationship: Identifiable, Hashable { var id = UUID(); var from: UUID; var to: UUID; var type: String }

@MainActor
final class DiagramStore: ObservableObject {
    @Published var title = "Commerce Domain"
    @Published var nodes: [DiagramNode] = [
        .init(name: "Customer", kind: .entity, position: .init(x: 180, y: 220), fields: [.init(name: "customerId", type: "UUID"), .init(name: "email", type: "String")]),
        .init(name: "Order", kind: .entity, position: .init(x: 540, y: 150), fields: [.init(name: "orderId", type: "UUID"), .init(name: "status", type: "OrderStatus"), .init(name: "total", type: "Decimal")]),
        .init(name: "Billing Service", kind: .service, position: .init(x: 880, y: 300), fields: [.init(name: "charge(order)", type: "Payment")])
    ]
    @Published var relationships: [Relationship] = []
    @Published var selectedID: UUID? = nil
    @Published var selectedRelation: UUID? = nil
    @Published var connectionSourceID: UUID? = nil
    @Published var zoom: CGFloat = 1
    var selectedNode: DiagramNode? { nodes.first { $0.id == selectedID } }

    init() { relationships = [.init(from: nodes[0].id, to: nodes[1].id, type: "places"), .init(from: nodes[1].id, to: nodes[2].id, type: "charges")] }
    func addNode(kind: NodeKind) { let n = DiagramNode(name: "New \(kind.rawValue.capitalized)", kind: kind, position: .init(x: 360, y: 360), fields: []); nodes.append(n); selectedID = n.id }
    func addRelationship(from: UUID, to: UUID, type: String = "relates to") {
        guard from != to, !type.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        relationships.append(.init(from: from, to: to, type: type.trimmingCharacters(in: .whitespacesAndNewlines)))
    }
    func beginConnection() { connectionSourceID = selectedID }
    func handleNodeTap(_ id: UUID) {
        if let source = connectionSourceID, source != id {
            addRelationship(from: source, to: id)
            connectionSourceID = nil
        }
        selectedID = id
    }
    func extractLayout() -> ExtractLayout { ExtractLayout(title: title, nodes: nodes, relationships: relationships) }
    func saveArc() {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "\(title).arc"
        panel.allowedContentTypes = [.arcMark]
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? self.xml().write(to: url, atomically: true, encoding: .utf8)
        }
    }
    func update(_ node: DiagramNode) { guard let i = nodes.firstIndex(where: {$0.id == node.id}) else { return }; nodes[i] = node }
    func deleteSelected() { guard let id = selectedID else { return }; nodes.removeAll {$0.id == id}; relationships.removeAll {$0.from == id || $0.to == id}; selectedID = nil }
    func xml() -> String {
        func escape(_ s: String) -> String { s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;") }
        func xmlID(_ id: UUID) -> String { "n" + id.uuidString.replacingOccurrences(of: "-", with: "") }
        let ns = nodes.map { n in
            let fields = n.fields.map { "      <field name=\"\(escape($0.name))\" type=\"\(escape($0.type))\"/>" }.joined(separator: "\n")
            return "    <node id=\"\(xmlID(n.id))\" name=\"\(escape(n.name))\" kind=\"\(n.kind.rawValue)\" x=\"\(Int(n.position.x))\" y=\"\(Int(n.position.y))\">\n\(fields)\n    </node>"
        }.joined(separator: "\n")
        let rs = relationships.compactMap { r -> String? in
            guard let a = nodes.first(where: { $0.id == r.from }), let b = nodes.first(where: { $0.id == r.to }) else { return nil }
            return "    <relationship from=\"\(xmlID(a.id))\" to=\"\(xmlID(b.id))\" type=\"\(escape(r.type))\"/>"
        }.joined(separator: "\n")
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<arcmark version=\"1.0.0\">\n  <diagram title=\"\(escape(title))\">\n  <nodes>\n\(ns)\n  </nodes>\n  <relationships>\n\(rs)\n  </relationships>\n  </diagram>\n</arcmark>"
    }
}
