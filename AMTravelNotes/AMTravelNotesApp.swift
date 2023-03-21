//
//  AMTravelNotesApp.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

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
