import Foundation

struct ImportedArcMarkDiagram {
    let title: String
    let nodes: [DiagramNode]
    let relationships: [Relationship]
    let owner: String?
    let creatorID: String?
}

enum ArcMarkDocumentReader {
    static let supportedVersions: Set<String> = ["1.0.0", "1.1.0"]
    static func read(from url: URL) throws -> ImportedArcMarkDiagram {
        let document = try XMLDocument(contentsOf: url, options: [])
        guard let root = document.rootElement(), root.name == "arcmark" else {
            throw ArcMarkDocumentError.invalidRoot
        }
        let version = root.attribute(forName: "version")?.stringValue
        guard let version, Self.supportedVersions.contains(version) else {
            throw ArcMarkDocumentError.unsupportedVersion(version)
        }
        guard let diagram = root.elements(forName: "diagram").first else {
            throw ArcMarkDocumentError.missingDiagram
        }

        let title = diagram.attribute(forName: "title")?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawOwner = diagram.attribute(forName: "owner")?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let owner = (rawOwner?.isEmpty == false) ? rawOwner : nil
        let rawCreatorID = diagram.attribute(forName: "creator-id")?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines)
        let creatorID = (rawCreatorID?.isEmpty == false) ? rawCreatorID : nil
        var ids: [String: UUID] = [:]
        var nodes: [DiagramNode] = []
        let nodeElements = diagram.elements(forName: "nodes").first?.elements(forName: "node") ?? []

        for element in nodeElements {
            let id = try requiredAttribute("id", in: element)
            guard ids[id] == nil else { throw ArcMarkDocumentError.duplicateNodeID(id) }
            let name = try requiredAttribute("name", in: element)
            let kindValue = try requiredAttribute("kind", in: element)
            guard let kind = NodeKind(rawValue: kindValue) else { throw ArcMarkDocumentError.unknownNodeKind(kindValue) }
            let x = try coordinate("x", in: element)
            let y = try coordinate("y", in: element)
            let fields = try element.elements(forName: "field").map { field in
                Field(name: try requiredAttribute("name", in: field), type: try requiredAttribute("type", in: field))
            }
            let uuid = UUID()
            ids[id] = uuid
            nodes.append(DiagramNode(id: uuid, name: name, kind: kind, position: CGPoint(x: x, y: y), fields: fields))
        }

        var relationships: [Relationship] = []
        let relationshipElements = diagram.elements(forName: "relationships").first?.elements(forName: "relationship") ?? []
        for element in relationshipElements {
            let fromID = try requiredAttribute("from", in: element)
            let toID = try requiredAttribute("to", in: element)
            guard let from = ids[fromID], let to = ids[toID] else {
                throw ArcMarkDocumentError.brokenRelationship(from: fromID, to: toID)
            }
            let type = try requiredAttribute("type", in: element)
            relationships.append(Relationship(from: from, to: to, type: type))
        }

        return ImportedArcMarkDiagram(
            title: title?.isEmpty == false ? title! : "ArcMark Diagram",
            nodes: nodes,
            relationships: relationships,
            owner: owner,
            creatorID: creatorID
        )
    }

    private static func requiredAttribute(_ name: String, in element: XMLElement) throws -> String {
        guard let value = element.attribute(forName: name)?.stringValue, !value.isEmpty else {
            throw ArcMarkDocumentError.missingAttribute(name, element: element.name ?? "element")
        }
        return value
    }

    private static func coordinate(_ name: String, in element: XMLElement) throws -> CGFloat {
        let value = try requiredAttribute(name, in: element)
        guard let number = Double(value) else { throw ArcMarkDocumentError.invalidCoordinate(name, value: value) }
        return CGFloat(number)
    }
}

enum ArcMarkDocumentError: LocalizedError {
    case invalidRoot
    case unsupportedVersion(String?)
    case missingDiagram
    case missingAttribute(String, element: String)
    case invalidCoordinate(String, value: String)
    case unknownNodeKind(String)
    case duplicateNodeID(String)
    case brokenRelationship(from: String, to: String)

    var errorDescription: String? {
        switch self {
        case .invalidRoot: "This file is not an ArcMark document."
        case .unsupportedVersion(let version): "ArcMark version \(version ?? "unknown") is not supported."
        case .missingDiagram: "The document does not contain a diagram."
        case .missingAttribute(let name, let element): "The <\(element)> element is missing its \(name) attribute."
        case .invalidCoordinate(let name, let value): "The \(name) coordinate '\(value)' is not a number."
        case .unknownNodeKind(let kind): "The node kind '\(kind)' is not supported."
        case .duplicateNodeID(let id): "The node ID '\(id)' appears more than once."
        case .brokenRelationship(let from, let to): "A relationship references missing node IDs '\(from)' or '\(to)'."
        }
    }
}
