// import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
// import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

@propertyWrapper
struct AmList<Value: ObservableAutomergeBoundObject> {
    var key: String

    init(_ key: String) {
        self.key = key
    }

    // MARK: wrapped value subscript

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, Value>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Value {
        let doc = instance.doc
        guard let parentObjectId = instance.obj else {
            fatalError("enclosing instance \(instance) isn't bound, ObjId is nil.")
        }
        let key = instance[keyPath: storageKeyPath].key
        let amval = try! doc.get(obj: parentObjectId, key: key)!
        if case let .Object(newObjectId, .List) = amval {
            return Value(doc: doc, obj: newObjectId)
        } else {
            fatalError("object referenced at \(key) wasn't a List")
        }
    }

    // MARK: projected value subscript

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
