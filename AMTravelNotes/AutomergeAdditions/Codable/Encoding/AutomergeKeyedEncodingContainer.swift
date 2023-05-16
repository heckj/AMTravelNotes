import class Automerge.Document
import struct Automerge.ObjId
import protocol Automerge.ScalarValueRepresentable

struct AutomergeKeyedEncodingContainer<K: CodingKey>: KeyedEncodingContainerProtocol {
    typealias Key = K

    /// A reference to the Automerge Encoding Implementation class used for tracking encoding state.
    let impl: AutomergeEncoderImpl
    /// An instance that represents a Map being constructed in an Automerge Document that maps to the keyed container
    /// you provide to encode.
    let object: AutomergeObject
    /// An array of types that conform to CodingKey that make up the "schema path" to this instance from the root of the
    /// top-level encoded type.
    let codingPath: [CodingKey]
    /// The Automerge document that the encoder writes into.
    let document: Document
    /// The objectId that this keyed encoding container maps to within an Automerge document.
    ///
    /// If `document` is `nil`, the error attempting to retrieve should be in ``lookupError``.
    let objectId: ObjId?
    /// An error captured when attempting to look up or create an objectId in Automerge based on the coding path
    /// provided.
    let lookupError: Error?

    private var firstValueWritten: Bool = false
    /// Creates a new keyed-encoding container you use to encode into an Automerge document.
    ///
    /// After initialization, the container has one of two properties set: ``objectId`` or ``lookupError``.
    /// As the container is created and initialized, it attempts to either look up or create an Automerge objectId that
    /// maps to the relevant schema path matching from the ``codingPath``.
    /// If the lookup was successful, the property `objectId` has the proper value from the associated ``doc``.
    /// Otherwise, the initialization captures the error into ``lookupError`` and is thrown when you invoke any of the
    /// `encode` methods.
    ///
    /// Called from within a developer's type providing conformance to `Encodable`, for example:
    /// ```swift
    /// var container = encoder.container(keyedBy: CodingKeys.self)
    /// ```
    ///
    /// - Parameters:
    ///   - impl: A reference to the AutomergeEncodingImpl that this container represents.
    ///   - codingPath: An array of types that conform to CodingKey that make up the "schema path" to this instance from
    /// the root of the top-level encoded type.
    ///   - doc: The Automerge document that the encoder writes into.
    init(impl: AutomergeEncoderImpl, codingPath: [CodingKey], doc: Document) {
        self.impl = impl
        object = impl.object!
        self.codingPath = codingPath
        self.document = doc
        switch retrieveObjectId(doc: doc, path: codingPath, containerType: .Key) {
        case let .success((objId, _)):
            self.objectId = objId
            self.lookupError = nil
        case let .failure(capturedError):
            self.objectId = nil
            self.lookupError = capturedError
        }
    }

    // used for nested containers
    init(impl: AutomergeEncoderImpl, object: AutomergeObject, codingPath: [CodingKey], doc: Document) {
        self.impl = impl
        self.object = object
        self.codingPath = codingPath
        self.document = doc
        switch retrieveObjectId(doc: doc, path: codingPath, containerType: .Key) {
        case let .success((objId, _)):
            self.objectId = objId
            self.lookupError = nil
        case let .failure(capturedError):
            self.objectId = nil
            self.lookupError = capturedError
        }
    }

    fileprivate func reportBestError() -> Error {
        // Returns the best value it can from a lookup error scenario.
        if let containerLookupError = self.lookupError {
            return containerLookupError
        } else {
            // If the error wasn't captured for some reason, drop back to a more general error exposing
            // the precondition failure.
            return CodingKeyLookupError
                .unexpectedLookupFailure(
                    "Encoding called on KeyedContainer when ObjectId is nil, and there was no recorded lookup error for the path \(self.codingPath)"
                )
        }
    }

