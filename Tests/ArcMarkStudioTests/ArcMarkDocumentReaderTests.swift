import Testing
import Foundation
@testable import ArcMarkStudio

@Test func readsAnArcMarkDocument() throws {
        let document = """
        <?xml version="1.0" encoding="UTF-8"?>
        <arcmark version="1.0.0">
          <diagram title="Import Test">
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
        </arcmark>
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arcmark-import-test.arc")
        try document.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let imported = try ArcMarkDocumentReader.read(from: url)

        #expect(imported.title == "Import Test")
        #expect(imported.nodes.map { $0.name } == ["Customer", "Billing Service"])
        #expect(imported.nodes.first?.fields.count == 1)
        #expect(imported.nodes.first?.fields.first?.name == "customerId")
        #expect(imported.nodes.first?.fields.first?.type == "UUID")
        #expect(imported.relationships.count == 1)
        #expect(imported.relationships.first?.type == "charges")
}

@Test func rejectsBrokenRelationship() throws {
        let document = """
        <arcmark version="1.0.0"><diagram title="Broken"><nodes><node id="a" name="A" kind="entity" x="0" y="0"/></nodes><relationships><relationship from="a" to="missing" type="relates to"/></relationships></diagram></arcmark>
        """
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("arcmark-broken-test.arc")
        try document.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        #expect(throws: ArcMarkDocumentError.self) { try ArcMarkDocumentReader.read(from: url) }
}
