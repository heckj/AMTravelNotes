//
//  AmProp.swift
//  TodoExample
//
//  Created by Alex Good on 22/02/2023.
//
import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

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
            // let whatshere = instance[keyPath: storageKeyPath] // AmScalarProp<Value>
            // ^^ this is the property wrapper itself, and we can read things from it
            // in this case \/ the `key` where we want to read from the Automerge doc
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
