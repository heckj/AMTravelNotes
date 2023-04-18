import ArgumentParser
import Automerge
import Foundation

@main
struct DumpDocument: ParsableCommand {
    @Argument var inputFile: String
    @Argument var outputFile: String

    mutating func run() throws {
        print("""
        Counting words in '\(inputFile)' \
        and writing the result into '\(outputFile)'.
        """)

        // Read 'inputFile', count the words, and save to 'outputFile'.
    }
}
