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
        let _ = try! doc.putObject(obj: ObjId.ROOT, key: "images", ty: .List)

        // Add some text
        try! doc.spliceText(obj: text, start: 0, delete: 0, value: "hello world!")

        let boundClass = TravelNotesModel(doc: doc)

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
        }
        print("displayStyle: \(String(describing: mirror.displayStyle.debugDescription))")
        print("subjectType: \(mirror.subjectType)") // Type of the object being mirrored - TravelNotesModel
        print("superclassMirror: \(String(describing: mirror.superclassMirror))")

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
//    Child: (label: Optional("_subObject"), value: AMTravelNotes.AmObj<AMTravelNotes.BaseAutomergeObject>(key: "meta"))
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("_subObject"))
//        grandkid: (label: Optional("value"), value: AMTravelNotes.AmObj<AMTravelNotes.BaseAutomergeObject>(key: "meta"))
//    Child: (label: Optional("_images"), value: AMTravelNotes.AmList<AMTravelNotes.AutomergeList<__C.NSImage>>(key: "images"))
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("_images"))
//        grandkid: (label: Optional("value"), value: AMTravelNotes.AmList<AMTravelNotes.AutomergeList<__C.NSImage>>(key: "images"))
//    displayStyle: Optional(Swift.Mirror.DisplayStyle.class)
//    subjectType: TravelNotesModel
//    superclassMirror: Optional(Mirror for BaseAutomergeObject)
    }

    func testMoreCheckMirror() throws {
        let example = CoupleOfThings(note: "hi")

        let mirror = Mirror(reflecting: example)

        for a_child in mirror.children {
            if case let (label?, value) = a_child {
                print(label, value)
                let labelMirror = Mirror(reflecting: label)
                let valueMirror = Mirror(reflecting: value)
                print("    label static type: \(labelMirror.subjectType)")
                print("    value static type: \(valueMirror.subjectType)")
            }
            let submirror = Mirror(reflecting: a_child)
            for grandkid in submirror.children {
                print("    grandkid: \(grandkid)")
            }
        }
        print("displayStyle: \(String(describing: mirror.displayStyle.debugDescription))")
        print("subjectType: \(mirror.subjectType)") // Type of the object being mirrored - TravelNotesModel
        print("superclassMirror: \(String(describing: mirror.superclassMirror))")

//    Child: (label: Optional("id"), value: D24CD553-92A2-4F4E-9D36-1A7226EDA7B2)
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("id"))
//        grandkid: (label: Optional("value"), value: D24CD553-92A2-4F4E-9D36-1A7226EDA7B2)
//    Child: (label: Optional("timestamp"), value: 2023-04-14 13:23:17 +0000)
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("timestamp"))
//        grandkid: (label: Optional("value"), value: 2023-04-14 13:23:17 +0000)
//    Child: (label: Optional("note"), value: "hi")
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("note"))
//        grandkid: (label: Optional("value"), value: "hi")
//    Child: (label: Optional("boolExample"), value: true)
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("boolExample"))
//        grandkid: (label: Optional("value"), value: true)
//    Child: (label: Optional("doubleExample"), value: 3.141592653589793)
//        child static type: (label: Optional<String>, value: Any)
//        grandkid: (label: Optional("label"), value: Optional("doubleExample"))
//        grandkid: (label: Optional("value"), value: 3.141592653589793)
//    displayStyle: Optional(Swift.Mirror.DisplayStyle.struct)
//    subjectType: CoupleOfThings
//    superclassMirror: nil
    }
}
