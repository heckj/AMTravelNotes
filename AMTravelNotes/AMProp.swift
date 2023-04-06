//
//  AmProp.swift
//  TodoExample
//
//  Created by Alex Good on 22/02/2023.
//
import Foundation
import Combine
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

/*
 ==============================================================================
 Property Wrappers
 ==============================================================================
 */

class TravelNotesModel: AutomergeBoundObject, Identifiable {
    @AmScalarProp("id") var id: String
    @AmScalarProp("done") var done: Bool
    @AmText("notes") var notes: String

    init(doc: Document, id _: String, done _: Bool) {
        super.init(doc: doc)
    }
}

/*
 ==============================================================================
 Property Wrappers
 ==============================================================================
 */

// @AmList("myList") -> something that acts like a collection, but is bound to Document
// @AmObject("myOtherObject") -> something that acts like an object, but is bound to Document
//   -- Supports different types annotated as objects within the map (AMProp currently)
//   - - can the wrapper initialize in the doc and objId?

// @AmMap("myDict") -> acts more like a Swift dict (values all the same type)
// @AmText("collaborativeNotes") -> acts like String w/ Binding<String>, proxying updates to Document

@propertyWrapper
struct AmList<AmListType: ObservableAutomergeBoundObject> {
    // TODO: convert to something that allows pathing into nested CRDT objects, not only top-level items
    var key: String

    init(_ key: String) {
        self.key = key
    }

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, AmListType>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> AmListType {
        get {
            let doc = instance.doc
            let obj = instance.obj
            let key = instance[keyPath: storageKeyPath].key // parameter provided by user to map into Automerge Doc
            let amval = try! doc.get(obj: obj, key: key)!
            if case let .Object(objId, .List) = amval {
                return AutomergeList(doc: doc, obj: objId) as! AmListType
            } else {
                fatalError("object referenced at \(key) wasn't a List")
            }
        }
        set {
            instance.objectWillChange.send()

            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            let theNewObjectIdForThisList = try! doc.putObject(obj: obj, key: key, ty: .List)
            print(newValue) // has the object that was "set" into this place - copy in?
//            for listItem in newValue {
//                // crap - AmListType isn't declaring object vs. scalar...
//            }
        }
    }
//
//    static subscript<T: ObservableAutomergeBoundObject>(
//        _enclosingInstance instance: T,
//        projected _: KeyPath<T, Binding<AmListType>>,
//        storage storageKeyPath: KeyPath<T, Self>
//    ) -> Binding<AmListType> {
//        get {
//            let doc = instance.doc
//            let key = instance[keyPath: storageKeyPath].key
//            let obj = instance.obj
//            let binding: Binding<Value> = scalarPropBinding(doc: doc, objId: obj, key: key, observer: instance)
//            return binding
//        }
//        @available(
//            *,
//            unavailable,
//            message: "@Concatenating projected value is readonly"
//        )
//        set {}
//    }

    @available(*, unavailable)
    var wrappedValue: Value {
        fatalError("not available")
    }

    @available(*, unavailable)
    var projectedValue: Binding<Value> {
        fatalError("not available")
    }
}

@propertyWrapper
struct AmScalarProp<Value: ScalarValueRepresentable> {
    // TODO: convert to something that allows pathing into nested CRDT objects, not only top-level items
    var key: String

    init(_ key: String) {
        self.key = key
    }

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, Value>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Value {
        get {
            let doc = instance.doc
            let obj = instance.obj
            let key = instance[keyPath: storageKeyPath].key
            let amval = try! doc.get(obj: obj, key: key)!
            if case let .success(v) = Value.fromValue(amval) {
                return v
            } else {
                fatalError("description not text")
            }
        }
        set {
            instance.objectWillChange.send()

            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            try! doc.put(obj: obj, key: key, value: newValue.toScalarValue())
        }
    }

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        projected _: KeyPath<T, Binding<Value>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<Value> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            let binding: Binding<Value> = scalarPropBinding(doc: doc, objId: obj, key: key, observer: instance)
            return binding
        }
        @available(
            *,
            unavailable,
            message: "@Concatenating projected value is readonly"
        )
        set {}
    }

    @available(*, unavailable)
    var wrappedValue: Value {
        fatalError("not available")
    }

    @available(*, unavailable)
    var projectedValue: Binding<Value> {
        fatalError("not available")
    }
}

func scalarPropBinding<V: ScalarValueRepresentable, O: ObservableAutomergeBoundObject>(
    doc: Document,
    objId: ObjId,
    key: String,
    observer: O
) -> Binding<V> {
    Binding(
        get: {
            let amval = try! doc.get(obj: objId, key: key)!
            if case let .success(v) = V.fromValue(amval) {
                return v
            } else {
                fatalError("description not text")
            }
        },
        set: { newValue in
            observer.objectWillChange.send()
            try! doc.put(obj: objId, key: key, value: newValue.toScalarValue())
        }
    )
}

func textBinding<O: ObservableAutomergeBoundObject>(
    doc: Document,
    objId: ObjId,
    key: String,
    observer: O
) -> Binding<String> {
    Binding(
        get: { () -> String in
            if case let .Object(id, .Text) = try! doc.get(obj: objId, key: key)! {
                return try! doc.text(obj: id)
            } else {
                fatalError("\(key) not text")
            }
        },
        set: { (newValue: String) in
            observer.objectWillChange.send()
            try! updateText(doc: doc, objId: objId, key: key, newText: newValue)
        }
    )
}

@propertyWrapper
struct AmText {
    var key: String

    init(_ key: String) {
        self.key = key
    }

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, String>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> String {
        get {
            let doc = instance.doc
            let obj = instance.obj
            let key = instance[keyPath: storageKeyPath].key
            if case let .Object(id, .Text) = try! doc.get(obj: obj, key: key) {
                return try! doc.text(obj: id)
            } else {
                fatalError("\(key) not text")
            }
        }
        set {
            instance.objectWillChange.send()

            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            try! updateText(doc: doc, objId: obj, key: key, newText: newValue)
        }
    }

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        projected _: KeyPath<T, Binding<String>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<String> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            return textBinding(doc: doc, objId: obj, key: key, observer: instance)
        }
        @available(
            *,
            unavailable,
            message: "@Concatenating projected value is readonly"
        )
        set {}
    }

    // Constrains the property wrapper from being used with value types
    // Forces the usage of subscripted access
    @available(*, unavailable)
    var wrappedValue: String {
        fatalError("not available")
    }

    @available(*, unavailable)
    var projectedValue: Binding<String> {
        fatalError("not available")
    }
}

func updateText(doc: Document, objId: ObjId, key: String, newText: String) throws {
    if case let .Object(textId, .Text) = try! doc.get(obj: objId, key: key) {
        let current = try! doc.text(obj: textId).utf8
        let diff: CollectionDifference<String.UTF8View.Element> = newText.utf8.difference(from: current)
        var inserted = 0
        var removed = 0
        for change in diff {
            switch change {
            case let .insert(offset, element, _):
                let index = offset - removed + inserted
                let char = String(bytes: [element], encoding: .utf8)
                try! doc.spliceText(obj: textId, start: UInt64(index), delete: 0, value: char)
                inserted += 1
            case let .remove(offset, _, _):
                let index = offset - removed + inserted
                try! doc.spliceText(obj: textId, start: UInt64(index), delete: 1)
                removed += 1
            }
        }
    } else {
        fatalError("\(key) not text")
    }
}
