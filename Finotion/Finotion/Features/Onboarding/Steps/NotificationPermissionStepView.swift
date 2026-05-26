import SwiftUI

struct NotificationPermissionStepView: View {
    let viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "bell.badge")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)
            Text("Stay Informed")
                .font(.title.bold())
            Text("Allow notifications to be reminded when recurring payments are dispatched and when syncs complete.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Allow Notifications") {
                Task { await viewModel.completeNotificationPermission() }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .frame(maxWidth: .infinity)
            .padding(.horizontal)
            Button("Skip for Now") {
                viewModel.skipNotifications()
            }
            .foregroundStyle(.secondary)
        }
        .padding()
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden()
    }
}
