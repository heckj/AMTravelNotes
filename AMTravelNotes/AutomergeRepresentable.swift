import Automerge
import Foundation

/// A type that represents all the potential options that can be represented in the schema supported by Automerge.
public enum AutomergeRepresentable: Equatable, Hashable {
    case List // [??]
    case Map // [String:??]
    case Text // String
    case bool
    case bytes
    case string
    case uint
    case int
    case double
    case counter
    case timestamp
    // case null // this is better expressed as a full Optional<AutomergeRepresentable> type

//    public func value() -> Automerge.Value {
//        switch self {
//        case .List:
//            fatalError("unimplemented")
//            //Value.Object(<#T##ObjId#>, <#T##ObjType#>)
//        case .Map:
//            fatalError("unimplemented")
//            //Value.Object(<#T##ObjId#>, <#T##ObjType#>)
//        case .Text:
//            fatalError("unimplemented")
//            //Value.Object(<#T##ObjId#>, <#T##ObjType#>)
//        case .bool:
//            Value.Scalar(.Boolean(<#T##Bool#>))
//        case .bytes:
//            <#code#>
//        case .string:
//            <#code#>
//        case .uint:
//            <#code#>
//        case .int:
//            <#code#>
//        case .double:
//            <#code#>
//        case .counter:
//            <#code#>
//        case .timestamp:
//            <#code#>
//        }
//    }
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
