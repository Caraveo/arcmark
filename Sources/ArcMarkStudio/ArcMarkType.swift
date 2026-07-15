import UniformTypeIdentifiers

extension UTType {
    /// The registered ArcMark diagram document type. Its payload is XML, but its user-facing extension is `.arc`.
    static let arcMark = UTType(exportedAs: "com.arcmark.diagram", conformingTo: .xml)
}
