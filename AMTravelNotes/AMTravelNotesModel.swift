import Automerge
import AutomergeSwiftAdditions
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// What I'd like to have as my "travel notes" schema:

// - ROOT {
//     "id" - UUID (Scalar) // for comparing origins for sync
//     "title" - String (scalar)
//     "summary" - Text (collaborative)
//     "images" - LIST [
//        {
//           "image": Data (scalar) - pngRepresentation
//           "notes": Text (collaborative)
//        }
//     ]
//   }

class TravelNotesModel: BaseAutomergeObject, Identifiable {
    @AmScalarProp("id") var id: UUID
    @AmScalarProp("title") var title: String
    @AmText("summary") var notes: String
    @AmObj("meta") var subObject: BaseAutomergeObject

    #if os(iOS)
    @AmList("images") var images: AutomergeList<UIImage>
    #elseif os(macOS)
    @AmList("images") var images: AutomergeList<NSImage>
    #endif

    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
        super.init(doc: doc, obj: obj)

        // TODO: check to see if it exists, and create if not
        do {
            guard let obj = obj else {
                fatalError("initialized model not linked to an Automerge objectId.")
            }
            let _ = try! doc.putObject(obj: obj, key: "summary", ty: .Text)
            try doc.put(obj: obj, key: "id", value: .String(UUID().uuidString))
            let _ = try! doc.putObject(obj: obj, key: "images", ty: .List)
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
