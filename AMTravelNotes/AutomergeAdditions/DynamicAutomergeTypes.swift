import Combine
import Foundation

import class Automerge.Document
import struct Automerge.ObjId

// MARK: Automerge 'List' overlays

class DynamicAutomergeList: ObservableAutomergeBoundObject, Sequence, RandomAccessCollection {
    internal var doc: Document
    internal var obj: ObjId?

    required init(doc: Document, obj: ObjId?) {
        if obj != nil {
            precondition(obj != ObjId.ROOT, "A list object can't be bound to the Root of an Automerge document.")
            precondition(doc.objectType(obj: obj!) == .List, "The object with id: \(obj!) is not a List CRDT.")
        }
        self.doc = doc
        self.obj = obj
    }

    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .List {
            self.obj = objId
        } else {
            return nil
        }
    }

    init?(doc: Document, _ automergeType: AutomergeType) throws {
        self.doc = doc
        if case let .List(objId) = automergeType {
            self.obj = objId
        } else {
            return nil
        }
    }

    // MARK: DynamicAutomergeList Sequence Conformance

    typealias Element = AutomergeType?

    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmListIterator<Element> {
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
            if objId != nil {
                self.length = doc.length(obj: objId!)
            } else {
                self.length = 0
            }
        }

        mutating func next() -> Element? {
            if cursorIndex >= length || objId == nil {
                return nil
            }
            self.cursorIndex += 1
            if let result = try! doc.get(obj: objId!, index: cursorIndex) {
                do {
                    return try result.automergeType as? Element
                } catch {
                    // yes, we're really swallowing any underlying errors.
                }
            }
            return nil
        }
    }

    // MARK: DynamicAutomergeList RandomAccessCollection Conformance

    // typealias Index = UInt64 // inferred
    typealias Iterator = AmListIterator<Element>

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
        guard let objId = self.obj else {
            return 0
        }
        return self.doc.length(obj: objId)
    }

    subscript(position: UInt64) -> AutomergeType? {
        do {
            if let objId = self.obj, let amvalue = try self.doc.get(obj: objId, index: position) {
                return try amvalue.automergeType
            }
        } catch {
            // swallow errors to return nil
        }
        return nil
    }
}

// MARK: Automerge 'Map' overlays

class DynamicAutomergeMap: ObservableAutomergeBoundObject, Sequence, Collection {
    internal var doc: Document
    internal var obj: ObjId?
    private var _keys: [String]

    required init(doc: Document, obj: ObjId?) {
        self.doc = doc
        self.obj = obj
        if obj != nil {
            self._keys = doc.keys(obj: obj!)
            precondition(doc.objectType(obj: obj!) == .Map, "The object with id: \(obj!) is not a Map CRDT.")
        } else {
            self._keys = []
        }
    }

    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path), doc.objectType(obj: objId) == .Map {
            self.obj = objId
            self._keys = doc.keys(obj: objId)
        } else {
            return nil
        }
    }

    init?(doc: Document, _ automergeType: AutomergeType) throws {
        self.doc = doc
        if case let .Map(objId) = automergeType {
            self.obj = objId
            self._keys = doc.keys(obj: objId)
        } else {
            return nil
        }
    }

    // MARK: DynamicAutomergeMap Sequence Conformance

    // public typealias Element = (key: Key, value: Value)
    typealias Element = (String, AutomergeType?)

    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmMapIterator<Element> {
        AmMapIterator(doc: self.doc, objId: self.obj)
    }

    struct AmMapIterator<Element>: IteratorProtocol {
        private let doc: Document
        private let objId: ObjId?
        private var cursorIndex: UInt64
        private let keys: [String]
        private let length: UInt64

        init(doc: Document, objId: ObjId?) {
            self.doc = doc
            self.objId = objId
            self.cursorIndex = 0
            if objId != nil {
                self.length = doc.length(obj: objId!)
                self.keys = doc.keys(obj: objId!)
            } else {
                self.length = 0
                self.keys = []
            }
        }

        mutating func next() -> Element? {
            if cursorIndex >= length, self.objId != nil {
                return nil
            }
            self.cursorIndex += 1
            let currentKey = keys[Int(cursorIndex)]
            if let result = try! doc.get(obj: objId!, key: currentKey) {
                do {
                    let amrep = try result.automergeType
                    return (currentKey, amrep) as? Element
                } catch {
                    // yes, we're really swallowing any underlying errors.
                }
            }
            return nil
        }
    }

    // MARK: DynamicAutomergeMap Collection Conformance

    // typealias Index = Int // inferred
    typealias Iterator = AmMapIterator<Element>

    var startIndex: Int {
        0
    }

    var endIndex: Int {
        _keys.count
    }

    func index(after i: Int) -> Int {
        i + 1
    }

    subscript(position: Int) -> (String, AutomergeType?) {
        let currentKey = self._keys[position]
        if let objId = self.obj, let result = try! doc.get(obj: objId, key: currentKey) {
            do {
                let amrep = try result.automergeType
                return (currentKey, amrep)
            } catch {
                // yes, we're really swallowing any underlying errors.
            }
        }
        return (currentKey, nil)
    }
}

@dynamicMemberLookup
class DynamicAutomergeObject: ObservableAutomergeBoundObject {
    internal var doc: Document
    internal var obj: ObjId?

    // alternate initializer that accepts a path into the Automerge document
    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
        if obj != nil {
            precondition(doc.objectType(obj: obj!) == .Map, "The object with id: \(obj!) is not a Map CRDT.")
        }
        self.doc = doc
        self.obj = obj
    }

    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path) {
            self.obj = objId
        } else {
            return nil
        }
    }

    init?(doc: Document, _ automergeType: AutomergeType) throws {
        self.doc = doc
        if case let .Map(objId) = automergeType {
            self.obj = objId
        } else {
            return nil
        }
    }

    subscript(dynamicMember member: String) -> AutomergeType? {
        do {
            if let objId = self.obj, let amValue = try doc.get(obj: objId, key: member) {
                return try amValue.automergeType
            }
        } catch {
            // yes, we're really swallowing any underlying errors.
        }
        return nil
    }
}
