//
//  WrappedAMDoc.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import Automerge
import Foundation

// NOTE(heckj):
// exploring protecting Automerge from multi-threaded access by utilizing an Actor
// and an "async-acceptable" semaphore.
// 21march2023 - this pattern looks like it's getting scuttled primarily due to
// the ReferenceFileDocument protocol not having any supported `async` method paths within it -
// so all calls need to be synchronous, which stops the idea of using a Swift Actor
// rather in its tracks.

actor ActorProtectedAutomergeDocument {
    var doc: Automerge.Document

    init() {
        doc = Automerge.Document()
    }

    init(from data: Data) throws {
        doc = try Document(data)
    }

    func save() -> Data {
        doc.save()
    }
}
