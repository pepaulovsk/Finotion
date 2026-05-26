import SwiftUI

struct ShortcutInstallStepView: View {
    let viewModel: OnboardingViewModel
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "apps.iphone")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("Add to Shortcuts")
                .font(.title.bold())
            Text("Install the Finotion shortcut to quickly log expenses with NFC stickers or from the Shortcuts app.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            if let url = viewModel.shortcutInstallURL {
                Button("Install Shortcut") {
                    openURL(url)
                    viewModel.completeShortcutInstall()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .padding(.horizontal)
            }
            Button("Skip for Now") {
                viewModel.skipShortcut()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Shortcuts")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}
