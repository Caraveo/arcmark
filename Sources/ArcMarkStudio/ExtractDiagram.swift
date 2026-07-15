import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ExtractNode: Identifiable {
    let node: DiagramNode
    let position: CGPoint
    var id: UUID { node.id }
}

struct ExtractLoop: Identifiable {
    let members: Set<UUID>
    let frame: CGRect
    let hiddenRelationID: UUID
    let id = UUID()
}

struct ExtractLayout {
    let title: String
    let nodes: [ExtractNode]
    let relationships: [Relationship]
    let loops: [ExtractLoop]
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
        var groups = Dictionary(grouping: sorted, by: { depth[$0.id] ?? 0 })
        let levels = groups.keys.sorted()
        let incomingSources = Dictionary(grouping: relationships, by: \.to)
        // Stable forward barycentric ordering. We deliberately do not perform a
        // backward pass: that pass can reverse an already-correct source order
        // and reintroduce crossings. Each destination follows the row order of
        // the sources immediately to its left; unused rows remain empty space.
        for level in levels.dropFirst() {
            guard let current = groups[level] else { continue }
            let previousRows = Dictionary(uniqueKeysWithValues: (groups[level - 1] ?? []).enumerated().map { ($0.element.id, Double($0.offset)) })
            groups[level] = current.enumerated().sorted { left, right in
                func score(_ node: DiagramNode, fallback: Int) -> Double {
                    let rows = (incomingSources[node.id] ?? []).compactMap { previousRows[$0.from] }
                    return rows.isEmpty ? Double(fallback) : rows.reduce(0, +) / Double(rows.count)
                }
                let a = score(left.element, fallback: left.offset), b = score(right.element, fallback: right.offset)
                return a == b ? left.element.name < right.element.name : a < b
            }.map(\.element)
        }
        var positioned: [ExtractNode] = []
        for level in groups.keys.sorted() {
            for (row, node) in (groups[level] ?? []).enumerated() {
                positioned.append(ExtractNode(node: node, position: .init(x: 70 + CGFloat(level) * 250, y: 80 + CGFloat(row) * 132)))
            }
        }
        // Kosaraju's algorithm identifies strongly connected components. A
        // component with multiple nodes (or a self relation) is a visual loop.
        var forward = Dictionary(uniqueKeysWithValues: source.map { ($0.id, [UUID]()) })
        var backward = Dictionary(uniqueKeysWithValues: source.map { ($0.id, [UUID]()) })
        for relation in relationships where ids.contains(relation.from) && ids.contains(relation.to) { forward[relation.from, default: []].append(relation.to); backward[relation.to, default: []].append(relation.from) }
        var visited = Set<UUID>(), finish: [UUID] = []
        func visit(_ id: UUID) { guard visited.insert(id).inserted else { return }; for next in forward[id, default: []] { visit(next) }; finish.append(id) }
        for node in source { visit(node.id) }
        visited.removeAll(); var components: [Set<UUID>] = []
        func collect(_ id: UUID, _ component: inout Set<UUID>) { guard visited.insert(id).inserted else { return }; component.insert(id); for next in backward[id, default: []] { collect(next, &component) } }
        for id in finish.reversed() { var component = Set<UUID>(); collect(id, &component); if component.count > 1 || forward[id, default: []].contains(id) { components.append(component) } }
        // Render cyclic components as a left-to-right sequence within their own
        // enclosure. It makes the omitted final return edge visually obvious.
        for component in components {
            let internalRelations = relationships.filter { component.contains($0.from) && component.contains($0.to) }
            let externalEntrances = component.filter { id in relationships.contains { $0.to == id && !component.contains($0.from) } }
            var ordered = externalEntrances.sorted { $0.uuidString < $1.uuidString }
            if ordered.isEmpty, let first = component.sorted(by: { $0.uuidString < $1.uuidString }).first { ordered = [first] }
            var cursor = 0
            while cursor < ordered.count {
                let current = ordered[cursor]; cursor += 1
                if let next = internalRelations.first(where: { $0.from == current && !ordered.contains($0.to) })?.to { ordered.append(next) }
            }
            ordered += component.filter { !ordered.contains($0) }.sorted { $0.uuidString < $1.uuidString }
            let currentPositions = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0.position) })
            let originX = ordered.compactMap { currentPositions[$0]?.x }.min() ?? 70
            let originY = ordered.compactMap { currentPositions[$0]?.y }.min() ?? 80
            for (index, id) in ordered.enumerated() {
                guard let itemIndex = positioned.firstIndex(where: { $0.id == id }) else { continue }
                positioned[itemIndex] = ExtractNode(node: positioned[itemIndex].node, position: .init(x: originX + CGFloat(index) * 210, y: originY))
            }
        }
        self.nodes = positioned
        let positions = Dictionary(uniqueKeysWithValues: positioned.map { ($0.id, $0.position) })
        self.loops = components.compactMap { component in
            let rects = component.compactMap { positions[$0].map { CGRect(x: $0.x, y: $0.y, width: 180, height: 70) } }
            guard var frame = rects.first else { return nil }; for rect in rects.dropFirst() { frame = frame.union(rect) }
            // The enclosure replaces precisely one closing relation: the one
            // leaving the rightmost (then lowest) member. All other internal
            // relations remain visible, so the loop's flow is still readable.
            guard let closing = relationships.filter({ component.contains($0.from) && component.contains($0.to) }).max(by: {
                let a = positions[$0.from] ?? .zero, b = positions[$1.from] ?? .zero
                return a.x == b.x ? a.y < b.y : a.x < b.x
            }) else { return nil }
            return ExtractLoop(members: component, frame: frame.insetBy(dx: -26, dy: -30), hiddenRelationID: closing.id)
        }
        let maxX = positioned.map { $0.position.x + 180 }.max() ?? 360
        let maxY = positioned.map { $0.position.y + 70 }.max() ?? 220
        self.size = .init(width: max(520, maxX + 70), height: max(260, maxY + 70))
    }

    func svg() -> String {
        func escape(_ string: String) -> String { string.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "<", with: "&lt;").replacingOccurrences(of: "\"", with: "&quot;") }
        let lookup = Dictionary(uniqueKeysWithValues: nodes.map { ($0.id, $0) })
        let edges = relationships.compactMap { relation -> String? in
            guard !loops.contains(where: { $0.hiddenRelationID == relation.id }) else { return nil }
            guard let source = lookup[relation.from], let target = lookup[relation.to] else { return nil }
            let x1 = source.position.x + 180, y1 = source.position.y + 35, x2 = target.position.x, y2 = target.position.y + 35
            return "<path class=\"edge\" marker-end=\"url(#arrow)\" d=\"M\(x1) \(y1) C\(x1 + 48) \(y1), \(x2 - 48) \(y2), \(x2) \(y2)\"/><text class=\"label\" x=\"\((x1+x2)/2)\" y=\"\((y1+y2)/2-9)\">\(escape(relation.type))</text>"
        }.joined()
        let loopAreas = loops.map { "<rect class=\"loop\" x=\"\($0.frame.minX)\" y=\"\($0.frame.minY)\" width=\"\($0.frame.width)\" height=\"\($0.frame.height)\" rx=\"12\"/>" }.joined()
        let cards = nodes.map { node in "<rect class=\"node\" x=\"\(node.position.x)\" y=\"\(node.position.y)\" width=\"180\" height=\"70\" rx=\"3\"/><text class=\"name\" x=\"\(node.position.x + 90)\" y=\"\(node.position.y + 42)\">\(escape(node.node.name))</text>" }.joined()
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <svg xmlns=\"http://www.w3.org/2000/svg\" width=\"\(Int(size.width))\" height=\"\(Int(size.height))\" viewBox=\"0 0 \(Int(size.width)) \(Int(size.height))\">
          <defs><marker id=\"arrow\" viewBox=\"0 0 10 10\" refX=\"8\" refY=\"5\" markerWidth=\"7\" markerHeight=\"7\" orient=\"auto\"><path d=\"M 0 0 L 10 5 L 0 10 z\" fill=\"#64748b\"/></marker></defs>
          <style>.edge{fill:none;stroke:#64748b;stroke-width:2}.loop{fill:#f8fafc;fill-opacity:.45;stroke:#94a3b8;stroke-width:1.5;stroke-dasharray:6 5}.node{fill:#f8fafc;stroke:#94a3b8;stroke-width:1.5}.name{font:600 15px -apple-system,BlinkMacSystemFont,sans-serif;fill:#0f172a;text-anchor:middle}.label{font:12px -apple-system,BlinkMacSystemFont,sans-serif;fill:#475569;text-anchor:middle}</style>
          \(loopAreas)\(edges)\(cards)
        </svg>
        """
    }
}

final class ExtractRenderView: NSView {
    let layout: ExtractLayout
    let transparentBackground: Bool
    init(layout: ExtractLayout, transparentBackground: Bool = false) { self.layout = layout; self.transparentBackground = transparentBackground; super.init(frame: CGRect(origin: .zero, size: layout.size)); wantsLayer = true }
    required init?(coder: NSCoder) { nil }
    override func draw(_ dirtyRect: NSRect) {
        if transparentBackground { NSGraphicsContext.current?.cgContext.clear(bounds) } else { NSColor.white.setFill(); bounds.fill() }
        let lookup = Dictionary(uniqueKeysWithValues: layout.nodes.map { ($0.id, $0) })
        for loop in layout.loops { NSColor(calibratedWhite: 0.95, alpha: 0.55).setFill(); NSBezierPath(roundedRect: loop.frame, xRadius: 12, yRadius: 12).fill(); let border = NSBezierPath(roundedRect: loop.frame, xRadius: 12, yRadius: 12); border.setLineDash([6, 5], count: 2, phase: 0); NSColor.slate.setStroke(); border.stroke() }
        for relation in layout.relationships {
            guard !layout.loops.contains(where: { $0.hiddenRelationID == relation.id }) else { continue }
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
            HStack { VStack(alignment: .leading, spacing: 3) { Text("System Design Overview").font(.title2.weight(.bold)); Text("A clean relationship-first view, independent of canvas placement.").foregroundStyle(.secondary) }; Spacer(); Button("Done") { dismiss() } }
            ScrollView([.horizontal, .vertical]) { ExtractPreview(layout: layout).frame(width: layout.size.width, height: layout.size.height).padding(20) }.background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
            HStack { Picker("Format", selection: $format) { ForEach(ExtractFormat.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).frame(width: 280); Spacer(); Button { save() } label: { Label("Export \(format.rawValue)", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent) }
        }.padding(24).frame(width: 900, height: 660)
    }
    private func save() {
        let panel = NSSavePanel(); panel.nameFieldStringValue = "\(store.title).\(format.extensionName)"; panel.allowedContentTypes = [format.type]
        panel.begin { response in guard response == .OK, let url = panel.url else { return }; let view = ExtractRenderView(layout: layout, transparentBackground: format == .png); let data: Data?
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
            for loop in layout.loops { context.fill(Path(roundedRect: loop.frame, cornerRadius: 12), with: .color(.gray.opacity(0.10))); context.stroke(Path(roundedRect: loop.frame, cornerRadius: 12), with: .color(.gray.opacity(0.7)), style: .init(lineWidth: 1.5, dash: [6, 5])) }
            for relation in layout.relationships { guard !layout.loops.contains(where: { $0.hiddenRelationID == relation.id }), let source = lookup[relation.from], let target = lookup[relation.to] else { continue }; let start = CGPoint(x: source.position.x + 180, y: source.position.y + 35), end = CGPoint(x: target.position.x, y: target.position.y + 35); var path = Path(); path.move(to: start); path.addCurve(to: end, control1: .init(x: start.x + 48, y: start.y), control2: .init(x: end.x - 48, y: end.y)); context.stroke(path, with: .color(.secondary), lineWidth: 2); let angle = atan2(end.y - start.y, end.x - start.x); var arrow = Path(); arrow.move(to: end); arrow.addLine(to: .init(x: end.x - 10 * cos(angle - .pi / 6), y: end.y - 10 * sin(angle - .pi / 6))); arrow.addLine(to: .init(x: end.x - 10 * cos(angle + .pi / 6), y: end.y - 10 * sin(angle + .pi / 6))); arrow.closeSubpath(); context.fill(arrow, with: .color(.secondary)); context.draw(Text(relation.type).font(.caption).foregroundColor(.secondary), at: .init(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2 - 10)) }
            for item in layout.nodes { let rect = CGRect(x: item.position.x, y: item.position.y, width: 180, height: 70); context.fill(Path(roundedRect: rect, cornerRadius: 3), with: .color(.white)); context.stroke(Path(roundedRect: rect, cornerRadius: 3), with: .color(.gray.opacity(0.7)), lineWidth: 1.5); context.draw(Text(item.node.name).font(.headline.weight(.semibold)).foregroundColor(.primary), at: .init(x: rect.midX, y: rect.midY)) }
        }.background(.white)
    }
}
