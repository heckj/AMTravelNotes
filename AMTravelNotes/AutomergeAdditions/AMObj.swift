// import Combine
import Foundation
import struct SwiftUI.Binding

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.ScalarValue
// import protocol Automerge.ScalarValueRepresentable
import enum Automerge.Value

@propertyWrapper
struct AmObj<Value: ObservableAutomergeBoundObject> {
    //              ^^ a constraint on the type of the object that the wrapper returns
    var key: String

    init(_ key: String) {
        self.key = key
    }

    // MARK: wrapped value subscript

    static subscript<T: ObservableAutomergeBoundObject>(
        _enclosingInstance instance: T,
        wrapped _: KeyPath<T, Value>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> BaseAutomergeBoundObject {
        let doc = instance.doc
        let parentObjectId = instance.obj
        let key = instance[keyPath: storageKeyPath].key
        let amval = try! doc.get(obj: parentObjectId, key: key)!
        if case let .Object(newObjectId, .Map) = amval {
            return BaseAutomergeBoundObject(doc: doc, obj: newObjectId)
        } else {
            fatalError("object referenced at \(key) wasn't a Map")
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
