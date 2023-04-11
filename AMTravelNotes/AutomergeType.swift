import struct Automerge.ObjId
import enum Automerge.Value
import Foundation

/// A type that represents all the potential options that the Automerge schema represents.
///
/// AutomergeType is a mapping from the nested enumerations in `Automerge.Value` into a
/// single enumeration, externalizing null and the reserved `unknown` scalar type for ergonomic
/// convenience in returning consistent value from underlying Automerge data structures.
public enum AutomergeType: Equatable, Hashable {
    /// A list CRDT.
    case List(ObjId) // [??]
    /// A map CRDT.
    case Map(ObjId) // [String:??]
    /// A specialized list CRDT for representing text.
    case Text(ObjId) // String
    /// A byte buffer.
    case Bytes(Data)
    /// A string.
    case String(String)
    /// An unsigned integer.
    case Uint(UInt64)
    /// A signed integer.
    case Int(Int64)
    /// A floating point number.
    case Double(Double)
    /// An integer counter.
    case Counter(Int64)
    /// A timestamp represented by the milliseconds since UNIX epoch.
    case Timestamp(Int64)
    /// A Boolean value.
    case Boolean(Bool)
    /// An unknown, raw scalar type.
    ///
    /// This type is reserved for forward compatibility, and is not expected to be created directly.
    case Unknown(typeCode: UInt8, data: Data)

    // Automerge `Value` has an internal null type, but for the swift type comparison mechanism
    // it seems to be more effective to represent that as Optional<AutomergeRepresentable>.
}

enum AutomergeRepresentableError: Error {
    case unknownScalarType(UInt8, Data)
}

extension Automerge.Value {
    var automergeType: AutomergeType? {
        get throws {
            switch self {
            case let .Object(objId, objectType):
                switch objectType {
                case .List:
                    return .List(objId)
                case .Map:
                    return .Map(objId)
                case .Text:
                    return .Text(objId)
                }
            case let .Scalar(scalarValue):
                switch scalarValue {
                case let .Bytes(dataBuffer):
                    return .Bytes(dataBuffer)
                case let .String(stringValue):
                    return .String(stringValue)
                case let .Uint(uintValue):
                    return .Uint(uintValue)
                case let .Int(intValue):
                    return .Int(intValue)
                case let .F64(doubleValue):
                    return .Double(doubleValue)
                case let .Counter(intValue):
                    return .Counter(intValue)
                case let .Timestamp(int64Value):
                    return .Timestamp(int64Value)
                case let .Boolean(boolValue):
                    return .Boolean(boolValue)
                case let .Unknown(typeCode: typeCode, data: data):
                    throw AutomergeRepresentableError.unknownScalarType(typeCode, data)
                case .Null:
                    return nil
                }
            }
        }
    }
}
