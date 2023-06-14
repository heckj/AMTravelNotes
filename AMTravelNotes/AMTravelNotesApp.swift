import SwiftUI

@main
struct AMTravelNotesApp: App {
    var body: some Scene {
        DocumentGroup {
            AMTravelNotesDocument()
        } editor: { file in
            ContentView(document: file.document)
        }
    }
}
