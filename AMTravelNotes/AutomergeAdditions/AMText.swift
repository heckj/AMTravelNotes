// import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
import enum Automerge.Value

@propertyWrapper
struct AmText {
    var key: String

    init(_ key: String) {
        self.key = key
    }

    static subscript<T: ObservableAutomergeContainer>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, String>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> String {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            if let parentObjectId = instance.obj {
                if case let .Object(id, .Text) = try! doc.get(obj: parentObjectId, key: key) {
                    return try! doc.text(obj: id)
                } else {
                    fatalError("\(key) on \(parentObjectId) doesn't reference an Automerge Text container")
                }
            } else {
                // instance is unbound, so attempt to retrieve a text value from unbound storage
                if let unboundStoredValue = instance.unboundStorage[key] {
                    switch String.fromScalarValue(unboundStoredValue) {
                    case let .success(v):
                        return v
                    case let .failure(errDetail):
                        fatalError("Unable to convert \(unboundStoredValue) to String: \(errDetail).")
                    }
                } else {
                    fatalError(
                        "enclosing instance \(instance) isn't bound and there is no internally stored value from unboundStorage."
                    )
                }
            }
        }
        set {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            if let parentObjectId = instance.obj {
                instance.objectWillChange.send()
                try! updateText(doc: doc, objId: parentObjectId, key: key, newText: newValue)
            } else {
                // The enclosing instance is unbound, so stash the value as a scalar in
                // the internal 'unboundStorage'.
                instance.unboundStorage[key] = newValue.toScalarValue()
            }
        }
    }

    static subscript<T: ObservableAutomergeContainer>(
        _enclosingInstance instance: T,
        projected _: KeyPath<T, Binding<String>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<String> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            if let parentObjectId = instance.obj {
                return textBinding(doc: doc, objId: parentObjectId, key: key, observer: instance)
            } else {
                fatalError("enclosing instance \(instance) isn't bound, ObjId is nil.")
            }
        }
        @available(
            *,
            unavailable,
            message: "The projected value (`Binding<String>`) is read-only."
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
        fatalError("The property \(key) on \(objId) is not an Automerge Text reference.")
    }
}

func textBinding<O: ObservableAutomergeContainer>(
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
                fatalError("The property \(key) on \(objId) is not an Automerge Text reference.")
            }
        },
        set: { (newValue: String) in
            observer.objectWillChange.send()
            try! updateText(doc: doc, objId: objId, key: key, newText: newValue)
        }
    )
}