    mutating func encodeNil(forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }
        // This builds up a mirror of the schema that can be consistently walked
        object.set(.null, for: key.stringValue)
        // This writes the value into the Automerge document as the encoding process advances.
        try document.put(obj: objectId, key: key.stringValue, value: .Null)
    }

    mutating func encode(_ value: Bool, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }
        // this is where we want to call into AM to set the value on the objectId for the key provided
        object.set(.bool(value), for: key.stringValue)
        // This writes the value into the Automerge document as the encoding process advances.
        try document.put(obj: objectId, key: key.stringValue, value: .Boolean(value))
    }

    mutating func encode(_ value: String, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }
        // this is where we want to call into AM to set the value on the objectId for the key provided
        object.set(.string(value), for: key.stringValue)
        // This writes the value into the Automerge document as the encoding process advances.
        try document.put(obj: objectId, key: key.stringValue, value: .String(value))

        // NOTE(heckj): This override of the generic encode() is keyed by the type within the schema
        // and writes into Automerge as a ScalarValue of the String instead of as an Automerge
        // collaborative text instance. We may prefer to default to creating a nested Automerge Text
        // object in these cases, or have some other indicator that we can use to distinguish when a
        // String type is expected to be stored as a scalar value versus Text.
    }

    mutating func encode(_ value: Double, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath + [key],
                debugDescription: "Unable to encode Double.\(value) at \(codingPath) into an Automerge F64."
            ))
        }
        object.set(.double(value), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Float, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }
        guard !value.isNaN, !value.isInfinite else {
            throw EncodingError.invalidValue(value, .init(
                codingPath: codingPath + [key],
                debugDescription: "Unable to encode Float.\(value) directly in JSON."
            ))
        }
        object.set(.double(Double(value)), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Int, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Int8, forKey key: Self.Key) throws {
        guard let objectId = objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Int16, forKey key: Self.Key) throws {
        guard let objectId = objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Int32, forKey key: Self.Key) throws {
        guard let objectId = objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: Int64, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: UInt, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: UInt8, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: UInt16, forKey key: Self.Key) throws {
        guard let objectId = objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: UInt32, forKey key: Self.Key) throws {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode(_ value: UInt64, forKey key: Self.Key) throws {
        guard let objectId = objectId else {
            throw reportBestError()
        }

        object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode<T>(_ value: T, forKey key: Self.Key) throws where T: ScalarValueRepresentable {
        guard let objectId = self.objectId else {
            throw reportBestError()
        }

        // object.set(.int(Int64(value.description)!), for: key.stringValue)
        try document.put(obj: objectId, key: key.stringValue, value: value.toScalarValue())
    }

    mutating func encode<T>(_ value: T, forKey key: Self.Key) throws where T: Encodable {
        let newPath = impl.codingPath + [key]
        // this is where we need to figure out what the encodable type is in order to create
        // the correct Automerge objectType underneath the covers.
        // For example - for encoding another struct, class, or dict - we'd want to make it .map,
        // array or list would be .list, and for a singleValue property we don't want to create a new
        // objectId.
        // This should ideally be an "upsert" - look up and find if there already, otherwise create
        // a new instance to write into...

        // as we create newEncoder, we don't have any idea what kind of thing this is - singleValue, keyed, or
        // unkeyed...
        // As such, we can't easily assert the "new" objectId - because we don't know if we need one,
        // and if so, if it's associated with singleValue (don't need a new one), keyed (need a new map one),
        // or unkeyed (need a new list one). In fact, we don't even know for sure what we'll need until
        // the Codable method `encode` is called - because that's where a container is created. So while we
        // can set this "newPath", we don't have the deets to create (if needed) a new objectId until we
        // initialize a specific container type.

        let newEncoder = AutomergeEncoderImpl(
            userInfo: impl.userInfo,
            codingPath: newPath,
            doc: self.document
        )
        try value.encode(to: newEncoder)

        guard let encodedValue = newEncoder.value else {
            preconditionFailure()
        }

        object.set(encodedValue, for: key.stringValue)
    }

    mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type, forKey key: Self.Key) ->
        KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey
    {
        let newPath = impl.codingPath + [key]
        let object = object.setObject(for: key.stringValue)
        let nestedContainer = AutomergeKeyedEncodingContainer<NestedKey>(
            impl: impl,
            object: object,
            codingPath: newPath,
            doc: self.document
        )
        return KeyedEncodingContainer(nestedContainer)
    }

    mutating func nestedUnkeyedContainer(forKey key: Self.Key) -> UnkeyedEncodingContainer {
        let newPath = impl.codingPath + [key]
        let array = object.setArray(for: key.stringValue)
        let nestedContainer = AutomergeUnkeyedEncodingContainer(
            impl: impl,
            array: array,
            codingPath: newPath,
            doc: self.document
        )
        return nestedContainer
    }

    mutating func superEncoder() -> Encoder {
        impl
    }

    mutating func superEncoder(forKey _: Self.Key) -> Encoder {
        impl
    }
}
