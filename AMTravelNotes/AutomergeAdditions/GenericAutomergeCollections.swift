import Combine
import Foundation

import class Automerge.Document
import struct Automerge.ObjId
import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

class BaseAutomergeBoundObject: ObservableAutomergeBoundObject {
    internal var doc: Document
    internal var obj: ObjId?

    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
        self.doc = doc
        if let obj {
            precondition(doc.objectType(obj: obj) == .Map, "The object with id: \(obj) is not a Map CRDT.")
            self.obj = obj
        }
    }

    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            self.obj = objId
        } else {
            return nil
        }
    }

    // if you're adding an object into a list, we need tp start with getting an objectId
    // back from the list we're adding into =
    // public func insertObject(obj: ObjId, index: UInt64, ty: ObjType) throws -> ObjId
    // ^^ how you append an object type into an existing list

    // We can't easily "create first, bind later" for objects with the low-level API provided.
    // begs the question - can we add to list[0], skip 1, and add list[2]? Or does that pitch
    // an error?

    // This could be a free function, or even on another object
    static func bind<T: BaseAutomergeBoundObject>(_: T, in doc: Document, at path: String) throws -> T? {
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            return T(doc: doc, obj: objId)
        }
        return nil
    }

    class func bind(doc: Document, path: String) throws -> Self? {
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            return Self(doc: doc, obj: objId)
        }
        return nil
    }
}

// NOTE(heckj): ScalarValueRepresentable has the pieces to convert into and out of types to Scalar values
// within Automerge, but I don't (yet) have the same thing for Lists or Object/Map representations.
// I want to try and accomplish that with a broader AutomergeRepresentable protocol. The initial version
// of which is relevant to READ-ONLY determine a type within Automerge, but doesn't have the bits in place
// to support conversions. When done, all AutomergeRepresentables should *also* be ScalarValueRepresentable.

class AutomergeList<T: AutomergeRepresentable>: ObservableAutomergeBoundObject, Sequence {
    internal var doc: Document
    internal var obj: ObjId?
    private var length: UInt64

    required init(doc: Document, obj: ObjId?) {
        self.doc = doc
        if let obj {
            precondition(obj != ObjId.ROOT, "A list object can't be bound to the Root of an Automerge document.")
            precondition(doc.objectType(obj: obj) == .List, "The object with id: \(obj) is not a List CRDT.")
            self.obj = obj
            self.length = doc.length(obj: obj)
        } else {
            self.obj = nil
            self.length = 0
        }
        // TODO: add validation of schema - that all list entries are convertible to type `T`
    }

    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .List {
            self.obj = objId
            self.length = doc.length(obj: objId)
            // TODO: add validation of schema - that all list entries are convertible to type `T`
        } else {
            return nil
        }
    }

    // MARK: Sequence Conformance

    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmListIterator<T> {
        AmListIterator(doc: self.doc, objId: self.obj)
    }

    struct AmListIterator<Element>: IteratorProtocol {
        private let doc: Document
        private let objId: ObjId?
        private var cursorIndex: UInt64
        private let length: UInt64

        init(doc: Document, objId: ObjId?) {
            self.doc = doc
            self.objId = objId
            self.cursorIndex = 0
            if let objId {
                self.length = doc.length(obj: objId)
            } else {
                self.length = 0
            }
        }

        mutating func next() -> Element? {
            if cursorIndex >= length {
                return nil
            }
            if let objId = self.objId {
                self.cursorIndex += 1
                if let result = try! doc.get(obj: objId, index: cursorIndex) {
                    do {
                        return try result.automergeType as? Element
                    } catch {
                        // yes, we're really swallowing any underlying errors.
                    }
                }
            }
            return nil
        }
    }
}

// MARK: AutomergeList<T> RandomAccessCollection Conformance

extension AutomergeList: RandomAccessCollection {
    // TODO: implement MutableAccessCollection
    typealias Index = UInt64 // inferred
    typealias Iterator = AmListIterator<T>

    var startIndex: UInt64 {
        0
    }

    func index(after i: UInt64) -> UInt64 {
        i + 1
    }

    func index(before i: UInt64) -> UInt64 {
        i - 1
    }

    var endIndex: UInt64 {
        length
    }

    subscript(position: UInt64) -> T {
        do {
            guard let amvalue = try self.doc.get(obj: self.obj!, index: position) else {
                fatalError("Unable to access list \(self.obj!) at index \(position)")
            }
            return try T.fromValue(amvalue)
        } catch {
            fatalError("Unable to convert value: \(error)")
        }
    }
}
