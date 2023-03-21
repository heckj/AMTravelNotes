//
//  AmProp.swift
//  TodoExample
//
//  Created by Alex Good on 22/02/2023.
//

import Foundation

import class Automerge.Document
import struct Automerge.ObjId
import enum Automerge.Value
import enum Automerge.ScalarValue
import struct SwiftUI.Binding
import Combine

typealias AMValue = Automerge.Value

protocol FromAmValue {
    associatedtype ConvertError: Error
    static func fromAmValue(_ val: AMValue) -> Result<Self, ConvertError>
}

protocol ToAmValue {
    func toAmValue() -> ScalarValue
}

enum BadBool: Error {
    case notbool
}

extension Bool: FromAmValue {
    typealias ConvertError = BadBool
    static func fromAmValue(_ val: AMValue) -> Result<Self, BadBool> {
        switch val {
        case .Scalar(.Boolean(let b)):
            return .success(b)
        default:
            return .failure(BadBool.notbool)
        }
    }
}

extension Bool: ToAmValue {
    func toAmValue() -> ScalarValue {
        .Boolean(self)
    }
}

enum BadString: Error {
    case notstring
}

extension String: FromAmValue {
    typealias ConvertError = BadString
    static func fromAmValue(_ val: AMValue) -> Result<String, BadString> {
        switch val {
        case .Scalar(.String(let s)):
            return .success(s)
        default:
            return .failure(BadString.notstring)
        }
    }
}

extension String: ToAmValue {
    func toAmValue() -> ScalarValue {
        .String(self)
    }
}

protocol HasDoc {
    var doc: Document { get }
}

protocol HasObj {
    var obj: ObjId { get }
}

@propertyWrapper
struct AmScalarProp<Value: FromAmValue & ToAmValue> {
    var key: String
    
    init(_ key: String) {
        self.key = key
    }
    
    static subscript<T: ObservableObject & HasDoc & HasObj>(
        _enclosingInstance instance: T,
        wrapped wrappedKeyPath: KeyPath<T, Value>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Value {
        get {
            let doc = instance.doc
            let obj = instance.obj
            let key = instance[keyPath: storageKeyPath].key
            let amval = try! doc.get(obj: obj, key: key)!
            if case let .success(v) = Value.fromAmValue(amval) {
                return v
            } else {
                fatalError("description not text")
            }
        }
        set {
            let publisher = instance.objectWillChange
            // This assumption is definitely not safe to make in
            // production code, but it's fine for this demo purpose:
            (publisher as! ObservableObjectPublisher).send()
            
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            try! doc.put(obj: obj, key: key, value: newValue.toAmValue())
        }
    }
    
    static subscript<T: HasDoc & HasObj & ObservableObject>(
        _enclosingInstance instance: T,
        projected wrappedKeyPath: KeyPath<T, Binding<Value>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<Value> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            let binding: Binding<Value> = scalarPropBinding(doc: doc, objId: obj, key: key, observer: instance)
            return binding
        }
        @available(*, unavailable,
                    message: "@Concatenating projected value is readonly")
        set {}
    }
    
    @available(*, unavailable)
    var wrappedValue: Value  {
        fatalError("not available")
    }
    
    @available(*, unavailable)
    var projectedValue: Binding<Value>  {
        fatalError("not available")
    }
}

func scalarPropBinding<V: FromAmValue & ToAmValue, O: ObservableObject>(doc: Document, objId: ObjId, key: String, observer: O) -> Binding<V> {
        Binding(
            get: {
                let amval = try! doc.get(obj: objId, key: key)!
                if case let .success(v) = V.fromAmValue(amval) {
                    return v
                } else {
                    fatalError("description not text")
                }
            },
            set: { newValue in
                let publisher = observer.objectWillChange
                // This assumption is definitely not safe to make in
                // production code, but it's fine for this demo purpose:
                (publisher as! ObservableObjectPublisher).send()
                try! doc.put(obj: objId, key: key, value: newValue.toAmValue())
            }
        )
}

func textBinding<O: ObservableObject>(doc: Document, objId: ObjId, key: String, observer: O) -> Binding<String> {
    return Binding(
        get: { () -> String in
            if case let .Object(id, .Text) = try! doc.get(obj: objId, key: key)! {
                return try! doc.text(obj: id)
            } else {
                fatalError("\(key) not text")
            }
        },
        set: { (newValue: String) -> Void in
            let publisher = observer.objectWillChange
            // This assumption is definitely not safe to make in
            // production code, but it's fine for this demo purpose:
            (publisher as! ObservableObjectPublisher).send()
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
    
    static subscript<T: ObservableObject & HasDoc & HasObj>(
        _enclosingInstance instance: T,
        wrapped wrappedKeyPath: KeyPath<T, String>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> String {
        get {
            let doc = instance.doc
            let obj = instance.obj
            let key = instance[keyPath: storageKeyPath].key
            if case let .Object(id, .Text) = try! doc.get(obj:obj, key:key) {
                return try! doc.text(obj: id)
            } else {
                fatalError("\(key) not text")
            }
        }
        set {
            let publisher = instance.objectWillChange
            // This assumption is definitely not safe to make in
            // production code, but it's fine for this demo purpose:
            (publisher as! ObservableObjectPublisher).send()
                
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            try! updateText(doc: doc, objId: obj, key: key, newText: newValue)
        }
    }
    
    static subscript<T: HasDoc & HasObj & ObservableObject>(
        _enclosingInstance instance: T,
        projected wrappedKeyPath: KeyPath<T, Binding<String>>,
        storage storageKeyPath: KeyPath<T, Self>
    ) -> Binding<String> {
        get {
            let doc = instance.doc
            let key = instance[keyPath: storageKeyPath].key
            let obj = instance.obj
            return textBinding(doc: doc, objId: obj, key: key, observer: instance)
        }
        @available(*, unavailable,
                    message: "@Concatenating projected value is readonly")
        set {}
    }
    
    @available(*, unavailable)
    var wrappedValue: String  {
        fatalError("not available")
    }
    
    @available(*, unavailable)
    var projectedValue: Binding<String>  {
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
                let index = offset - removed + inserted;
                let char = String(bytes: [element], encoding: .utf8)
                try! doc.spliceText(obj: textId, start: UInt64(index), delete: 0, value: char)
                inserted += 1
            case let .remove(offset, _, _):
                let index = offset - removed + inserted;
                try! doc.spliceText(obj: textId, start: UInt64(index), delete: 1)
                removed += 1
            }
        }
    } else {
        fatalError("\(key) not text")
    }
}
