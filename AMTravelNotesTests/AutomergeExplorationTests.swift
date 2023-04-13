//
//  AutomergeExplorationTests.swift
//  AMTravelNotesTests
//
//  Created by Joseph Heck on 3/23/23.
//

@testable import AMTravelNotes
import Automerge
import XCTest

final class AutomergeExplorationTests: XCTestCase {
    func testPathAtRoot() throws {
        let doc = Document()
        let path = try! doc.path(obj: ObjId.ROOT)
        // print("\(path)")
        XCTAssertEqual(path, [])
    }

    func testPath() throws {
        XCTAssertNotNil(DocumentCache.objId)
        XCTAssertEqual(DocumentCache.objId.count, 0)

        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        let deeplyNestedText = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)

        XCTAssertEqual(DocumentCache.objId.count, 0)

        let result = try XCTUnwrap(doc.lookupPath(path: ""))
        XCTAssertEqual(result, ObjId.ROOT)

        XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: "")))
        XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: ".")))
        XCTAssertNil(try doc.lookupPath(path: "a"))
        XCTAssertNil(try doc.lookupPath(path: "a."))
        XCTAssertEqual(try doc.lookupPath(path: "list"), list)
        XCTAssertNil(try doc.lookupPath(path: "list.1"))

        // The top level object isn't a list - so an index lookup should fail with an error
        XCTAssertThrowsError(try doc.lookupPath(path: "1.a"))

        // XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: "1.a")))
        // threw error "DocError(inner: AutomergeUniffi.DocError.WrongObjectType(message: "WrongObjectType"))"
        XCTAssertEqual(try doc.lookupPath(path: "list.0"), nestedMap)
        XCTAssertEqual(try doc.lookupPath(path: "list.0"), nestedMap)
        XCTAssertEqual(try doc.lookupPath(path: "list.0.notes"), deeplyNestedText)

        print("Cache: \(DocumentCache.objId)")
        /*
         Cache: [
         ".list.0.notes": (ObjId(1010867819f53d3748a498ecc9742ebf28de0003, Automerge.ObjType.Text),
         ".list": (ObjId(1010867819f53d3748a498ecc9742ebf28de0001, Automerge.ObjType.List),
         ".list.0": (ObjId(1010867819f53d3748a498ecc9742ebf28de0002, Automerge.ObjType.Map)
         ]
         */

        // verifying cache lookups

        XCTAssertEqual(DocumentCache.objId.count, 3)
        XCTAssertNotNil(DocumentCache.objId[".list"])
        XCTAssertNil(DocumentCache.objId["list"])
        XCTAssertNil(DocumentCache.objId["a"])
    }

    func testPathElementListToPath() throws {
        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        let deeplyNestedText = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)
        let pathToList = try! doc.path(obj: nestedMap)
        XCTAssertEqual(
            pathToList,
            [
                PathElement(
                    obj: ObjId.ROOT,
                    prop: .Key("list")
                ),
                PathElement(
                    obj: list,
                    prop: .Index(0)
                ),
            ]
        )
        XCTAssertEqual(pathToList.stringPath(), "list.0")

        let pathToText = try! doc.path(obj: deeplyNestedText)
        // print("textPath: \(pathToText)")
        XCTAssertEqual(
            pathToText,
            [
                PathElement(
                    obj: ObjId.ROOT,
                    prop: .Key("list")
                ),
                PathElement(
                    obj: list,
                    prop: .Index(0)
                ),
                PathElement(
                    obj: nestedMap,
                    prop: .Key("notes")
                ),
            ]
        )
        XCTAssertEqual(pathToText.stringPath(), "list.0.notes")
    }

    func testExample() throws {
        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        let deeplyNestedText = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)
        let path = try! doc.path(obj: nestedMap)
        XCTAssertEqual(
            path,
            [
                PathElement(
                    obj: ObjId.ROOT,
                    prop: .Key("list")
                ),
                PathElement(
                    obj: list,
                    prop: .Index(0)
                ),
            ]
        )
        let textPath = try! doc.path(obj: deeplyNestedText)
        print("textPath: \(textPath)")
        XCTAssertEqual(
            textPath,
            [
                PathElement(
                    obj: ObjId.ROOT,
                    prop: .Key("list")
                ),
                PathElement(
                    obj: list,
                    prop: .Index(0)
                ),
                PathElement(
                    obj: nestedMap,
                    prop: .Key("notes")
                ),
            ]
        )
    }

    func testReadBeyondIndex() throws {
        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        // let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)

        // intentionally beyond end of list
        XCTAssertNoThrow(try doc.get(obj: list, index: 32))
        let experiment: Value? = try doc.get(obj: list, index: 32)
        XCTAssertNil(experiment)
        // print(String(describing: experiment))
    }

    func testInsertBeyondIndex() throws {
        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)

        try doc.insert(obj: list, index: 0, value: .Int(0))
        try doc.insert(obj: list, index: 1, value: .Int(1))
        try doc.insert(obj: list, index: 2, value: .Int(2))

        // If you attempt to insert beyond the index/length of the existing array, you'll
        // get a DocError - with an inner error describing: index out of bounds
        XCTAssertEqual(doc.length(obj: list), 3)

        XCTAssertEqual(Value.Scalar(.Int(0)), try doc.get(obj: list, index: 0))
        XCTAssertEqual(Value.Scalar(.Int(1)), try doc.get(obj: list, index: 1))
        XCTAssertEqual(Value.Scalar(.Int(2)), try doc.get(obj: list, index: 2))
        XCTAssertNil(try doc.get(obj: list, index: 3))
        XCTAssertNil(try doc.get(obj: list, index: 4))
    }
}
