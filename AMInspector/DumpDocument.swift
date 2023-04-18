import ArgumentParser
import Automerge
import Foundation

@main
struct AMInspector: ParsableCommand {
    @Argument(help: "The Automerge document to inspect.")
    var inputFile: String

    @Flag(
        name: [.long],
        help: "Provide summary statistics about the Automerge document."
    )
    var stats = false

    @Flag(
        name: [.customShort("l"), .long],
        help: "List out the changeset hashes in the summary."
    )
    var listchanges = false

    @Flag(help: "Walk the schema of the document and print out the resolved values.")
    var walk = false

    mutating func run() throws {
        if listchanges {
            stats = true
        }

        let data: Data
        let doc: Document
        do {
            data = try Data(contentsOf: URL(fileURLWithPath: inputFile))
        } catch {
            print("Unable to open file at \(inputFile).")
            AMInspector.exit(withError: error)
        }

        do {
            doc = try Document(data)
        } catch {
            print("\(inputFile) is not an Automerge document.")
            AMInspector.exit(withError: error)
        }

        if stats {
            let changesets = doc.heads()
            print("Filename: \(inputFile)")
            print("- Size: \(data.count) bytes")
            print("- ActorId: \(doc.actor)")
            print("- ChangeSets: \(doc.heads().count)")
            if listchanges {
                for cs in changesets {
                    print("  - \(cs)")
                }
            }
        }

        if walk {
            do {
                try walk(doc)
            } catch {
                print("Error while walking document.")
                AMInspector.exit(withError: error)
            }
        }
    }

    func walk(_ doc: Document) throws {
        print("{")
        try walk(doc, from: ObjId.ROOT)
        print("}")
    }

    func walk(_ doc: Document, from objId: ObjId, indent: Int = 1) throws {
        let indentString = String(repeating: " ", count: indent * 2)
        switch doc.objectType(obj: objId) {
        case .Map:
            for (key, value) in try doc.mapEntries(obj: objId) {
                if case let Value.Scalar(scalarValue) = value {
                    print("\(indentString)\"\(key)\" : \(scalarValue)")
                }
                if case let Value.Object(childObjId, _) = value {
                    print("\(indentString)\"\(key)\" : {")
                    try walk(doc, from: childObjId, indent: indent + 1)
                    print("\(indentString)}")
                }
            }
        case .List:
            if doc.length(obj: objId) == 0 {
                print("\(indentString)[]")
            } else {
                print("\(indentString)[")
                for value in try doc.values(obj: objId) {
                    if case let Value.Scalar(scalarValue) = value {
                        print("\(indentString)  \(scalarValue)")
                    } else {
                        if case let Value.Object(childObjId, _) = value {
                            try walk(doc, from: childObjId, indent: indent + 1)
                        }
                    }
                }
                print("\(indentString)]")
            }
        case .Text:
            let stringValue = try doc.text(obj: objId)
            print("\(indentString)Text[\"\(stringValue)\"]")
        }
    }
}
