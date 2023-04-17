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
    var doc: Document
    var model: TravelNotesModel?

    static var readableContentTypes: [UTType] { [.automerge] }

    init() {
        doc = Document()
        model = TravelNotesModel(doc: doc)
    }

    required init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents
        else {
            throw CocoaError(.fileReadCorruptFile)
        }

        doc = try! Document(data)
        model = TravelNotesModel(doc: doc)
    }

    func snapshot(contentType _: UTType) throws -> Document {
        doc // Make a copy.
    }

    func fileWrapper(snapshot: Document, configuration _: WriteConfiguration) throws -> FileWrapper {
        let data = snapshot.save()
        let fileWrapper = FileWrapper(regularFileWithContents: data)
        return fileWrapper
    }
}
