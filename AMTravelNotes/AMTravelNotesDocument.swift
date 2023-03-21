//
//  AMTravelNotesDocument.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import Automerge
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static var automerge: UTType {
        UTType(exportedAs: "com.github.automerge.localfirst")
    }
}

class AMTravelNotesDocument: ReferenceFileDocument {
    typealias AMDoc = Automerge.Document
    var doc: AMDoc

    static var readableContentTypes: [UTType] { [.automerge] }

    init() {
        doc = AMDoc()
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        doc = try! AMDoc(data)
//        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
//            //itemsObjId = id
//        } else {
//            fatalError("no items")
//        }
    }

    func snapshot(contentType _: UTType) throws -> AMDoc {
        doc // Make a copy.
    }

    func fileWrapper(snapshot: AMDoc, configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.save()
        //                  ^^^^ Actor-isolated instance method 'save()' can not be referenced from a non-isolated
        //                  context
        //   when we attempt to use ProtectedAutomergeDocument as AMDoc (wrap the class in an Actor)
        //   It doesn't look like there's an "async" friendly version of ReferenceFileDocument that allows for
        //   non-synchronous calls that the protocol requires.
        let fileWrapper = FileWrapper(regularFileWithContents: data)
        return fileWrapper
    }
}
