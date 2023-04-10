import Combine
import Foundation

import class Automerge.Document
import struct Automerge.ObjId

class AutomergeList<T>: ObservableAutomergeBoundObject, Sequence, RandomAccessCollection {
    internal var doc: Document
    internal var obj: ObjId

    init(doc: Document, obj: ObjId) {
        precondition(obj != ObjId.ROOT, "A list object can't be bound to the Root of an Automerge document.")
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

    // MARK: Sequence Conformance

    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmListIterator<T> {
        AmListIterator(doc: self.doc, objId: self.obj)
    }

    struct AmListIterator<Element>: IteratorProtocol {
        private let doc: Document
        private let objId: ObjId
        private var cursorIndex: UInt64
        private let length: UInt64

        init(doc: Document, objId: ObjId) {
            self.doc = doc
            self.objId = objId
            self.cursorIndex = 0
            self.length = doc.length(obj: objId)
        }

        mutating func next() -> Element? {
            if cursorIndex >= length {
                return nil
            }
            self.cursorIndex += 1
            if let result = try! doc.get(obj: objId, index: cursorIndex) {
                do {
                    return try result.dynamicType as? Element
                } catch {
                    // yes, we're really swallowing any underlying errors.
                }
            }
            return nil
        }
    }

    // MARK: RandomAccessCollection Conformance

    // typealias Index = UInt64 // inferred
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
        self.doc.length(obj: self.obj)
    }

    subscript(position: UInt64) -> T {
        do {
            if let amvalue = try self.doc.get(obj: self.obj, index: position) {
                return try amvalue.dynamicType as? T
            }
        } catch {
            // swallow errors to return nil
        }
    }
}
