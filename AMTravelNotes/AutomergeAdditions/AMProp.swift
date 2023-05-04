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

    static subscript<T: ObservableAutomergeContainer>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, Value>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Value {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            // let whatIsHere = instance[keyPath: storageKeyPath] // AmScalarProp<Value>
            // ^^ this is the property wrapper itself, and we can read things from it
            // in this case \/ the `key` where we want to read from the Automerge doc

            if let parentObjectId = instance.obj {
                // The enclosing instance is 'bound' to a specific objectId, therefore
                // we attempt to retrieve the value using that objectId and the key
                // provided to the wrapper.
                let amval = try! doc.get(obj: parentObjectId, key: key)!
                switch Value.fromValue(amval) {
                case let .success(v):
                    return v
                case let .failure(errDetail):
                    fatalError("Unable to convert \(amval) to \(Value.self): \(errDetail).")
                }
            } else if let unboundStoredValue = instance.unboundStorage[key] {
                // The enclosing instance is 'unbound' therefore
                // we attempt to retrieve the value from the enclosing instance type's
                // internal storage.
                switch Value.fromScalarValue(unboundStoredValue) {
                case let .success(v):
                    return v
                case let .failure(errDetail):
                    fatalError("Unable to convert \(unboundStoredValue) to \(Value.self): \(errDetail).")
                }
            }
            fatalError(
                "enclosing instance \(instance) isn't bound and there is no internally stored value from unboundStorage."
            )
        }
        set {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            if let parentObjectId = instance.obj {
                // The enclosing instance is bound to an Automerge document and container,
                // report that a change is happening and set the value directly.
                instance.objectWillChange.send()
                try! doc.put(obj: parentObjectId, key: key, value: newValue.toScalarValue())
            } else {
                // The enclosing instance is unbound, so stash the value as a scalar in
                // the internal 'unboundStorage'.
                instance.unboundStorage[key] = newValue.toScalarValue()
            }
        }
    }

    static subscript<T: ObservableAutomergeContainer>(
        _enclosingInstance instance: T,
        projected _: KeyPath<T, Binding<Value>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<Value> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            if let parentObjectId = instance.obj {
                let binding: Binding<Value> = scalarPropBinding(
                    doc: doc,
                    objId: parentObjectId,
                    key: key,
                    observer: instance
                )
                return binding
            } else {
                fatalError("enclosing instance \(instance) isn't bound, ObjId is nil.")
            }
        }
        @available(
            *,
            unavailable,
            message: "The projected value (`Binding<Value>`) is read-only."
        )
        set {}
    }

    @available(*, unavailable)
    var wrappedValue: Value {
        fatalError("AmScalarProp is only available for reference types (classes).")
    }

    @available(*, unavailable)
    var projectedValue: Binding<Value> {
        fatalError("AmScalarProp is only available for reference types (classes).")
    }
}

func scalarPropBinding<V: ScalarValueRepresentable, O: ObservableAutomergeContainer>(
    doc: Document,
    objId: ObjId,
    key: String,
    observer: O
) -> Binding<V> {
    Binding(
        get: {
            let amval = try! doc.get(obj: objId, key: key)!
            switch V.fromValue(amval) {
            case let .success(v):
                return v
            case let .failure(errDetail):
                fatalError("Unable to convert \(amval) to \(Value.self): \(errDetail).")
            }
        },
        set: { newValue in
            observer.objectWillChange.send()
            try! doc.put(obj: objId, key: key, value: newValue.toScalarValue())
        }
    )
}
