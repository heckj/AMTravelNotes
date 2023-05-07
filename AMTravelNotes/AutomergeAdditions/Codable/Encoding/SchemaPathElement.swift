import enum Automerge.Prop

// rough equivalent to an opaque path - serves a similar function to Automerge.PathElement
// but from an external, path-only point of view to reference or build a potentially existing
// schema within Automerge.
public struct SchemaPathElement: Equatable {
    private let pathElement: Automerge.Prop

    init(_ pathProperty: Automerge.Prop) {
        pathElement = pathProperty
    }

    var isIndex: Bool {
        if case .Index = pathElement {
            return true
        }
        return false
    }

    init(_ key: some CodingKey) {
        if let intValue = key.intValue {
            pathElement = .Index(UInt64(intValue))
        } else {
            pathElement = .Key(key.stringValue)
        }
    }

    init(_ stringVal: String) {
        pathElement = .Key(stringVal)
    }

    init(_ intValue: UInt64) {
        pathElement = .Index(intValue)
    }

    public static let ROOT = SchemaPathElement(.Key(""))
}

// MARK: CodingKey conformance

extension SchemaPathElement: CodingKey {
    public init?(intValue: Int) {
        if intValue < 0 {
            preconditionFailure("Schema index positions can't be negative")
        }
        pathElement = Automerge.Prop.Index(UInt64(intValue))
    }

    public init?(stringValue: String) {
        pathElement = Automerge.Prop.Key(stringValue)
    }

    public var stringValue: String {
        if case let .Key(stringVal) = pathElement {
            return stringVal
        }
        preconditionFailure("Invalid string value from CodingKey that is an index \(pathElement)")
    }

    public var intValue: Int? {
        if case let .Index(intValue) = pathElement {
            return Int(intValue)
        }
        return nil
    }
}

extension SchemaPathElement: CustomStringConvertible {
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
