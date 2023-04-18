import Automerge
import Foundation

extension UUID: AutomergeRepresentable, ScalarValueRepresentable {
    public enum UUIDConversionError: LocalizedError {
        case notString(_ val: Value)
        case notUUIDString(_ stringValue: String)

        /// A localized message describing what error occurred.
        public var errorDescription: String? {
            switch self {
            case let .notString(val):
                return "Failed to read the scalar value \(val) as a String."
            case let .notUUIDString(stringValue):
                return "Unable to use the string \(stringValue) as a UUID"
            }
        }

        /// A localized message describing the reason for the failure.
        public var failureReason: String? { nil }
    }

    // MARK: ScalarValueRepresentable implementation

    public typealias ConvertError = UUIDConversionError
    public static func fromValue(_ val: Automerge.Value) -> Result<UUID, UUIDConversionError> {
        switch val {
        case let .Scalar(.String(stringValue)):
            guard let result = UUID(uuidString: stringValue) else {
                return .failure(UUIDConversionError.notUUIDString(stringValue))
            }
            return .success(result)
        default:
            return .failure(UUIDConversionError.notString(val))
        }
    }

    public func toScalarValue() -> Automerge.ScalarValue {
        .String(uuidString)
    }

    // MARK: AutomergeRepresentable implementation

    public static func fromValue(_ val: Value) throws -> Self {
        switch val {
        case let .Scalar(.String(stringValue)):

            guard let result = UUID(uuidString: stringValue) else {
                throw UUIDConversionError.notUUIDString(stringValue)
            }
            return result
        default:
            throw UUIDConversionError.notString(val)
        }
    }

    public func toValue(doc _: Document, objId _: ObjId) -> Value {
        .Scalar(.String(uuidString))
    }
}
