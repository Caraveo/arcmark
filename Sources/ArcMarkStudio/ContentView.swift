import SwiftUI
import AppKit

struct ContentView: View {
    @StateObject private var store = DiagramStore()
    @State private var showExport = false
    @State private var showExtract = false
    var body: some View {
        HSplitView {
            Sidebar(store: store).frame(minWidth: 220, idealWidth: 245, maxWidth: 280)
            VStack(spacing: 0) {
                Toolbar(store: store, showExport: $showExport, showExtract: $showExtract)
                DiagramCanvas(store: store)
            }.frame(minWidth: 650)
            Inspector(store: store).frame(minWidth: 270, idealWidth: 310, maxWidth: 360)
        }
        .sheet(isPresented: $showExport) { ExportSheet(store: store) }
        .sheet(isPresented: $showExtract) { ExtractSheet(store: store) }
        .onDeleteCommand { store.deleteSelected() }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct Sidebar: View {
    @ObservedObject var store: DiagramStore
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) { Image("arcmark-brand-logo", bundle: .module).resizable().scaledToFit().frame(width: 24, height: 24); Text("ARCMARK").font(.caption.weight(.bold)).tracking(2).foregroundStyle(.secondary) }
                TextField("Diagram name", text: $store.title).textFieldStyle(.plain).font(.title3.weight(.semibold))
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
                Label("ArcMark Standard v1.0.0", systemImage: "checkmark.seal.fill").font(.caption).foregroundStyle(.green)
                Text(".arc document format").font(.caption2).foregroundStyle(.secondary)
            }.padding(16).frame(maxWidth: .infinity, alignment: .leading).background(.quaternary)
        }
    }
}

private struct Toolbar: View {
    @ObservedObject var store: DiagramStore
    @Binding var showExport: Bool
    @Binding var showExtract: Bool
    var body: some View {
        HStack(spacing: 14) {
            Text("Diagram canvas").font(.headline)
            Spacer()
            Menu { ForEach(NodeKind.allCases) { kind in Button("Add \(kind.rawValue.capitalized)") { store.addNode(kind: kind) } } } label: { Label("Add node", systemImage: "plus") }
                .menuStyle(.borderlessButton)
            Button { store.beginConnection() } label: { Label(store.connectionSourceID == nil ? "Connect" : "Choose destination", systemImage: "arrowshape.turn.up.right.fill") }
                .buttonStyle(.bordered)
                .tint(store.connectionSourceID == nil ? .indigo : .orange)
                .disabled(store.selectedID == nil && store.connectionSourceID == nil)
            Divider().frame(height: 20)
            Button { store.zoom = max(0.5, store.zoom - 0.1) } label: { Image(systemName: "minus.magnifyingglass") }.buttonStyle(.plain)
            Text("\(Int(store.zoom * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary).frame(width: 34)
            Button { store.zoom = min(1.6, store.zoom + 0.1) } label: { Image(systemName: "plus.magnifyingglass") }.buttonStyle(.plain)
            Button { showExtract = true } label: { Label("Extract", systemImage: "rectangle.on.rectangle.angled") }.buttonStyle(.bordered)
            Button { store.saveArc() } label: { Label("Save As .arc", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent).tint(.indigo)
        }.padding(.horizontal, 22).frame(height: 58).background(.bar).overlay(alignment: .bottom) { Divider() }
    }
}

private struct DiagramCanvas: View {
    @ObservedObject var store: DiagramStore
    @State private var canvasOffset: CGSize = .zero
    @GestureState private var canvasDrag: CGSize = .zero

    private var displayedCanvasOffset: CGSize {
        CGSize(
            width: canvasOffset.width + canvasDrag.width,
            height: canvasOffset.height + canvasDrag.height
        )
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                Canvas { context, size in
                    let step: CGFloat = 24
                    let gridX = displayedCanvasOffset.width.truncatingRemainder(dividingBy: step)
                    let gridY = displayedCanvasOffset.height.truncatingRemainder(dividingBy: step)
                    for x in stride(from: gridX - step, through: size.width, by: step) { context.stroke(Path(CGRect(x: x, y: 0, width: 0.5, height: size.height)), with: .color(.gray.opacity(0.12))) }
                    for y in stride(from: gridY - step, through: size.height, by: step) { context.stroke(Path(CGRect(x: 0, y: y, width: size.width, height: 0.5)), with: .color(.gray.opacity(0.12))) }
                    context.translateBy(x: displayedCanvasOffset.width, y: displayedCanvasOffset.height)
                    for r in store.relationships { guard let a = store.nodes.first(where: {$0.id == r.from}), let b = store.nodes.first(where: {$0.id == r.to}) else { continue }; let route = canvasRoute(from: a, to: b, all: store.nodes); context.stroke(route.path, with: .color(.indigo.opacity(0.72)), style: .init(lineWidth: 2.25, dash: [6, 5])); let angle = atan2(route.arrowTo.y - route.arrowFrom.y, route.arrowTo.x - route.arrowFrom.x); let arrow: CGFloat = 10; var head = Path(); head.move(to: route.arrowTo); head.addLine(to: CGPoint(x: route.arrowTo.x - arrow * cos(angle - .pi / 6), y: route.arrowTo.y - arrow * sin(angle - .pi / 6))); head.addLine(to: CGPoint(x: route.arrowTo.x - arrow * cos(angle + .pi / 6), y: route.arrowTo.y - arrow * sin(angle + .pi / 6))); head.closeSubpath(); context.fill(head, with: .color(.indigo)); context.draw(Text(r.type).font(.caption.weight(.medium)).foregroundColor(.indigo), at: route.labelPoint) }
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 2)
                        .updating($canvasDrag) { value, state, _ in state = value.translation }
                        .onEnded { value in
                            canvasOffset.width += value.translation.width
                            canvasOffset.height += value.translation.height
                        }
                )
                .onTapGesture { store.selectedID = nil; store.connectionSourceID = nil }
                ForEach(store.nodes) { node in NodeCard(node: node, isSelected: store.selectedID == node.id)
                    .position(x: node.position.x + 74 + displayedCanvasOffset.width, y: node.position.y + 52 + displayedCanvasOffset.height)
                    .gesture(DragGesture().onChanged { value in var changed = node; changed.position = CGPoint(x: value.location.x - 74, y: value.location.y - 52); store.update(changed) })
                    .onTapGesture { store.handleNodeTap(node.id) }
                }
                VStack { Spacer(); HStack { Text(store.connectionSourceID == nil ? "Drag empty space to pan · Select a node, then Connect to link it" : "Now select the destination node").font(.caption.weight(store.connectionSourceID == nil ? .regular : .semibold)).foregroundStyle(store.connectionSourceID == nil ? Color.secondary : Color.orange).padding(10).background(.regularMaterial, in: Capsule()); Spacer() } }.padding(18)
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
        Section("Fields") { ForEach($edited.fields) { $field in FieldEditor(field: $field) { edited.fields.removeAll { $0.id == field.id } } }; Button { edited.fields.append(.init(name: "fieldName", type: "String")) } label: { Label("Add field", systemImage: "plus") } }
        Section { Button("Delete element", role: .destructive) { store.deleteSelected() } }
    }.formStyle(.grouped).onChange(of: edited) { _, value in store.update(value) }.onChange(of: node) { _, newValue in edited = newValue } }
}

