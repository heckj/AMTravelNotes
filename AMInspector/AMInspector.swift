import ArgumentParser
import Automerge
import Foundation
import Rainbow

@main
struct AMInspector: ParsableCommand {
    static var configuration = CommandConfiguration(
        commandName: "AMInspector",
        abstract: "Inspects and prints information about an Automerge file.",
        subcommands: [Info.self, Dump.self],
        defaultSubcommand: Info.self
    )

    struct Options: ParsableArguments {
        @Argument(help: "The Automerge document to inspect.")
        var inputFile: String
    }
}
