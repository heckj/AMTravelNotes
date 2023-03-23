//
//  AmProp.swift
//  TodoExample
//
//  Created by Alex Good on 22/02/2023.
//

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ObjType
import enum Automerge.ScalarValue
import Combine
import Foundation
import SwiftUI

enum LoadItemError: Error {
    case automerge
    case invalid(String)
}

// mixing the Automerge doc & Observable object with an explicit marker for a
// directly usable publisher to participate in send()
protocol ObservableAutomergeDocumentBound: ObservableObject, HasDoc, HasObj {
    var objectWillChange: ObservableObjectPublisher { get }
    var doc: Document { get }
}

// @AmList("myList") -> something that acts like a collection, but is bound to Document
// @AmObject("myOtherObject") -> something that acts like an object/map, but is bound to Document


// Path examples:
// . -> Root
// .done -> property 'done' on Root
// .pages -> property 'pages' on Root
// .pages.2 -> 3rd element in the list object that's at 'pages' on Root
// .pages.2.title -> title property of Map object in the 3rd list item under 'pages' on Root

// When creating a new schema from a path - we'll need to have a sense of what type of Value is getting splatted into place
// I don't think Automerge needs it, but we'll want it for a type declaration within the Swift side of things.

class AutomergeBoundList<T>: ObservableAutomergeDocumentBound, Sequence {
    typealias Element = T
    
    internal var doc: Document
    internal var obj: ObjId
    
    init(doc: Document, obj: ObjId) {
        precondition(obj != ObjId.ROOT, "A list object can't be bound to the Root of an Automerge document.")
        self.doc = doc
        self.obj = obj
    }
    
    /// Returns an iterator over the elements of this sequence.
    func makeIterator() -> AmListIterator<T> {
        AmListIterator()
    }

    struct AmListIterator<Element>: IteratorProtocol {
        mutating func next() -> Element? {
            return nil
        }
    }
}

class AutomergeBoundObject: ObservableAutomergeDocumentBound {
    internal var doc: Document
    internal var obj: ObjId
    
    // alternate initializer that accepts a path into the Automerge document
    init(doc: Document, obj: ObjId = ObjId.ROOT) {
        self.doc = doc
        self.obj = obj
    }
}

class TravelNotesModel: AutomergeBoundObject, Identifiable {
    @AmScalarProp("id") var id: String
    @AmScalarProp("done") var done: Bool
    @AmText("notes") var notes: String
    
    init(doc: Document, id: String, done: Bool) {
        super.init(doc: doc)
    }
}

class TodoItem: Identifiable, ObservableObject, HasDoc, HasObj {
    var obj: ObjId
    var doc: Document
    var subscriber: AnyCancellable?

    @AmText("description") var description: String
    @AmScalarProp("id") var id: String
    @AmScalarProp("done") var done: Bool

    fileprivate init(doc: Document, objId: ObjId) throws {
        self.doc = doc
        self.obj = objId
    }
}

class TodoItems: ObservableObject {
    var name: String
    var doc: Document
    private var itemsObjId: ObjId

    init(name: String, initDoc: Document) {
        doc = initDoc.fork()
        self.name = name
        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
            itemsObjId = id
        } else {
            fatalError("no items")
        }
    }

    func load(bytes: Data) {
        doc = try! Document(bytes)
        self.objectWillChange.send()
        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
            itemsObjId = id
        } else {
            fatalError("no items")
        }
    }

    var items: [TodoItem] {
        print("calculating items on \(name)")
        var items: [TodoItem] = []
        for key in doc.keys(obj: itemsObjId) {
            let val = try! doc.get(obj: itemsObjId, key: key)
            switch val {
            case let .Object(id, .Map):
                let item = try! TodoItem(doc: doc, objId: id)
                let cancel = item.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
                item.subscriber = cancel
                items.append(item)
            default:
                fatalError("item not a map")
            }
        }
        return items
    }

    func addItem(_ desc: String) {
        self.objectWillChange.send()
        let id = UUID().uuidString
        let obj = try! doc.putObject(obj: itemsObjId, key: id, ty: .Map)
        try! doc.put(obj: obj, key: "done", value: .Boolean(false))
        try! doc.put(obj: obj, key: "id", value: .String(id))
        let text = try! doc.putObject(obj: obj, key: "description", ty: .Text)
        try! doc.spliceText(obj: text, start: 0, delete: 0, value: desc)
    }

    func save() -> Data {
        self.doc.save()
    }
}
