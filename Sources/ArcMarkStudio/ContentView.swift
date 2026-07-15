import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = DiagramStore()
    @State private var showExport = false
    @State private var showRelationship = false
    var body: some View {
        HSplitView {
            Sidebar(store: store).frame(minWidth: 220, idealWidth: 245, maxWidth: 280)
            VStack(spacing: 0) {
                Toolbar(store: store, showExport: $showExport, showRelationship: $showRelationship)
                DiagramCanvas(store: store)
            }.frame(minWidth: 650)
            Inspector(store: store).frame(minWidth: 270, idealWidth: 310, maxWidth: 360)
        }
        .sheet(isPresented: $showExport) { ExportSheet(store: store) }
        .sheet(isPresented: $showRelationship) { RelationshipSheet(store: store) }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct Sidebar: View {
    @ObservedObject var store: DiagramStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                Text("ARCMARK").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary)
                Text(store.title).font(.title3.weight(.semibold))
            }.padding(20)
            Divider()
            Text("DIAGRAM CONTENTS").font(.caption2.weight(.bold)).foregroundStyle(.secondary).padding(.horizontal, 16).padding(.top, 18)
            List(selection: $store.selectedID) {
                ForEach(store.nodes) { node in
                    HStack(spacing: 10) {
                        Image(systemName: node.kind == .entity ? "rectangle.3.group.fill" : node.kind == .service ? "bolt.fill" : "waveform.path.ecg").foregroundStyle(node.kind.color).frame(width: 16)
                        VStack(alignment: .leading, spacing: 2) { Text(node.name); Text(node.kind.rawValue.uppercased()).font(.caption2).foregroundStyle(.secondary) }
                    }.tag(node.id)
                }
            }.listStyle(.sidebar)
            Spacer()
            VStack(alignment: .leading, spacing: 7) {
                Label("ArcMark v1.0", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                Text(".arc document format").font(.caption2).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary)
        }
    }
}

private struct Toolbar: View {
    @ObservedObject var store: DiagramStore
    @Binding var showExport: Bool
    @Binding var showRelationship: Bool
    var body: some View {
        HStack(spacing: 14) {
            Text("Diagram canvas").font(.headline)
            Spacer()
            Menu { ForEach(NodeKind.allCases) { kind in Button("Add \(kind.rawValue.capitalized)") { store.addNode(kind: kind) } } } label: { Label("Add node", systemImage: "plus") }
                .menuStyle(.borderlessButton)
            Button { showRelationship = true } label: { Label("Connect", systemImage: "arrowshape.turn.up.right.fill") }
                .disabled(store.nodes.count < 2)
            Divider().frame(height: 20)
            Button { store.zoom = max(0.5, store.zoom - 0.1) } label: { Image(systemName: "minus.magnifyingglass") }.buttonStyle(.plain)
            Text("\(Int(store.zoom * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
            Button { store.zoom = min(1.6, store.zoom + 0.1) } label: { Image(systemName: "plus.magnifyingglass") }.buttonStyle(.plain)
            Button { showExport = true } label: { Label("Export .arc", systemImage: "square.and.arrow.up") }.buttonStyle(.borderedProminent).tint(.indigo)
        }.padding(.horizontal, 22).frame(height: 58).background(.bar).overlay(alignment: .bottom) { Divider() }
    }
}

private struct DiagramCanvas: View {
    @ObservedObject var store: DiagramStore
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let step: CGFloat = 24
                    for x in stride(from: 0, through: size.width, by: step) { context.stroke(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(.gray.opacity(0.12))) }
                    for y in stride(from: 0, through: size.height, by: step) { context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(.gray.opacity(0.12))) }
                    for r in store.relationships { guard let a = store.nodes.first(where: {$0.id == r.from}), let b = store.nodes.first(where: {$0.id == r.to}) else {continue}; let start = CGPoint(x: a.position.x + 148, y: a.position.y + 52), end = CGPoint(x: b.position.x, y: b.position.y + 52); let c1 = CGPoint(x: start.x + 90, y: start.y), c2 = CGPoint(x: end.x - 90, y: end.y); var p = Path(); p.move(to: start); p.addCurve(to: end, control1: c1, control2: c2); context.stroke(p, with: .color(.indigo.opacity(0.72)), style: .init(lineWidth: 2.25, dash: [6, 5])); let angle = atan2(end.y - c2.y, end.x - c2.x); let arrow: CGFloat = 10; var head = Path(); head.move(to: end); head.addLine(to: CGPoint(x: end.x - arrow * cos(angle - .pi / 6), y: end.y - arrow * sin(angle - .pi / 6))); head.addLine(to: CGPoint(x: end.x - arrow * cos(angle + .pi / 6), y: end.y - arrow * sin(angle + .pi / 6))); head.closeSubpath(); context.fill(head, with: .color(.indigo)); let mid = CGPoint(x: (start.x+end.x)/2, y: (start.y+end.y)/2 - 14); context.draw(Text(r.type).font(.caption.weight(.medium)).foregroundColor(.indigo), at: mid) }
                }
                .contentShape(Rectangle()).onTapGesture { store.selectedID = nil }
                ForEach(store.nodes) { node in NodeCard(node: node, isSelected: store.selectedID == node.id)
                    .position(x: node.position.x + 74, y: node.position.y + 52)
                    .gesture(DragGesture().onChanged { value in var changed = node; changed.position = CGPoint(x: value.location.x - 74, y: value.location.y - 52); store.update(changed) })
                    .onTapGesture { store.selectedID = node.id }
                }
                VStack { Spacer(); HStack { Text("Drag nodes to arrange your model").font(.caption).foregroundStyle(.secondary).padding(10).background(.regularMaterial, in: Capsule()); Spacer() } }.padding(18)
            }.scaleEffect(store.zoom, anchor: .topLeading)
        }.background(Color(nsColor: .controlBackgroundColor))
    }
}

