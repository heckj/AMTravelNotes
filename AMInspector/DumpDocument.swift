import ArgumentParser
import Automerge
import Foundation

@main
struct AMInspector: ParsableCommand {
    @Argument(help: "The Automerge document to inspect.")
    var inputFile: String

    @Flag(
        name: [.customShort("l"), .long],
        help: "List out the included changesets."
    )
    var listchanges = false

    mutating func run() throws {
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
}
