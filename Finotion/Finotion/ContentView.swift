import SwiftUI

struct ContentView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "dollarsign.circle.fill")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Finotion")
                .font(.largeTitle)
                .fontWeight(.bold)
        }
        .padding()
    }
}
