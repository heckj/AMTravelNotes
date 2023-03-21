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
        DocumentGroup(newDocument: AMTravelNotesDocument()) { file in
            ContentView(document: file.$document)
        }
    }
}
