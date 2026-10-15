import SwiftUI

struct ContentView: View {
    var body: some View {
        GeometryReader { geometry in
            Image("HandsArtwork")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
