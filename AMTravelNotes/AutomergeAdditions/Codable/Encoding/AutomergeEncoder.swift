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

class AutomergeEncoderImpl {
    let userInfo: [CodingUserInfoKey: Any]
    let codingPath: [CodingKey]
    let document: Document
    let objectId: ObjId

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

extension AutomergeEncoderImpl: Encoder {
    func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
        if let _ = object {
            let container = AutomergeKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath)
            return KeyedEncodingContainer(container)
        }

        guard self.singleValue == nil, self.array == nil else {
            preconditionFailure()
        }

        self.object = AutomergeObject()
        let container = AutomergeKeyedEncodingContainer<Key>(impl: self, codingPath: codingPath)
        return KeyedEncodingContainer(container)
    }

    func unkeyedContainer() -> UnkeyedEncodingContainer {
        if let _ = array {
            return AutomergeUnkeyedEncodingContainer(impl: self, codingPath: self.codingPath)
        }

        guard self.singleValue == nil, self.object == nil else {
            preconditionFailure()
        }

        self.array = AutomergeArray()
        return AutomergeUnkeyedEncodingContainer(impl: self, codingPath: self.codingPath)
    }

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
