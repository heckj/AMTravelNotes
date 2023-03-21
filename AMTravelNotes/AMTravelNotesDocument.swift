//
//  AMTravelNotesDocument.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import SwiftUI
import UniformTypeIdentifiers
import Automerge

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
        
        doc = try! Document(Array(data))
//        if case let .Object(id, .Map) = try! doc.get(obj: ObjId.ROOT, key: "items")! {
//            //itemsObjId = id
//        } else {
//            fatalError("no items")
//        }
    }
    
    func snapshot(contentType: UTType) throws -> AMDoc {
        doc // Make a copy.
    }
    
    func fileWrapper(snapshot: AMDoc, configuration: WriteConfiguration) throws -> FileWrapper {
        let data = Data(snapshot.save())
        let fileWrapper = FileWrapper(regularFileWithContents: data)
        return fileWrapper
    }
    
}
