import Foundation

// conceptually borrowing the same idea that was used for JSON encoding and decoding
// at https://github.com/swift-extras/swift-extras-json/blob/main/Sources/ExtrasJSON/JSONValue.swift

/// A type that represents all the potential options that the Automerge schema represents.
///
/// AutomergeType is a generalized representation of the same schema components that
/// Automerge supports, and allows us to represent the same structure as an Automerge schema
/// as nested enums for the purposes of temporarily storing, encoding, or decoding values.
public enum AutomergeValue: Equatable, Hashable {
    /// A list CRDT.
    case list([AutomergeValue])
    /// A map CRDT.
    case map([String: AutomergeValue])
    /// A specialized list CRDT for representing text.
    case text(String) // String
    /// A byte buffer.
    case bytes(Data)
    /// A string.
    case string(String)
    /// An unsigned integer.
    case uint(UInt64)
    /// A signed integer.
    case int(Int64)
    /// A floating point number.
    case double(Double)
    /// An integer counter.
    case counter(Int64)
    /// A timestamp represented by the milliseconds since UNIX epoch.
    case timestamp(Int64)
    /// A Boolean value.
    case bool(Bool)
    /// An unknown, raw scalar type.
    ///
    /// This type is reserved for forward compatibility, and is not expected to be created directly.
    case unknown(typeCode: UInt8, data: Data)
    case null
}

public func == (lhs: AutomergeValue, rhs: AutomergeValue) -> Bool {
    switch (lhs, rhs) {
    case (.null, .null):
        return true
    case let (.bool(lhs), .bool(rhs)):
        return lhs == rhs
    case let (.int(lhs), .int(rhs)):
        return lhs == rhs
    case let (.uint(lhs), .uint(rhs)):
        return lhs == rhs
    case let (.double(lhs), .double(rhs)):
        return lhs == rhs
    case let (.bytes(lhs), .bytes(rhs)):
        return lhs == rhs
    case let (.counter(lhs), .counter(rhs)):
        return lhs == rhs
    case let (.timestamp(lhs), .timestamp(rhs)):
        return lhs == rhs
    case let (.string(lhs), .string(rhs)):
        return lhs == rhs
    case let (.list(lhs), .list(rhs)):
        guard lhs.count == rhs.count else {
            return false
        }

        var lhsiterator = lhs.makeIterator()
        var rhsiterator = rhs.makeIterator()

        while let lhs = lhsiterator.next(), let rhs = rhsiterator.next() {
            if lhs == rhs {
                continue
            }
            return false
        }

        return true
    case let (.map(lhs), .map(rhs)):
        guard lhs.count == rhs.count else {
            return false
        }

        var lhsiterator = lhs.makeIterator()

        while let (lhskey, lhsvalue) = lhsiterator.next() {
            guard let rhsvalue = rhs[lhskey] else {
                return false
            }

            if lhsvalue == rhsvalue {
                continue
            }
            return false
        }

        return true
    default:
        return false
    }
}
