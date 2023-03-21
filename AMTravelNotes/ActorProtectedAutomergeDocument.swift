//
//  WrappedAMDoc.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import Foundation
import Automerge

// NOTE(heckj):
// exploring protecting Automerge from multi-threaded access by utilizing an Actor
// and an "async-acceptable" semaphore

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
