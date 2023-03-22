//
//  QueueProtectedAutomergeDocument.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import Foundation
import Automerge

class QueueProtectedAutomergeDocument {
    private var doc: Automerge.Document
    // NOTE(heckj): this is probably something that's best back-ported in the the Automerge
    // Swift language bindings.
    private let queue = DispatchQueue(label: "automerge-wrapper", qos: .userInteractive)

    init() {
        doc = Automerge.Document()
    }

    init(from data: Data) throws {
        doc = try Document(data)
    }

    func save() -> Data {
        queue.sync {
            doc.save()
        }
    }
}

