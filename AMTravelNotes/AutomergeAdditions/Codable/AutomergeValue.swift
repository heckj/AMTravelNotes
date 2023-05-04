import Foundation

// conceptually borrowing the same idea that was used for JSON encoding and decoding
// at https://github.com/swift-extras/swift-extras-json/blob/main/Sources/ExtrasJSON/JSONValue.swift

enum AutomergeFuture {
    case value(AutomergeValue)
    case nestedArray(AutomergeArray)
    case nestedObject(AutomergeObject)
}

/// A type that represents all the potential options that the Automerge schema represents.
///
/// AutomergeType is a generalized representation of the same schema components that
/// Automerge supports, and allows us to represent the same structure as an Automerge schema
/// as nested enums for the purposes of temporarily storing, encoding, or decoding values.
public enum AutomergeValue: Equatable, Hashable {
    /// A list CRDT.
    case array([AutomergeValue])
    /// A map CRDT.
    case object([String: AutomergeValue])
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
    case let (.array(lhs), .array(rhs)):
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
    case let (.object(lhs), .object(rhs)):
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

class AutomergeArray {
    private(set) var array: [AutomergeFuture] = []

    init() {
        array.reserveCapacity(10)
    }

    @inline(__always) func append(_ element: AutomergeValue) {
        array.append(.value(element))
    }

    @inline(__always) func appendArray() -> AutomergeArray {
        let array = AutomergeArray()
        self.array.append(.nestedArray(array))
        return array
    }

    @inline(__always) func appendObject() -> AutomergeObject {
        let object = AutomergeObject()
        array.append(.nestedObject(object))
        return object
    }

    var values: [AutomergeValue] {
        array.map { future -> AutomergeValue in
            switch future {
            case let .value(value):
                return value
            case let .nestedArray(array):
                return .array(array.values)
            case let .nestedObject(object):
                return .object(object.values)
            }
        }
    }
}

class AutomergeObject {
    private(set) var dict: [String: AutomergeFuture] = [:]

    init() {
        dict.reserveCapacity(20)
    }

    @inline(__always) func set(_ value: AutomergeValue, for key: String) {
        dict[key] = .value(value)
    }

    @inline(__always) func setArray(for key: String) -> AutomergeArray {
        if case let .nestedArray(array) = dict[key] {
            return array
        }

        if case .nestedObject = dict[key] {
            preconditionFailure("For key \"\(key)\" a keyed container has already been created.")
        }

        let array = AutomergeArray()
        dict[key] = .nestedArray(array)
        return array
    }

    @inline(__always) func setObject(for key: String) -> AutomergeObject {
        if case let .nestedObject(object) = dict[key] {
            return object
        }

        if case .nestedArray = dict[key] {
            preconditionFailure("For key \"\(key)\" an unkeyed container has already been created.")
        }

        let object = AutomergeObject()
        dict[key] = .nestedObject(object)
        return object
    }

    var values: [String: AutomergeValue] {
        dict.mapValues { future -> AutomergeValue in
            switch future {
            case let .value(value):
                return value
            case let .nestedArray(array):
                return .array(array.values)
            case let .nestedObject(object):
                return .object(object.values)
            }
        }
    }
}
