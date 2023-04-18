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

    // @AmStruct("meta2") var subObject2: CoupleOfThings

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

// alternately, I might be able to double-up on Codable representations
// to come up with an appropriate representation.
// struct -> Encodable -> JSON -> convert to Automerge types?

extension CoupleOfThings: AutomergeRepresentable {
    public enum MyStructConversionError: LocalizedError {
        case notMap(_ val: Value)
        case unimplemented

        /// A localized message describing what error occurred.
        public var errorDescription: String? {
            switch self {
            case let .notMap(val):
                return "The value \(val) is not a Map object and can't be bound to the struct."
            case .unimplemented:
                return "This feature isn't fully implemented."
            }
        }
    }

    static func fromValue(_ val: Automerge.Value) throws -> CoupleOfThings {
        guard case let .Object(mapObjectId, .Map) = val else {
            throw MyStructConversionError.notMap(val)
        }
        print(mapObjectId)
        // do the work to inspect the relevant type and bind in the keys
        // for the struct, recursively doing "the right thing", returning
        // a populated Struct "CoupleOfThings" from the underlying Automerge
        // pieces.
        throw MyStructConversionError.unimplemented
    }

    // extend to support dropping into a List and/or Map with an additional
    // option of "key" for Map and indexPosition for List?
    func toValue(doc _: Automerge.Document, objId _: Automerge.ObjId) throws -> Automerge.Value {
        // takes an instance of the struct and encodes it's various tidbits
        // into Automerge, using the provided objId (which should be a Map)
        // as the enclosing object instance

        Value.Scalar(.Null)
    }
}
