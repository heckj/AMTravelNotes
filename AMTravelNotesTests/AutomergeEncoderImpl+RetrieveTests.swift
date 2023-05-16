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
    var setupCache: [String: ObjId] = [:]

    override func setUp() {
        setupCache = [:]
        doc = Document()
        let list = try! doc.putObject(obj: ObjId.ROOT, key: "list", ty: .List)
        setupCache["list"] = list

        let nestedMap = try! doc.insertObject(obj: list, index: 0, ty: .Map)
        setupCache["nestedMap"] = nestedMap

        try! doc.put(obj: nestedMap, key: "image", value: .Bytes(Data()))
        let deeplyNestedText = try! doc.putObject(obj: nestedMap, key: "notes", ty: .Text)
        setupCache["deeplyNestedText"] = deeplyNestedText
    }

    func testPathAtRoot() throws {
        let doc = Document()
        let path = try! doc.path(obj: ObjId.ROOT)
        XCTAssertEqual(path, [])
    }

    func testRetrieveLeafValue() throws {
        let fullCodingPath: [AnyCodingKey] = [
            AnyCodingKey("list"),
            AnyCodingKey(0),
            AnyCodingKey("notes"),
        ]
        let encoderImpl = AutomergeEncoderImpl(userInfo: [:], codingPath: fullCodingPath, doc: doc)

        let result = encoderImpl.retrieveObjectId(path: fullCodingPath, containerType: .Value)
        switch result {
        case let .success((objectId, codingKeyInstance)):
            XCTAssertEqual(objectId, setupCache["nestedMap"])
            XCTAssertEqual(codingKeyInstance, AnyCodingKey("notes"))
        case .failure:
            XCTFail("Failure looking up full path to notes as a value")
        }
        // Caching not yet implemented
        // XCTAssertEqual(encoderImpl.cache.count, 2)
    }
}
