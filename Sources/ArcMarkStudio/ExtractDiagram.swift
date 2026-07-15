import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExtractNode: Identifiable {
    let node: DiagramNode
    let position: CGPoint
    var id: UUID { node.id }
}

struct ExtractLayout {
    let title: String
    let nodes: [ExtractNode]
    let relationships: [Relationship]
    let size: CGSize

    init(title: String, nodes source: [DiagramNode], relationships: [Relationship]) {
        self.title = title; self.relationships = relationships
        let ids = Set(source.map(\.id))
        var incoming = Dictionary(uniqueKeysWithValues: source.map { ($0.id, 0) })
        var outgoing = Dictionary(uniqueKeysWithValues: source.map { ($0.id, [UUID]()) })
        for relation in relationships where ids.contains(relation.from) && ids.contains(relation.to) {
            incoming[relation.to, default: 0] += 1
            outgoing[relation.from, default: []].append(relation.to)
        }
        var depth = Dictionary(uniqueKeysWithValues: source.map { ($0.id, 0) })
        var queue = source.filter { incoming[$0.id] == 0 }.sorted { $0.name < $1.name }.map(\.id)
        var cursor = 0
        while cursor < queue.count {
            let id = queue[cursor]; cursor += 1
            for child in outgoing[id, default: []] {
                depth[child] = max(depth[child, default: 0], depth[id, default: 0] + 1)
                incoming[child, default: 1] -= 1
                if incoming[child] == 0 { queue.append(child) }
            }
        }
        // Cycles and disconnected diagrams remain deterministic in the first column.
        let sorted = source.sorted { (depth[$0.id] ?? 0, $0.name) < (depth[$1.id] ?? 0, $1.name) }
        let groups = Dictionary(grouping: sorted, by: { depth[$0.id] ?? 0 })
        var positioned: [ExtractNode] = []
        for level in groups.keys.sorted() {
            for (row, node) in (groups[level] ?? []).enumerated() {
                positioned.append(ExtractNode(node: node, position: .init(x: 70 + CGFloat(level) * 250, y: 80 + CGFloat(row) * 112)))
            }
        }
        self.nodes = positioned
        let maxX = positioned.map { $0.position.x + 180 }.max() ?? 360
        let maxY = positioned.map { $0.position.y + 70 }.max() ?? 220
        self.size = .init(width: max(520, maxX + 70), height: max(260, maxY + 70))
    }

