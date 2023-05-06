import class Automerge.Document
import struct Automerge.ObjId

public struct AutomergeEncoder {
    public var userInfo: [CodingUserInfoKey: Any] = [:]
    var doc: Document

    public init(doc: Document) {
        self.doc = doc
    }

    public func encode<T: Encodable>(_ value: T, at objId: ObjId = ObjId.ROOT) throws {
        precondition(doc.objectType(obj: objId) == .Map, "The object with id: \(objId) is not a Map CRDT.")
        let encoder = AutomergeEncoderImpl(
            userInfo: userInfo,
            codingPath: [],
            doc: self.doc,
            objectId: objId
        )
        try value.encode(to: encoder)
    }

//    public func encode<T: Encodable>(_ value: T, onto objId: ObjId, as key: String) throws {
//        precondition(doc.objectType(obj: objId) == .Map, "The object with id: \(objId) is not a Map CRDT.")
//        let _: AutomergeValue = try encodeAsAutomergeValue(value)
//    }
//
//    public func encode<T: Encodable>(_ value: T, onto objId: ObjId, at index: Int) throws {
//        precondition(doc.objectType(obj: objId) == .List, "The object with id: \(objId) is not a List CRDT.")
//        let _: AutomergeValue = try encodeAsAutomergeValue(value)
//    }

    // or some variation that accepts a "path" string:
//        precondition(doc.objectType(obj: obj) == .Map, "The object with id: \(obj) is not a Map CRDT.")
//        self.doc = doc
//        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
//            self.obj = objId
//        } else {
//            return nil
//        }
}

/// The internal implementation of AutomergeEncoder.
///
/// Instances of the class capture one of the various kinds of schema value types - single value, array, or object.
/// The instance also tracks the dynamic state associated with that value as it encodes types you provide.
class AutomergeEncoderImpl {
    let userInfo: [CodingUserInfoKey: Any]
    let codingPath: [CodingKey]
    let document: Document
    let objectId: ObjId

    // Only one of these optional properties is expected to be valid at a time,
    // effectively exposed on the instance as the `value` property.
    var singleValue: AutomergeValue?
    var array: AutomergeArray?
    var object: AutomergeObject?

    var value: AutomergeValue? {
        if let object = self.object {
            return .object(object.values)
        }
        if let array = self.array {
            return .array(array.values)
        }
        return self.singleValue
    }

    init(userInfo: [CodingUserInfoKey: Any], codingPath: [CodingKey], doc: Document, objectId: ObjId) {
        self.userInfo = userInfo
        self.codingPath = codingPath
        self.document = doc
        self.objectId = objectId
    }
}

// A bit of example code that someone might implement to provide Encodable conformance
// for their own type.
//
//
// extension Coordinate: Encodable {
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(latitude, forKey: .latitude)
//        try container.encode(longitude, forKey: .longitude)
//
//        var additionalInfo = container.nestedContainer(keyedBy: AdditionalInfoKeys.self, forKey: .additionalInfo)
//        try additionalInfo.encode(elevation, forKey: .elevation)
//    }
// }

// 1. encode calls to create the container for the instance, passing in available coding keys type that it'll use
// 2. iterate through the properties, and on each:
//      call container.encode(AValue, forKey: AKey)
// // container.nestedContainer creates a new keyed or unkeyed reference

extension AutomergeEncoderImpl: Encoder {
    /// Returns a KeyedCodingContainer that a developer uses when conforming to the Encodable protocol.
    /// - Parameter _: The CodingKey type that this keyed coding container expects when encoding properties.
    ///
    /// This method provides a generic, type-erased container that conforms to KeyedEncodingContainer, allowing
    /// either a developer, or compiler synthesized code, to encode single value properties or create nested containers,
    /// such as an array (nested unkeyed container) or dictionary (nested keyed container) while serializing/encoding
    /// their type.
    func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        // if the Impl already has a keyed encoding container set locally, return that value.
        if let _ = object {
            let container = AutomergeKeyedEncodingContainer<Key>(
                impl: self,
                codingPath: codingPath,
                doc: self.document,
                objectId: self.objectId
            )
            return KeyedEncodingContainer(container)
        }

        // verify that the impl doesn't already have a singleValue or unkeyed container set
        guard self.singleValue == nil, self.array == nil else {
            preconditionFailure()
        }

        // falling through, create a new AutomergeObject to represent this, and built the
        // keyed container to return with that object.
        self.object = AutomergeObject()
        let container = AutomergeKeyedEncodingContainer<Key>(
            impl: self,
            codingPath: codingPath,
            doc: self.document,
            objectId: self.objectId
        )
        return KeyedEncodingContainer(container)
    }

    /// Returns an UnkeyedEncodingContainer that a developer uses when conforming to the Encodable protocol.
    ///
    /// This method provides a generic, type-erased container that conforms to UnkeyedEncodingContainer, allowing
    /// either a developer, or compiler synthesized code, to encode single value properties or create nested containers,
    /// such as an array (nested unkeyed container) or dictionary (nested keyed container) while serializing/encoding
    /// their type.
    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let _ = array {
            return AutomergeUnkeyedEncodingContainer(
                impl: self,
                codingPath: self.codingPath,
                doc: self.document,
                objectId: self.objectId
            )
        }

        guard self.singleValue == nil, self.object == nil else {
            preconditionFailure()
        }

        self.array = AutomergeArray()
        return AutomergeUnkeyedEncodingContainer(
            impl: self,
            codingPath: self.codingPath,
            doc: self.document,
            objectId: self.objectId
        )
    }

    /// Returns a SingleValueEncodingContainer that a developer uses when conforming to the Encodable protocol.
    ///
    /// This method provides a generic, type-erased container that conforms to KeyedEncodingContainer, allowing
    /// either a developer, or compiler synthesized code, to encode single value properties or create nested containers,
    /// such as an array (nested unkeyed container) or dictionary (nested keyed container) while serializing/encoding
    /// their type.
    func singleValueContainer() -> SingleValueEncodingContainer {
        guard self.object == nil, self.array == nil else {
            preconditionFailure()
        }

        return AutomergeSingleValueEncodingContainer(
            impl: self,
            codingPath: self.codingPath,
            doc: self.document,
            objectId: self.objectId
        )
    }
}
