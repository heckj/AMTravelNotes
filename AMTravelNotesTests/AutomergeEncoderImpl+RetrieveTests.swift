//
//  AutomergeEncoderImpl+RetrieveTests.swift
//  AMTravelNotesTests
//
//  Created by Joseph Heck on 5/16/23.
//

@testable import AMTravelNotes
import Automerge
import XCTest

final class RetrieveObjectIdTests: XCTestCase {
    var doc: Document!

    override func setUp() {
        doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        try! doc.put(obj: nestedMap, key: "image", value: .Bytes(Data()))
        let _ = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)
    }

    func testPathAtRoot() throws {
        let doc = Document()
        let path = try! doc.path(obj: ObjId.ROOT)
        print("\(path)")
        XCTAssertEqual(path, [])
    }
}
