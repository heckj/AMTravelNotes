//
//  AutomergeExplorationTests.swift
//  AMTravelNotesTests
//
//  Created by Joseph Heck on 3/23/23.
//

import XCTest
import Automerge

final class AutomergeExplorationTests: XCTestCase {

    func testPathAtRoot() throws {
        let doc = Document()
        let path = try! doc.path(obj: ObjId.ROOT)
        //print("\(path)")
        XCTAssertEqual(path, [])
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
}
