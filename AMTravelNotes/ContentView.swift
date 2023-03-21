//
//  ContentView.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 3/21/23.
//

import SwiftUI

struct ContentView: View {
    @Binding var document: AMTravelNotesDocument

    var body: some View {
        TextEditor(text: $document.text)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(document: .constant(AMTravelNotesDocument()))
    }
}
