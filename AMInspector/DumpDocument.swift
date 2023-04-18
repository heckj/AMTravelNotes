import ArgumentParser
import Automerge
import Foundation

@main
struct AMInspector: ParsableCommand {
    @Argument(help: "The Automerge document to inspect.")
    var inputFile: String
    
    @Flag(name: [.customShort("l"), .long],
          help: "List out the included changesets.")
    var listchanges = false

    mutating func run() throws {
        let data = try Data(contentsOf: URL(fileURLWithPath: inputFile))
                
        let doc = try Document(data)
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
