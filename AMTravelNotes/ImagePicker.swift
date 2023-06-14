import PhotosUI
import SwiftUI

struct ImagePicker: View {
    @State var imageSelection: PhotosPickerItem?

    var body: some View {
        Text("EXAMPLE IMAGE HERE").font(.largeTitle)
            .overlay(alignment: .bottomTrailing) {
                PhotosPicker(
                    selection: $imageSelection,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
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
