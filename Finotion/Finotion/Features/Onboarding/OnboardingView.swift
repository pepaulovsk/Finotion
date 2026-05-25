import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.notionService) private var notionService
    @State private var viewModel: OnboardingViewModel?

    var body: some View {
        Group {
            if let vm = viewModel {
                OnboardingFlowView(viewModel: vm)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            guard viewModel == nil else { return }
            viewModel = OnboardingViewModel(notionService: notionService, appState: appState)
        }
    }
}

private struct OnboardingFlowView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        NavigationStack {
            Group {
                switch viewModel.step {
                case .connectNotion:
                    ConnectNotionStepView(viewModel: viewModel)
                case .chooseDatabase:
                    DatabasePathStepView(viewModel: viewModel)
                case .fieldMapping:
                    FieldMappingView(viewModel: viewModel)
                case .installShortcut:
                    ShortcutInstallStepView(viewModel: viewModel)
                case .notificationPermission:
                    NotificationPermissionStepView(viewModel: viewModel)
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.error != nil },
                set: { if !$0 { viewModel.error = nil } }
            )) {
                Button("OK") { viewModel.error = nil }
            } message: {
                Text(viewModel.error.map { errorMessage($0) } ?? "")
            }
        }
    }

    private func errorMessage(_ error: OnboardingError) -> String {
        switch error {
        case .oauthCancelled: return "Connection cancelled. Tap Connect to try again."
        case .oauthFailed(let msg): return "Connection failed: \(msg)"
        case .networkError: return "Network error. Please check your connection."
        case .fieldMappingIncomplete: return "Name, Amount, and Date fields are required."
        }
    }
}