private struct NodeCard: View {
    let node: DiagramNode; let isSelected: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack { Circle().fill(node.kind.color).frame(width: 8, height: 8); Text(node.name).font(.subheadline.weight(.semibold)); Spacer(); Text(node.kind.rawValue.uppercased()).font(.system(size: 8, weight: .bold)).foregroundStyle(.secondary) }.padding(10)
            Divider()
            VStack(alignment: .leading, spacing: 5) { ForEach(node.fields) { field in HStack { Text(field.name).font(.caption); Spacer(); Text(field.type).font(.caption.monospaced()).foregroundStyle(.secondary) } }; if node.fields.isEmpty { Text("No fields").font(.caption).foregroundStyle(.tertiary) } }.padding(10)
        }.frame(width: 148, alignment: .leading).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10)).overlay(RoundedRectangle(cornerRadius: 10).stroke(isSelected ? .indigo : node.kind.color.opacity(0.35), lineWidth: isSelected ? 2 : 1)).shadow(color: .black.opacity(0.1), radius: 7, y: 3)
    }
}

private struct Inspector: View {
    @ObservedObject var store: DiagramStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("INSPECTOR").font(.caption.weight(.bold)).tracking(1.5).foregroundStyle(.secondary).padding(20)
            Divider()
            if let n = store.selectedNode { NodeInspector(store: store, node: n) } else { ContentUnavailableView("Select an element", systemImage: "cursorarrow.click", description: Text("Click a node on the canvas to edit its structure.")) }
            Spacer()
        }.background(.bar)
    }
}

private struct NodeInspector: View {
    @ObservedObject var store: DiagramStore; let node: DiagramNode
    @State private var edited: DiagramNode
    init(store: DiagramStore, node: DiagramNode) { self.store = store; self.node = node; _edited = State(initialValue: node) }
    var body: some View { Form {
        Section("Element") { TextField("Name", text: $edited.name); Picker("Kind", selection: $edited.kind) { ForEach(NodeKind.allCases) { Text($0.rawValue.capitalized).tag($0) } } }
        Section("Fields") { ForEach($edited.fields) { $field in HStack { TextField("Name", text: $field.name); TextField("Type", text: $field.type).frame(width: 78) } }.onDelete { edited.fields.remove(atOffsets: $0) }; Button { edited.fields.append(.init(name: "fieldName", type: "String")) } label: { Label("Add field", systemImage: "plus") } }
        Section { Button("Apply changes") { store.update(edited) }.buttonStyle(.borderedProminent); Button("Delete element", role: .destructive) { store.deleteSelected() } }
    }.formStyle(.grouped).onChange(of: node) { _, newValue in edited = newValue } }
}

private struct ExportSheet: View {
    @ObservedObject var store: DiagramStore; @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack { VStack(alignment: .leading) { Text("Export ArcMark .arc").font(.title2.weight(.bold)); Text("An XML-based ArcMark document, validated by the bundled XSD.").foregroundStyle(.secondary) }; Spacer(); Button("Done") { dismiss() } }
        TextEditor(text: .constant(store.xml())).font(.system(.caption, design: .monospaced)).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        HStack { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(store.xml(), forType: .string) } label: { Label("Copy document", systemImage: "doc.on.doc") }; Spacer(); Button { let panel = NSSavePanel(); panel.nameFieldStringValue = "\(store.title).arc"; panel.allowedContentTypes = [.arcMark]; panel.begin { if $0 == .OK, let url = panel.url { try? store.xml().write(to: url, atomically: true, encoding: .utf8) } } } label: { Label("Save .arc", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent) }
    }.padding(24).frame(width: 700, height: 560) }
}

private struct RelationshipSheet: View {
    @ObservedObject var store: DiagramStore
    @Environment(\.dismiss) private var dismiss
    @State private var fromID: UUID?
    @State private var toID: UUID?
    @State private var label = "relates to"
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack { VStack(alignment: .leading, spacing: 4) { Text("Create relationship").font(.title2.weight(.bold)); Text("The arrow flows from source to destination.").foregroundStyle(.secondary) }; Spacer(); Button("Cancel") { dismiss() } }
            Form {
                Picker("From", selection: $fromID) { Text("Choose source").tag(UUID?.none); ForEach(store.nodes) { Text($0.name).tag(UUID?.some($0.id)) } }
                Picker("To", selection: $toID) { Text("Choose destination").tag(UUID?.none); ForEach(store.nodes) { Text($0.name).tag(UUID?.some($0.id)) } }
                TextField("Relationship", text: $label)
            }.formStyle(.grouped)
            HStack { Spacer(); Button("Create arrow") { if let fromID, let toID { store.addRelationship(from: fromID, to: toID, type: label); dismiss() } }.buttonStyle(.borderedProminent).disabled(fromID == nil || toID == nil || fromID == toID || label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) }
        }.padding(24).frame(width: 440)
    }
}