    func svg() -> String {
        func escape(_ string: String) -> String { string.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;") }
        let lookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let edges = relationships.compactMap { relation -> String? in
            guard let source = lookup[relation.from], let target = lookup[relation.to] else { return nil }
            let x1 = source.position.x + 180, y1 = source.position.y + 35, x2 = target.position.x, y2 = target.position.y + 35
            return "<path class=\"edge\" marker-end=\"url(#arrow)\" d=\"M\(x1) \(y1) C\(x1 + 48) \(y1), \(x2 - 48) \(y2), \(x2) \(y2)\"/><text class=\"label\" x=\"\((x1+x2)/2)\" y=\"\((y1+y2)/2-9)\">\(escape(relation.type))</text>"
        }.joined()
        let cards = nodes.map { node in "<rect class=\"node\" x=\"\(node.position.x)\" y=\"\(node.position.y)\" width=\"180\" height=\"70\" rx=\"3\"/><text class=\"name\" x=\"\(node.position.x + 90)\" y=\"\(node.position.y + 42)\">\(escape(node.node.name))</text>" }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(Int(size.width))\" height=\"\(Int(size.height))\" viewBox=\"0 0 \(Int(size.width)) \(Int(size.height))\">
          <defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"8\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#64748b\"/></marker></defs>
          <style>.bg{fill:#ffffff}.edge{fill:none;stroke:#64748b;stroke-width:2}.node{fill:#f8fafc;stroke:#94a3b8;stroke-width:1.5}.name{font:600 15px -apple-system,BlinkMacSystemFont,sans-serif;fill:#0f172a;text-anchor:middle}.label{font:12px -apple-system,BlinkMacSystemFont,sans-serif;fill:#475569;text-anchor:middle}</style>
          <rect class=\"bg\" width=\"100%\" height=\"100%\"/>\(edges)\(cards)
        </svg>
        """
    }
}

final class ExtractRenderView: NSView {
    let layout: ExtractLayout
    init(layout: ExtractLayout) { self.layout = layout; super.init(frame: CGRect(origin: .zero, size: layout.size)); wantsLayer = true }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.setFill(); bounds.fill()
        let lookup = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        for relation in layout.relationships {
            guard let source = lookup[relation.from], let target = lookup[relation.to] else { continue }
            let start = CGPoint(x: source.position.x + 180, y: source.position.y + 35), end = CGPoint(x: target.position.x, y: target.position.y + 35)
            let path = NSBezierPath(); path.move(to: start); path.curve(to: end, controlPoint1: .init(x: start.x + 48, y: start.y), controlPoint2: .init(x: end.x - 48, y: end.y)); NSColor.slate.setStroke(); path.lineWidth = 2; path.stroke()
            let angle = atan2(end.y - start.y, end.x - start.x), arrow = NSBezierPath(); arrow.move(to: end); arrow.line(to: .init(x: end.x - 10 * cos(angle - .pi / 6), y: end.y - 10 * sin(angle - .pi / 6))); arrow.line(to: .init(x: end.x - 10 * cos(angle + .pi / 6), y: end.y - 10 * sin(angle + .pi / 6))); arrow.close(); NSColor.slate.setFill(); arrow.fill()
            let label = relation.type as NSString; label.draw(at: .init(x: (start.x + end.x) / 2 - label.size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width / 2, y: (start.y + end.y) / 2 + 7), withAttributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.secondaryLabelColor])
        }
        for item in layout.nodes {
            let rect = CGRect(x: item.position.x, y: item.position.y, width: 180, height: 70); NSColor(calibratedWhite: 0.98, alpha: 1).setFill(); NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3).fill(); NSColor.slate.setStroke(); let border = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3); border.lineWidth = 1.5; border.stroke()
            let text = item.node.name as NSString; let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .semibold), .foregroundColor: NSColor.labelColor]; let textSize = text.size(withAttributes: attributes); text.draw(at: .init(x: rect.midX - textSize.width / 2, y: rect.midY - textSize.height / 2), withAttributes: attributes)
        }
    }
}

extension NSColor { static let slate = NSColor(calibratedRed: 0.39, green: 0.45, blue: 0.55, alpha: 1) }

private enum ExtractFormat: String, CaseIterable, Identifiable { case svg = "SVG", png = "PNG", jpeg = "JPEG", pdf = "PDF"; var id: String { rawValue }; var type: UTType { switch self { case .svg: .svg; case .png: .png; case .jpeg: .jpeg; case .pdf: .pdf } }; var extensionName: String { rawValue.lowercased().replacingOccurrences(of: "jpeg", with: "jpg") } }

struct ExtractSheet: View {
    @ObservedObject var store: DiagramStore
    @Environment(\.dismiss) private var dismiss
    @State private var format: ExtractFormat = .svg
    private var layout: ExtractLayout { ExtractLayout(title: store.title, nodes: store.nodes, relationships: store.relationships) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack { VStack(alignment: .leading, spacing: 3) { Text("Extracted diagram").font(.title2.weight(.bold)); Text("A clean relationship-first view, independent of canvas placement.").foregroundStyle(.secondary) }; Spacer(); Button("Done") { dismiss() } }
            ScrollView([.horizontal, .vertical]) { ExtractPreview(layout: layout).frame(width: layout.size.width, height: layout.size.height).padding(20) }.background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            HStack { Picker("Format", selection: $format) { ForEach(ExtractFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 280); Spacer(); Button { save() } label: { Label("Export \(format.rawValue)", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 900, height: 660)
    }
    private func save() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(store.title).\(format.extensionName)"; panel.allowedContentTypes = [format.type]
        panel.begin { response in guard response == .OK, let url = panel.url else { return }; let view = ExtractRenderView(layout: layout); let data: Data?
            switch format { case .svg: data = layout.svg().data(using: .utf8); case .pdf: data = view.dataWithPDF(inside: view.bounds); case .png, .jpeg: let image = NSImage(size: layout.size); image.lockFocus(); view.draw(view.bounds); image.unlockFocus(); guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) else { return }; data = bitmap.representation(using: format == .png ? .png : .jpeg, properties: format == .jpeg ? [.compressionFactor: 0.92] : [:]) }
            try? data?.write(to: url)
        }
    }
}

private struct ExtractPreview: View {
    let layout: ExtractLayout
    var body: some View {
        Canvas { context, _ in
            let lookup = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
            for relation in layout.relationships { guard let source = lookup[relation.from], let target = lookup[relation.to] else { continue }; let start = CGPoint(x: source.position.x + 180, y: source.position.y + 35), end = CGPoint(x: target.position.x, y: target.position.y + 35); var path = Path(); path.move(to: start); path.addCurve(to: end, control1: .init(x: start.x + 48, y: start.y), control2: .init(x: end.x - 48, y: end.y)); context.stroke(path, with: .color(.secondary), lineWidth: 2); let angle = atan2(end.y - start.y, end.x - start.x); var arrow = Path(); arrow.move(to: end); arrow.addLine(to: .init(x: end.x - 10 * cos(angle - .pi / 6), y: end.y - 10 * sin(angle - .pi / 6))); arrow.addLine(to: .init(x: end.x - 10 * cos(angle + .pi / 6), y: end.y - 10 * sin(angle + .pi / 6))); arrow.closeSubpath(); context.fill(arrow, with: .color(.secondary)); context.draw(Text(relation.type).font(.caption).foregroundColor(.secondary), at: .init(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 10)) }
            for item in layout.nodes { let rect = CGRect(x: item.position.x, y: item.position.y, width: 180, height: 70); context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white)); context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(.gray.opacity(0.7)), lineWidth: 1.5); context.draw(Text(item.node.name).font(.headline.weight(.semibold)).foregroundColor(.primary), at: .init(x: rect.midX, y: rect.midY)) }
        }.background(.white)
    }
}
