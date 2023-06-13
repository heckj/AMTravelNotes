//
//  ImagePicker.swift
//  AMTravelNotes
//
//  Created by Joseph Heck on 6/13/23.
//

import SwiftUI
import PhotosUI

struct ImagePicker: View {
    
    @State var imageSelection: PhotosPickerItem?
    
    var body: some View {
        Text("EXAMPLE IMAGE HERE").font(.largeTitle)
//        CircularProfileImage(imageState: viewModel.imageState)
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(selection: $imageSelection,
                             matching: .images,
                             photoLibrary: .shared()) {
                    Image(systemName: "pencil.circle.fill")
                        .symbolRenderingMode(.multicolor)
                        .font(.system(size: 30))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.borderless)
            }
    }
}

struct ImagePicker_Previews: PreviewProvider {
    static var previews: some View {
        ImagePicker()
    }
}
