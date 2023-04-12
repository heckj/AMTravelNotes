import Combine

import class Automerge.Document
import struct Automerge.ObjId

protocol HasDoc {
    var doc: Document { get }
}

protocol HasObj {
    var obj: ObjId { get }
}

// mixing the Automerge doc & Observable object with an explicit marker for a
// directly usable publisher to participate in send()
protocol ObservableAutomergeBoundObject: ObservableObject, HasDoc, HasObj {
    var objectWillChange: ObservableObjectPublisher { get }
    // ^^ this is really about more easily participating in ObservableObject notifications

    init(doc: Document, obj: ObjId)
}
