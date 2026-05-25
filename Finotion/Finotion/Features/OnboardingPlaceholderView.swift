import SwiftUI

struct OnboardingPlaceholderView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "link.icloud")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)
            Text("Connect Notion")
                .font(.title2.bold())
            Text("Onboarding coming soon")
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
