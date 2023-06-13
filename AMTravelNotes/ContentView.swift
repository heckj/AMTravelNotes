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
        VStack {
            HStack {
                Spacer()
                Text("Document ID: \(document.model.id)")
                    .font(.caption)
                Spacer()
            }
            Form {
                TextField("Title", text: $document.model.title)
                TextField("Summary", text: $document.model.summary.value)
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: AMTravelNotesDocument())
    }
}
