import enum Automerge.Prop

// rough equivalent to an opaque path - serves a similar function to Automerge.PathElement
// but from an external, path-only point of view to reference or build a potentially existing
// schema within Automerge.

/// A type that maps provides a coding key value with an enumeration.
public struct SchemaPathElement: Equatable {
    private let pathElement: Automerge.Prop

    init(_ pathProperty: Automerge.Prop) {
        pathElement = pathProperty
    }

    /// Indicates whether this instance represents an index into an un-keyed container.
    var isIndex: Bool {
        if case .Index = pathElement {
            return true
        }
        return false
    }

    /// Creates a new schema path element from a generic coding key.
    /// - Parameter key: The coding key to use for internal values.
    public init(_ key: some CodingKey) {
        if let intValue = key.intValue {
            pathElement = .Index(UInt64(intValue))
        } else {
            pathElement = .Key(key.stringValue)
        }
    }

    /// Creates a new schema path element for a keyed container using the string you provide.
    /// - Parameter stringVal: The key for a keyed container.
    public init(_ stringVal: String) {
        pathElement = .Key(stringVal)
    }

    /// Creates a new schema path element for an un-keyed container using the index you provide.
    /// - Parameter intValue: The index position for an un-keyed container.
    public init(_ intValue: UInt64) {
        pathElement = .Index(intValue)
    }

    /// A coding key that represents the root of a schema hierarchy.
    ///
    /// `ROOT` conceptually maps to the equivalent of an empty array of `some CodingKey`.
    public static let ROOT = SchemaPathElement(.Key(""))
}

// MARK: CodingKey conformance

extension SchemaPathElement: CodingKey {
    /// Creates a new schema path element for an un-keyed container using the index you provide.
    ///
    /// For a non-failable initializer for ``SchemaPathElement``, use ``init(_:)``.
    ///
    /// - Parameter intValue: The index position for an un-keyed container.
    public init?(intValue: Int) {
        if intValue < 0 {
            preconditionFailure("Schema index positions can't be negative")
        }
        pathElement = Automerge.Prop.Index(UInt64(intValue))
    }

    /// Creates a new schema path element for a keyed container using the string you provide.
    ///
    /// For a non-failable initializer for ``SchemaPathElement``, use ``init(_:)``.
    ///
    /// - Parameter stringVal: The key for a keyed container.
    public init?(stringValue: String) {
        pathElement = Automerge.Prop.Key(stringValue)
    }

    /// The string value for this schema path element.
    public var stringValue: String {
        if case let .Key(stringVal) = pathElement {
            return stringVal
        }
        preconditionFailure("Invalid string value from CodingKey that is an index \(pathElement)")
    }

    /// The integer value of this schema path element.
    ///
    /// If `nil`, the schema path element is expected to be a string that represents a key for a keyed container.
    public var intValue: Int? {
        if case let .Index(intValue) = pathElement {
            return Int(intValue)
        }
        return nil
    }
}

extension SchemaPathElement: CustomStringConvertible {
    /// A string description of the schema path element.
    public var description: String {
        switch pathElement {
        case let .Index(uintVal):
            return "[\(uintVal)]"
        case let .Key(strVal):
            return strVal
        }
    }
}

extension SchemaPathElement: Hashable {
    public func hash(into hasher: inout Hasher) {
        switch pathElement {
        case let .Index(intVal):
            hasher.combine(intVal)
        case let .Key(strVal):
            hasher.combine(strVal)
        }
    }
}
