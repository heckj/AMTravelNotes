//
//  AMTravelNotesTests.swift
//  AMTravelNotesTests
//
//  Created by Joseph Heck on 3/21/23.
//

@testable import AMTravelNotes
import Automerge
import XCTest

final class AMTravelNotesTests: XCTestCase {
    func testCheckMirror() throws {
        // Establish Document
        let doc = Document()
        let text = try! doc.putObject(obj: ObjId.ROOT, key: "notes", ty: .Text)
        try doc.put(obj: ObjId.ROOT, key: "id", value: .String("1234"))
        try doc.put(obj: ObjId.ROOT, key: "done", value: .Boolean(false))

        // Add some text
        try! doc.spliceText(obj: text, start: 0, delete: 0, value: "hello world!")

        let boundClass = TravelNotesModel(doc: doc, id: "1234", done: false)

        let mirror = Mirror(reflecting: boundClass)

        for a_child in mirror.children {
            print("Child: \(a_child)")
            let _ = a_child.label // optional string
            let _ = a_child.value // Any

            let submirror = Mirror(reflecting: a_child)
            print("    child static type: \(submirror.subjectType)")
            for grandkid in submirror.children {
                print("    grandkid: \(grandkid)")
            }

//    Child: (label: Optional("_id"), value: AMTravelNotes.AmScalarProp<Swift.String>(key: "id"))
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("_id"))
//        grandkid: (label: Optional("value"), value: AMTravelNotes.AmScalarProp<Swift.String>(key: "id"))
//    Child: (label: Optional("_done"), value: AMTravelNotes.AmScalarProp<Swift.Bool>(key: "done"))
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("_done"))
//        grandkid: (label: Optional("value"), value: AMTravelNotes.AmScalarProp<Swift.Bool>(key: "done"))
//    Child: (label: Optional("_notes"), value: AMTravelNotes.AmText(key: "notes"))
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("_notes"))
//        grandkid: (label: Optional("value"), value: AMTravelNotes.AmText(key: "notes"))
        }
        print("displayStyle: \(String(describing: mirror.displayStyle.debugDescription))")
        print("subjectType: \(mirror.subjectType)") // Type of the object being mirrored - TravelNotesModel
        print("superclassMirror: \(String(describing: mirror.superclassMirror))")
    }
}
