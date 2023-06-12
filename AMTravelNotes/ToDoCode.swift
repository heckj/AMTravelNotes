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
import enum Automerge.Value
import AutomergeSwiftAdditions
import Combine
import Foundation
import SwiftUI

enum LoadItemError: Error {
    case automerge
    case invalid(String)
}

class TodoItem: Identifiable, ObservableAutomergeContainer {
    var obj: ObjId?
    var doc: Document
    var unboundStorage: [String: Automerge.ScalarValue]
    var subscriber: AnyCancellable?

    @AmText("description") var description: String
    @AmScalarProp("id") var id: String
    @AmScalarProp("done") var done: Bool

    required init(doc: Document, obj: ObjId?) {
        self.doc = doc
        self.obj = obj
        self.unboundStorage = [:]
    }
}

//
// class TodoItems: ObservableAutomergeBoundObject {
//    var name: String
//    var doc: Document
//    internal var obj: ObjId {
//        itemsObjId
//    }
//
//    private var itemsObjId: ObjId
//
//    init(name: String, initDoc: Document) {
//        doc = initDoc.fork()
//        self.name = name
//        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
//            itemsObjId = id
//        } else {
//            fatalError("no items")
//        }
//    }
//
//    func load(bytes: Data) {
//        doc = try! Document(bytes)
//        self.objectWillChange.send()
//        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
//            itemsObjId = id
//        } else {
//            fatalError("no items")
//        }
//    }
//
//    var items: [TodoItem] {
//        print("calculating items on \(name)")
//        var items: [TodoItem] = []
//        for key in doc.keys(obj: itemsObjId) {
//            let val = try! doc.get(obj: itemsObjId, key: key)
//            switch val {
//            case let .Object(id, .Map):
//                let item = TodoItem(doc: doc, obj: id)
//                let cancel = item.objectWillChange.sink(receiveValue: { self.objectWillChange.send() })
//                item.subscriber = cancel
//                items.append(item)
//            default:
//                fatalError("item not a map")
//            }
//        }
//        return items
//    }
//
//    func addItem(_ desc: String) {
//        self.objectWillChange.send()
//        let id = UUID().uuidString
//        let obj = try! doc.putObject(obj: itemsObjId, key: id, ty: .Map)
//        try! doc.put(obj: obj, key: "done", value: .Boolean(false))
//        try! doc.put(obj: obj, key: "id", value: .String(id))
//        let text = try! doc.putObject(obj: obj, key: "description", ty: .Text)
//        try! doc.spliceText(obj: text, start: 0, delete: 0, value: desc)
//    }
//
//    func save() -> Data {
//        self.doc.save()
//    }
// }
