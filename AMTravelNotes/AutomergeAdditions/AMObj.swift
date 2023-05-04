// import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
// import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

@propertyWrapper
struct AmObj<Value: ObservableAutomergeContainer> {
    //              ^^ a constraint on the type of the object that the wrapper returns
    var key: String

    /// Creates a wrapper that returns a reference to a type that maps to an Automerge object.
    /// - Parameter key: The string that represents the key within the Automerge map for this property.
    init(_ key: String) {
        self.key = key
    }

    // MARK: wrapped value subscript

    static subscript<T: ObservableAutomergeContainer>(
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
        if case let .Object(newObjectId, .Map) = amval {
            return BaseAutomergeObject(doc: doc, obj: newObjectId) as! Value
        } else {
            fatalError("object referenced at \(key) wasn't a Map.")
        }
    }

    // MARK: projected value subscript

//    static subscript<T: ObservableAutomergeContainer>(
//        _enclosingInstance instance: T,
//        projected _: KeyPath<T, Binding<Value>>,
//        storage storageKeyPath: KeyPath<T, Self>
//    ) -> Binding<Value> {
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
