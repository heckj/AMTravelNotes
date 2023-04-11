import Automerge
import Foundation

/// A type that can be represented within an Automerge document.
public protocol AutomergeTypeRepresentable {
    /// The error type associated with failed attempted conversion into or out of Automerge representation.
    associatedtype ConvertError: LocalizedError

    /// Converts the Automerge representation to a local type, or returns a failure
    /// - Parameter val: The Automerge ``Value`` to be converted as a scalar value into a local type.
    /// - Returns: The type, converted to a local type, or an error indicating the reason for the failure to convert.
    ///
    /// The protocol accepts defines a function to accept a ``Value`` primarily for convenience.
    /// ``Value`` is a higher level enumeration that can include object types such as ``ObjType/List``, ``ObjType/Map``,
    /// and ``ObjType/Text``.
    static func fromValue(_ val: Value) -> Result<Self, ConvertError>

    /// Converts a local type into an Automerge scalar value.
    /// - Returns: The ``ScalarValue`` that aligns with the provided type
    func toValue(_ doc: Document, objId: ObjId) -> Result<Value, ConvertError>
    // ^^ This might require options for doc: and objId: in order to know _where_ in the schema to land
    // the created value when you're fiddling with things like Objects, Maps, and Lists. Could potentially
    // also use `path` to go from a String based input and look up (or create) the relevant objId on the fly.
}

// Maybe AutomergeTypeRepresentable should _replace_ ScalarValueRepresentable entirely...

/// A type that represents all the potential options that can be represented in the schema supported by Automerge.
public enum AutomergeRepresentable: Equatable, Hashable {
    case List // [??]
    case Map // [String:??]
    case Text // String
    case bool // -> Bool
    case bytes // -> Data
    case string // -> String
    case uint // -> UInt
    case int // -> Int
    case double // -> Double
    case counter // -> Int
    case timestamp // -> Date
    // case null // this is better expressed as a full Optional<AutomergeRepresentable> type
}

// ^^ NOTE(heckj) - biggest idea here was a single enumeration that represented an internal Automerge
// type - aka Value, but without the potential tree walk to more easily convert it back out.
// Thinking now that there's little value in this setup, as it's mostly for the fully dynamic form
// of Obj/Map/Dict - and in practice that should return `Value` instead of this additional layer.

enum AutomergeRepresentableError: Error {
    case unknownScalarType(UInt8, Data)
}

extension Automerge.Value {
    var dynamicType: AutomergeRepresentable? {
        get throws {
            switch self {
            case let .Object(_, objectType):
                switch objectType {
                case .List:
                    return .List
                case .Map:
                    return .Map
                case .Text:
                    return .Text
                }
            case let .Scalar(scalarValue):
                switch scalarValue {
                case .Bytes:
                    return .bytes
                case .String:
                    return .string
                case .Uint:
                    return .uint
                case .Int:
                    return .int
                case .F64:
                    return .double
                case .Counter:
                    return .counter
                case .Timestamp:
                    return .timestamp
                case .Boolean:
                    return .bool
                case let .Unknown(typeCode: typeCode, data: data):
                    throw AutomergeRepresentableError.unknownScalarType(typeCode, data)
                case .Null:
                    return nil
                }
            }
        }
    }
}