private struct FieldEditor: View {
    @Binding var field: Field
    let remove: () -> Void
    @State private var isHovering = false
    var body: some View {
        HStack(spacing: 6) {
            TextField("Name", text: $field.name)
            TextField("Type", text: $field.type).frame(width: 78)
            Button(action: remove) { Image(systemName: "trash").font(.caption.weight(.semibold)) }
                .buttonStyle(.borderless)
                .foregroundStyle(.red)
                .opacity(isHovering ? 1 : 0)
                .accessibilityLabel("Remove \(field.name)")
        }
        .onHover { isHovering = $0 }
    }
}

private struct ExportSheet: View {
    @ObservedObject var store: DiagramStore; @Environment(\.dismiss) private var dismiss
    var body: some View { VStack(alignment: .leading, spacing: 16) { HStack { VStack(alignment: .leading) { Text("Export ArcMark .arc").font(.title2.weight(.bold)); Text("An XML-based ArcMark document, validated by the bundled XSD.").foregroundStyle(.secondary) }; Spacer(); Button("Done") { dismiss() } }
        TextEditor(text: .constant(store.xml())).font(.system(.caption, design: .monospaced)).padding(8).background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
        HStack { Button { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(store.xml(), forType: .string) } label: { Label("Copy document", systemImage: "doc.on.doc") }; Spacer(); Button { let panel = NSSavePanel(); panel.nameFieldStringValue = "\(store.title).arc"; panel.allowedContentTypes = [.arcMark]; panel.begin { if $0 == .OK, let url = panel.url { try? store.xml().write(to: url, atomically: true, encoding: .utf8) } } } label: { Label("Save .arc", systemImage: "square.and.arrow.down") }.buttonStyle(.borderedProminent) }
    }.padding(24).frame(width: 700, height: 560) }
}
