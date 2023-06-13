import Automerge
import AutomergeSwiftAdditions
import Foundation
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// What I'd like to have as my "travel notes" schema:
//
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

struct TravelNotesModel: Codable, Identifiable {
    let id: UUID
    var title: String
    var summary: Text
    var images: [ImageSet]

    init(title: String, summary: Text, images: [ImageSet]) {
        id = UUID()
        self.title = title
        self.summary = summary
        self.images = images
    }
}

struct ImageSet: Codable {
    var image: CodableImage
    var notes: Text
}

// class TravelNotesModel: BaseAutomergeObject, Identifiable {
//    @AmScalarProp("id") var id: UUID
//    @AmScalarProp("title") var title: String
//    @AmText("summary") var notes: String
//    @AmObj("meta") var subObject: BaseAutomergeObject
//
//    #if os(iOS)
//    @AmList("images") var images: AutomergeList<UIImage>
//    #elseif os(macOS)
//    @AmList("images") var images: AutomergeList<NSImage>
//    #endif
//
//    required init(doc: Document, obj: ObjId? = ObjId.ROOT) {
//        super.init(doc: doc, obj: obj)
//
//        // TODO: check to see if it exists, and create if not
//        do {
//            guard let obj = obj else {
//                fatalError("initialized model not linked to an Automerge objectId.")
//            }
//            let _ = try! doc.putObject(obj: obj, key: "summary", ty: .Text)
//            try doc.put(obj: obj, key: "id", value: .String(UUID().uuidString))
//            let _ = try! doc.putObject(obj: obj, key: "images", ty: .List)
//        } catch {
//            fatalError("Error establishing model schema: \(error)")
//        }
//    }
// }
