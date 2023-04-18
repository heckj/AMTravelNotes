import Automerge
import Foundation

/// A type that can be represented within an Automerge document.
///
/// You can encode your own types to be used as scalar values in Automerge, or within ``ObjType/List`` or
/// ``ObjType/Map``
/// by conforming your type to `AutomergeRepresentable`.
/// Implement ``AutomergeRepresentable/toValue(doc:objId:)`` and ``AutomergeRepresentable/fromValue(_:)``with your
/// preferred encoding.
///
/// To treat your type as a scalar value with atomic updates, return a value of``ScalarValue/Bytes(_:)`` with the data
/// encoded
/// into the associated type, and read the bytes through ``AutomergeRepresentable/fromValue(_:)`` to decode into your
/// type.
public protocol AutomergeRepresentable {
    /// Converts the Automerge representation to a local type, or returns a failure
    /// - Parameter val: The Automerge ``Value`` to be converted as a scalar value into a local type.
    /// - Returns: The type, converted to a local type, or an error indicating the reason for the conversion failure.
    ///
    /// The protocol accepts defines a function to accept a ``Value`` primarily for convenience.
    /// ``Value`` is a higher level enumeration that can include object types such as ``ObjType/List``, ``ObjType/Map``,
    /// and ``ObjType/Text``.
    static func fromValue(_ val: Value) throws -> Self

    /// Converts a local type into an Automerge Value type.
    /// - Parameters:
    ///   - doc: The document your type is mapping into.
    ///   - objId: The object id.
    /// - Returns: The ``ScalarValue`` that aligns with the provided type or an error indicating the reason for the
    /// conversion failure.
    func toValue(doc: Document, objId: ObjId) throws -> Value
}

// MARK: Boolean Conversions

///// A failure to convert an Automerge scalar value to or from a Boolean representation.
// public enum BooleanScalarConversionError: LocalizedError {
//    case notbool(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notbool(val):
//            return "Failed to read the scalar value \(val) as a Boolean."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension Bool: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> Self {
        switch val {
        case let .Scalar(.Boolean(b)):
            return b
        default:
            throw BooleanScalarConversionError.notbool(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.Boolean(self))
    }
}

// MARK: String Conversions

///// A failure to convert an Automerge scalar value to or from a String representation.
// public enum StringScalarConversionError: LocalizedError {
//    case notstring(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notstring(val):
//            return "Failed to read the scalar value \(val) as a String."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension String: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> String {
        switch val {
        case let .Scalar(.String(s)):
            return s
        default:
            throw StringScalarConversionError.notstring(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.String(self))
    }
}

// MARK: Bytes Conversions

///// A failure to convert an Automerge scalar value to or from a byte representation.
// public enum BytesScalarConversionError: LocalizedError {
//    case notbytes(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notbytes(val):
//            return "Failed to read the scalar value \(val) as a bytes."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension Data: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> Data {
        switch val {
        case let .Scalar(.Bytes(d)):
            return d
        default:
            throw BytesScalarConversionError.notbytes(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) throws -> Value {
        .Scalar(.Bytes(self))
    }
}

// MARK: UInt Conversions

///// A failure to convert an Automerge scalar value to or from an unsigned integer representation.
// public enum UIntScalarConversionError: LocalizedError {
//    case notUInt(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notUInt(val):
//            return "Failed to read the scalar value \(val) as an unsigned integer."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension UInt: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> UInt {
        switch val {
        case let .Scalar(.Uint(d)):
            return UInt(d)
        default:
            throw UIntScalarConversionError.notUInt(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.Uint(UInt64(self)))
    }
}

// MARK: Int Conversions

///// A failure to convert an Automerge scalar value to or from a signed integer representation.
// public enum IntScalarConversionError: LocalizedError {
//    case notInt(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notInt(val):
//            return "Failed to read the scalar value \(val) as a signed integer."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension Int: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> Int {
        switch val {
        case let .Scalar(.Int(d)):
            return Int(d)
        default:
            throw IntScalarConversionError.notInt(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.Int(Int64(self)))
    }
}

// MARK: Double Conversions

///// A failure to convert an Automerge scalar value to or from a 64-bit floating-point value representation.
// public enum DoubleScalarConversionError: LocalizedError {
//    case notDouble(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notDouble(val):
//            return "Failed to read the scalar value \(val) as a 64-bit floating-point value."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension Double: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> Double {
        switch val {
        case let .Scalar(.F64(d)):
            return Double(d)
        default:
            throw DoubleScalarConversionError.notDouble(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.F64(self))
    }
}

// MARK: Timestamp Conversions

///// A failure to convert an Automerge scalar value to or from a timestamp representation.
// public enum TimestampScalarConversionError: LocalizedError {
//    case notTimetamp(_ val: Value)
//
//    /// A localized message describing what error occurred.
//    public var errorDescription: String? {
//        switch self {
//        case let .notTimetamp(val):
//            return "Failed to read the scalar value \(val) as a timestamp value."
//        }
//    }
//
//    /// A localized message describing the reason for the failure.
//    public var failureReason: String? { nil }
// }

extension Date: AutomergeRepresentable {
    public static func fromValue(_ val: Value) throws -> Date {
        switch val {
        case let .Scalar(.Timestamp(d)):
            return Date(timeIntervalSince1970: TimeInterval(d))
        default:
            throw TimestampScalarConversionError.notTimetamp(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.Timestamp(Int64(timeIntervalSince1970)))
    }
}

extension Counter: AutomergeRepresentable {
    public typealias ConvertError = CounterScalarConversionError
    public static func fromValue(_ val: Value) throws -> Counter {
        switch val {
        case let .Scalar(.Counter(d)):
            return Counter(d)
        default:
            throw CounterScalarConversionError.notCounter(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.Counter(Int64(value)))
    }
}
