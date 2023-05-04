import class Automerge.Document
import struct Automerge.ObjId
import Foundation

struct AutomergeSingleValueEncodingContainer: SingleValueEncodingContainer {
    let impl: AutomergeEncoderImpl
    let codingPath: [CodingKey]
    let doc: Document
    let objectId: ObjId

    private var firstValueWritten: Bool = false

    init(impl: AutomergeEncoderImpl, codingPath: [CodingKey], doc: Document, objectId: ObjId) {
        self.impl = impl
        self.codingPath = codingPath
        self.doc = doc
        self.objectId = objectId
    }

    mutating func encodeNil() throws {}

    mutating func encode(_ value: Bool) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .bool(value)
    }

    mutating func encode(_ value: Int) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: Int8) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: Int16) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: Int32) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: Int64) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(value)
    }

    mutating func encode(_ value: UInt) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: UInt8) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: UInt16) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: UInt32) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: UInt64) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .int(Int64(truncatingIfNeeded: value))
    }

    mutating func encode(_ value: Float) throws {
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: self.codingPath,
                debugDescription: "Unable to encode Float.\(value) directly in Automerge."
            ))
        }

        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .double(Double(value))
    }

    mutating func encode(_ value: Double) throws {
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: self.codingPath,
                debugDescription: "Unable to encode Double.\(value) directly in Automerge."
            ))
        }

        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .double(value)
    }

    mutating func encode(_ value: String) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .string(value)
    }

    mutating func encode(_ value: Data) throws {
        self.preconditionCanEncodeNewValue()
        self.impl.singleValue = .bytes(value)
    }

    // ?? how handle types for Counter and Timestamp

    mutating func encode<T: Encodable>(_ value: T) throws {
        self.preconditionCanEncodeNewValue()
        try value.encode(to: self.impl)
    }

    func preconditionCanEncodeNewValue() {
        precondition(
            self.impl.singleValue == nil,
            "Attempt to encode value through single value container when previously value already encoded."
        )
    }
}
