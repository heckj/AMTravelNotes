import Automerge
import Foundation

/// A type that represents all the potential options that can be represented in the schema supported by Automerge.
public enum AutomergeRepresentable: Equatable, Hashable {
    case List
    case Map
    case Text
    case bool
    case bytes
    case string
    case uint
    case int
    case double
    case counter
    case timestamp
    // case null // this is better expressed as a full Optional<AutomergeRepresentable> type
}

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
