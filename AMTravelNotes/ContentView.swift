//
//  ContentView.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import SwiftUI

struct ContentView: View {
    @ObservedObject var document: AMTravelNotesDocument

    var body: some View {
        Text("Placeholder")
        // TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: AMTravelNotesDocument())
    }
}
