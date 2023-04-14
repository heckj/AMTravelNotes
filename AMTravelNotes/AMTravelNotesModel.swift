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
    }
}

struct CoupleOfThings: Identifiable {
    let id: UUID
    let timestamp: Date
    let note: String
    let boolExample: Bool
    let doubleExample: Double
    
    let listExample: [Int64]
    let dictExample: [String:UInt64]

    init(id: UUID = UUID(), timestamp: Date = Date.now, note: String) {
        self.id = id
        self.timestamp = timestamp
        self.note = note
        self.boolExample = true
        self.doubleExample = Double.pi
        self.listExample = [5]
        self.dictExample = ["one":1]
    }
}
