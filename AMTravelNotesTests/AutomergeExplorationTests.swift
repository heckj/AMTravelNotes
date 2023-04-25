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
        print("\(path)")
        XCTAssertEqual(path, [])
    }

    func testPath() throws {
        XCTAssertNotNil(PathCache.objId)
        XCTAssertEqual(PathCache.objId.count, 0)

        let doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        let deeplyNestedText = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)

        XCTAssertEqual(PathCache.objId.count, 0)

        let result = try XCTUnwrap(doc.lookupPath(path: ""))
        XCTAssertEqual(result, ObjId.ROOT)

        XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: "")))
        XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: ".")))
        XCTAssertNil(try doc.lookupPath(path: "a"))
        XCTAssertNil(try doc.lookupPath(path: "a."))
        XCTAssertEqual(try doc.lookupPath(path: "list"), list)
        XCTAssertEqual(try doc.lookupPath(path: ".list"), list)
        XCTAssertNil(try doc.lookupPath(path: "list.[1]"))

        XCTAssertThrowsError(try doc.lookupPath(path: ".list.[5]"), "Index Out of Bounds should throw an error")
        // The top level object isn't a list - so an index lookup should fail with an error
        XCTAssertThrowsError(try doc.lookupPath(path: "[1].a"))

        // XCTAssertEqual(ObjId.ROOT, try XCTUnwrap(doc.lookupPath(path: "1.a")))
        // threw error "DocError(inner: AutomergeUniffi.DocError.WrongObjectType(message: "WrongObjectType"))"
        XCTAssertEqual(try doc.lookupPath(path: "list.[0]"), nestedMap)
        XCTAssertEqual(try doc.lookupPath(path: ".list.[0]"), nestedMap)
        XCTAssertEqual(try doc.lookupPath(path: "list.[0].notes"), deeplyNestedText)
        XCTAssertEqual(try doc.lookupPath(path: ".list.[0].notes"), deeplyNestedText)
        print("Cache: \(PathCache.objId)")
        /*
         Cache: [
             ".list.[0]": (ObjId(1010d753481b2afb40a5b353e66bc0df63120002, Automerge.ObjType.Map),
             ".list": (ObjId(1010d753481b2afb40a5b353e66bc0df63120001, Automerge.ObjType.List),
             ".list.[0].notes": (ObjId(1010d753481b2afb40a5b353e66bc0df63120003, Automerge.ObjType.Text)
         ]
         */

        // verifying cache lookups

        XCTAssertEqual(PathCache.objId.count, 3)
        XCTAssertNotNil(PathCache.objId[".list"])
        XCTAssertNil(PathCache.objId["list"])
        XCTAssertNil(PathCache.objId["a"])
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
        XCTAssertEqual(pathToList.stringPath(), ".list.[0]")

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
        XCTAssertEqual(pathToText.stringPath(), ".list.[0].notes")
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

    func testSyncStateUpdating() throws {
        let doc1 = Document()
        let syncState1 = SyncState()

        let doc2 = Document()
        let syncState2 = SyncState()

        try! doc1.put(obj: ObjId.ROOT, key: "key1", value: .String("value1"))
        try! doc2.put(obj: ObjId.ROOT, key: "key2", value: .String("value2"))

        XCTAssertNil(syncState1.theirHeads)
        let syncDataMsg = try XCTUnwrap(doc1.generateSyncMessage(state: syncState1))
        print("sync msg size: \(syncDataMsg.count) bytes")
        // syncState1 isn't updated by generating a sync message
        //   .. so at this point syncState1 is effectively "empty" and doesn't contain a list of
        //      any change hashes
        // XCTAssertNotNil(syncState1.theirHeads)
        // print("size of changes in syncState1: \(syncState1.theirHeads?.count)")

        // And we generally want to keep iterating sync messages UNTIL the syncDataMsg result
        // is nil, which indicates that nothing further needs to be synced.

        XCTAssertNil(syncState2.theirHeads)
        try doc2.receiveSyncMessage(state: syncState2, message: syncDataMsg)
        XCTAssertNotNil(syncState2.theirHeads) // it IS updated when you invoke receiveSyncMessages(...)
        print("size of changes in syncState2: \(syncState2.theirHeads?.count ?? -1)")
        for change in syncState2.theirHeads! {
            print(" -> ChangeHash: \(change)")
        }
        // XCTAssertEqual(syncState1.theirHeads, syncState2.theirHeads)
    }
}
