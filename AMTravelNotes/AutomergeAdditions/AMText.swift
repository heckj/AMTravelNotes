// import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
// import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

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
