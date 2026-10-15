import SwiftUI
import AuthenticationServices

struct ContentView: View {
    var body: some View {
        GeometryReader { proxy in
            Image("CosmicLoginArtwork")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .ignoresSafeArea()
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
