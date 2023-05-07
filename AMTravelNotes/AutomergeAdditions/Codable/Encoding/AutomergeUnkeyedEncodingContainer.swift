import class Automerge.Document
import struct Automerge.ObjId
import protocol Automerge.ScalarValueRepresentable

struct AutomergeUnkeyedEncodingContainer: UnkeyedEncodingContainer {
    let impl: AutomergeEncoderImpl
    let array: AutomergeArray
    let codingPath: [CodingKey]
    /// The Automerge document that the encoder writes into.
    let document: Document
    /// The objectId that this keyed encoding container maps to within an Automerge document.
    let objectId: ObjId

    private(set) var count: Int = 0
    private var firstValueWritten: Bool = false

    init(impl: AutomergeEncoderImpl, codingPath: [CodingKey], doc: Document, objectId: ObjId) {
        self.impl = impl
        array = impl.array!
        self.codingPath = codingPath
        self.document = doc
        self.objectId = objectId
    }

    // used for nested containers
    init(impl: AutomergeEncoderImpl, array: AutomergeArray, codingPath: [CodingKey], doc: Document, objectId: ObjId) {
        self.impl = impl
        self.array = array
        self.codingPath = codingPath
        self.document = doc
        self.objectId = objectId
    }

    mutating func encodeNil() throws {}

    mutating func encode(_ value: Bool) throws {
        array.append(.bool(value))
    }

    mutating func encode(_ value: String) throws {
        array.append(.string(value))
    }

    mutating func encode(_ value: Double) throws {
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath + [ArrayKey(index: count)],
                debugDescription: "Unable to encode Double.\(value) directly in JSON."
            ))
        }

        try encodeFloatingPoint(value)
    }

    mutating func encode(_ value: Float) throws {
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath + [ArrayKey(index: count)],
                debugDescription: "Unable to encode Float.\(value) directly in JSON."
            ))
        }

        try encodeFloatingPoint(value)
    }

    mutating func encode(_ value: Int) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: Int8) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: Int16) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: Int32) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: Int64) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: UInt) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: UInt8) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: UInt16) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: UInt32) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode(_ value: UInt64) throws {
        try encodeFixedWidthInteger(value)
    }

    mutating func encode<T>(_ value: T) throws where T: Encodable {
        let newPath = impl.codingPath + [ArrayKey(index: count)]
        let newEncoder = AutomergeEncoderImpl(
            userInfo: impl.userInfo,
            codingPath: newPath,
            doc: self.document,
            objectId: self.objectId
        )
        try value.encode(to: newEncoder)

        guard let value = newEncoder.value else {
            preconditionFailure()
        }

        array.append(value)
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) ->
        KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
    {
        let newPath = impl.codingPath + [ArrayKey(index: count)]
        let object = array.appendObject()
        let nestedContainer = AutomergeKeyedEncodingContainer<NestedKey>(
            impl: impl,
            object: object,
            codingPath: newPath, doc: self.document, objectId: self.objectId
        )
        return KeyedEncodingContainer(nestedContainer)
    }

    mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
        let newPath = impl.codingPath + [ArrayKey(index: count)]
        let array = array.appendArray()
        let nestedContainer = AutomergeUnkeyedEncodingContainer(
            impl: impl,
            array: array,
            codingPath: newPath,
            doc: self.document,
            objectId: self.objectId
        )
        return nestedContainer
    }

    mutating func superEncoder() -> Encoder {
        preconditionFailure()
    }
}

extension AutomergeUnkeyedEncodingContainer {
    @inline(__always) private mutating func encodeFixedWidthInteger<N: FixedWidthInteger>(_ value: N) throws {
        array.append(.int(Int64(value.description)!))
    }

    @inline(__always) private mutating func encodeFloatingPoint<N: FloatingPoint>(_ value: N)
        throws where N: CustomStringConvertible
    {
        array.append(.double(Double(value.description)!))
    }
}
