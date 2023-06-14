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
