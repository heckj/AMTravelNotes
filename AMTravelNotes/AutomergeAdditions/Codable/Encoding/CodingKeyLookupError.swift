import Foundation

public enum CodingKeyLookupError: LocalizedError {
    /// An error that represents a coding container was unable to look up a relevant Automerge objectId and was unable
    /// to capture a more specific error.
    case unexpectedLookupFailure(String)
    /// The path element is not valid.
    case invalidPathElement(String)
    /// The path element, structured as a Index location, doesn't include an index value.
    case emptyListIndex(String)
    /// The list index requested was longer than the list in the Document.
    case indexOutOfBounds(String)

    case invalidValueLookup(String)
    case invalidIndexLookup(String)
    case pathExtendsThroughText(String)
    case pathExtendsThroughScalar(String)
    case mismatchedSchema(String)

    // schema is missing beyond a certain point - only in readOnly mode
    case schemaMissing(String)

    /// A localized message describing what error occurred.
    public var errorDescription: String? {
        switch self {
        case let .unexpectedLookupFailure(str):
            return str
        case let .invalidPathElement(str):
            return str
        case let .emptyListIndex(str):
            return str
        case let .indexOutOfBounds(str):
            return str
        case let .invalidValueLookup(str):
            return str
        case let .invalidIndexLookup(str):
            return str
        case let .pathExtendsThroughText(str):
            return str
        case let .pathExtendsThroughScalar(str):
            return str
        case let .schemaMissing(str):
            return str
        case let .mismatchedSchema(str):
            return str
        }
    }

    /// A localized message describing the reason for the failure.
    public var failureReason: String? { nil }
}
