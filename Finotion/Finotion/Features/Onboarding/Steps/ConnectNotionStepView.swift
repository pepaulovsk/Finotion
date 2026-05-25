import AuthenticationServices
import SwiftUI

struct ConnectNotionStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "link.icloud")
                .font(.system(size: 64))
                .foregroundStyle(.accent)
            Text("Connect Notion")
                .font(.title.bold())
            Text("Finotion needs access to your Notion workspace to store and read your financial data.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: launchOAuth) {
                Label("Connect with Notion", systemImage: "arrow.up.right.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(viewModel.isLoading)
            .padding(.horizontal)
        }
        .padding()
        .navigationTitle("Welcome")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func launchOAuth() {
        guard let authURL = viewModel.notionAuthURL else { return }
        let session = ASWebAuthenticationSession(
            url: authURL,
            callbackURLScheme: "finotion"
        ) { callbackURL, _ in
            Task { await viewModel.handleOAuthCallback(callbackURL) }
        }
        session.prefersEphemeralWebBrowserSession = false
        session.start()
    }
}
