import Combine
import Foundation

import class Automerge.Document
import struct Automerge.ObjId

/// A base class for classes that reference Automerge containers.
class BaseAutomergeObject: ObservableAutomergeContainer {
    internal var doc: Document
    internal var obj: ObjId?

    /// Creates a new instance of a class that references a container with an Automerge document.
    /// - Parameters:
    ///   - doc: The Automerge document associated with this reference.
    ///   - obj: An optional objectId of a `Map` type of container within an Automerge document. If `nil`, the root of
    /// the Automerge document is used.
    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
        self.doc = doc
        if let obj {
            precondition(doc.objectType(obj: obj) == .Map, "The object with id: \(obj) is not a Map CRDT.")
            self.obj = obj
        }
    }

    /// Creates a new instance of a class that references a container with an Automerge document.
    /// - Parameters:
    ///   - doc: The Automerge document associated with this reference.
    ///   - path: The string path that represents a `Map` type of container within the Automerge document.
    ///
    ///   The initializer fails if the path doesn't match any schema within the Automerge document, or if the container
    ///   referenced by the path is a List type of container.
    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            self.obj = objId
        } else {
            return nil
        }
    }

    // When you add an object into an Automerge list, start with getting an objectId that Automerge
    // provides for the new object reference:
    // public func insertObject(obj: ObjId, index: UInt64, ty: ObjType) throws -> ObjId
    // ^^ how you append an object type into an existing list

    // This could be a free function, or even a static function on Document perhaps
//    static func bind<T: BaseAutomergeObject>(_: T, in doc: Document, at path: String) throws -> T? {
//        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
//            return T(doc: doc, obj: objId)
//        }
//        return nil
//    }

    class func bind(doc: Document, path: String) throws -> Self? {
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            return Self(doc: doc, obj: objId)
        }
        return nil
    }
}
