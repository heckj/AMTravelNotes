import Foundation
import ArgumentParser
import Automerge

extension AMInspector {
    struct Info: ParsableCommand {
        static var configuration = CommandConfiguration(
            commandName: "info",
            abstract: "Inspects and prints general metrics about Automerge files."
        )
        
        @OptionGroup var options: AMInspector.Options
        
        @Flag(
            name: [.customShort("v"), .long],
            help: "List the changeset hashes."
        )
        var verbose = false
        
        mutating func run() throws {
            let data: Data
            let doc: Document
            do {
                data = try Data(contentsOf: URL(fileURLWithPath: options.inputFile))
            } catch {
                print("Unable to open file at \(options.inputFile).")
                AMInspector.exit(withError: error)
            }
            
            do {
                doc = try Document(data)
            } catch {
                print("\(options.inputFile) is not an Automerge document.")
                AMInspector.exit(withError: error)
            }
            
            
            let changesets = doc.heads()
            print("Filename: \(options.inputFile)")
            print("- Size: \(data.count) bytes")
            print("- ActorId: \(doc.actor)")
            print("- ChangeSets: \(doc.heads().count)")
            if verbose {
                for cs in changesets {
                    print("  - \(cs)")
                }
            }
        }
    }
}
