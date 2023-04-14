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
    typealias AMDoc = QueueProtectedAutomergeDocument
    var doc: AMDoc
    var model: TravelNotesModel?

    static var readableContentTypes: [UTType] { [.automerge] }

    init() {
        doc = AMDoc()
        doc.withSafety { doc in
            self.model = TravelNotesModel(doc: doc)
        }
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        doc = try! AMDoc(from: data)
        doc.withSafety { doc in
            self.model = TravelNotesModel(doc: doc)
        }
    }

    func snapshot(contentType _: UTType) throws -> AMDoc {
        doc // Make a copy.
    }

    func fileWrapper(snapshot: AMDoc, configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.save()
        let fileWrapper = FileWrapper(regularFileWithContents: data)
        return fileWrapper
    }
}
