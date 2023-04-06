import Foundation
import Combine

import class Automerge.Document
import struct Automerge.ObjId

class AutomergeList: ObservableAutomergeBoundObject, Sequence, RandomAccessCollection {
        
    internal var doc: Document
    internal var obj: ObjId

    init(doc: Document, obj: ObjId) {
        precondition(obj != ObjId.ROOT, "A list object can't be bound to the Root of an Automerge document.")
        self.doc = doc
        self.obj = obj
        // It's be nice if, given an ObjId, we could verify this is a List, and not a Map
        //
        // Might be possible through
        // https://docs.rs/automerge/latest/automerge/trait.ReadDoc.html#tymethod.object_type
        // exposed up through the UniFFI layer...
    }

    // MARK: Sequence Conformance

    typealias Element = AutomergeRepresentable?
    
    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmListIterator<Element> {
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
            self.cursorIndex+=1
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

    //typealias Index = UInt64 // inferred
    typealias Iterator = AmListIterator<Element>

    var startIndex: UInt64 {
        return 0
    }
    
    func index(after i: UInt64) -> UInt64 {
        return i+1
    }

    var endIndex: UInt64 {
        return self.doc.length(obj: self.obj)
    }
    
    func index(before i: UInt64) -> UInt64 {
        return i-1
    }
    
    subscript(position: UInt64) -> AutomergeRepresentable? {
        get {
            do {
                if let amvalue = try self.doc.get(obj: self.obj, index: position) {
                    return try amvalue.dynamicType
                }
            }catch {
                // swallow errors to return nil
            }
            return nil
        }
    }

}

// class AutomergeMap: ObservableAutomergeBoundObject, Sequence
//

@dynamicMemberLookup
class AutomergeBoundObject: ObservableAutomergeBoundObject {
    internal var doc: Document
    internal var obj: ObjId

    // alternate initializer that accepts a path into the Automerge document
    init(doc: Document, obj: ObjId = ObjId.ROOT) {
        self.doc = doc
        self.obj = obj
    }
    
    // dynamic lookup for accessing internals "like a map"?
    init?(doc: Document, path: String) throws {
        self.doc = doc
        if let objId = try doc.lookupPath(path: path) {
            self.obj = objId
        } else {
            return nil
        }
    }
    
    subscript(dynamicMember member: String) -> AutomergeRepresentable? {
        do {
            if let amValue = try doc.get(obj: self.obj, key: member) {
                return try amValue.dynamicType
            }
        } catch {
            // yes, we're really swallowing any underlying errors.
        }
        return nil
    }
}

/*
 ==============================================================================
 Observable Variants of the fully dynamic bound objects - return "Value" types
 rather than casting down to specific types.
 ==============================================================================
 */


// This is a variant on AutomergeBoundObject that adds a publisher with the idea
// of getting notified when sync's happen and the underlying elements change, but nothing is yet
// wired up for that.
@dynamicMemberLookup
class DynamicAutomergeObject: ObservableAutomergeBoundObject {
    var objectWillChange: ObservableObjectPublisher
    var doc: Document
    var obj: ObjId
    
    
    init(doc: Document, obj: ObjId) {
        // There should be some safety check here - verifying that what we're binding
        // really is a Map object in Automerge.
        self.objectWillChange = ObservableObjectPublisher()
        self.doc = doc
        self.obj = obj
    }
    
    init?(doc: Document, path: String) throws {
        self.objectWillChange = ObservableObjectPublisher()
        self.doc = doc
        if let objId = try doc.lookupPath(path: path) {
            self.obj = objId
        } else {
            return nil
        }
    }
    
    subscript(dynamicMember member: String) -> AutomergeRepresentable? {
        do {
            if let valueType = try doc.get(obj: self.obj, key: member) {
                return try valueType.dynamicType
            }
        } catch {
            // yes, we're really swallowing any underlying errors.
        }
        return nil
    }
}
