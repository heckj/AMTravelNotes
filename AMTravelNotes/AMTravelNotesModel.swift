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

    var computedProperty: Bool {
        done
    }

    #if os(iOS)
    @AmList("images") var images: AutomergeList<UIImage>
    #elseif os(macOS)
    @AmList("images") var images: AutomergeList<NSImage>
    #endif

    // @AmMap("map") var myMap: AMMap<String, FOO>()
    // @AmObject("myObject") var anInstance: AMObject() // non-dynamic version of AutomergeBoundObject

    required init(doc: Document, obj: ObjId = ObjId.ROOT) {
        super.init(doc: doc, obj: obj)
    }
}

struct CoupleOfThings: Identifiable {
    let id: UUID
    let timestamp: Date
    let note: String

    init(id: UUID = UUID(), timestamp: Date = Date.now, note: String) {
        self.id = id
        self.timestamp = timestamp
        self.note = note
    }
}
