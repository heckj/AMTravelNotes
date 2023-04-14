import Automerge
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

class TravelNotesModel: BaseAutomergeBoundObject, Identifiable {
    @AmScalarProp("id") var id: String
    @AmScalarProp("done") var done: Bool
    @AmText("notes") var notes: String
    @AmObj("meta") var subObject: BaseAutomergeBoundObject

    var computedProperty: Bool {
        done
    }

    #if os(iOS)
    @AmList("images") var images: AutomergeList<UIImage>
    #elseif os(macOS)
    @AmList("images") var images: AutomergeList<NSImage>
    #endif

    // @AmMap("map") var myMap: AMMap<String, FOO>()

    required init(doc: Document, obj: ObjId = ObjId.ROOT) {
        super.init(doc: doc, obj: obj)

        // TODO: check to see if it exists, and create if not
        do {
            let _ = try! doc.putObject(obj: obj, key: "notes", ty: .Text)
            try doc.put(obj: obj, key: "id", value: .String("1234"))
            try doc.put(obj: obj, key: "done", value: .Boolean(false))
            let _ = try! doc.putObject(obj: obj, key: "images", ty: .List)
            let _ = try! doc.putObject(obj: obj, key: "meta", ty: .Map)
        } catch {
            fatalError("Error establishing model schema: \(error)")
        }
    }
}

struct CoupleOfThings: Identifiable {
    let id: UUID
    let timestamp: Date
    let note: String
    let boolExample: Bool
    let doubleExample: Double

    let listExample: [Int64]
    let dictExample: [String: UInt64]

    init(id: UUID = UUID(), timestamp: Date = Date.now, note: String) {
        self.id = id
        self.timestamp = timestamp
        self.note = note
        boolExample = true
        doubleExample = Double.pi
        listExample = [5]
        dictExample = ["one": 1]
    }
}
