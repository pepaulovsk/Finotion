import SwiftUI

struct DatabasePathStepView: View {
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                Text("How would you like to set up your database?")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.top)

                pathCard(
                    systemImage: "sparkles",
                    title: "Create from Template",
                    description: "Finotion creates a ready-to-use Notion database with all required fields.",
                    action: {
                        Task { await viewModel.selectPathA() }
                    }
                )

                pathCard(
                    systemImage: "tray.full",
                    title: "Use Existing Database",
                    description: "Connect an existing Notion database and map its fields to Finotion concepts.",
                    action: {
                        Task { await viewModel.loadDatabases() }
                    }
                )

                if viewModel.isLoading {
                    ProgressView()
                }

                if !viewModel.databases.isEmpty {
                    Divider()
                    Text("Select a database")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ForEach(viewModel.databases) { db in
                        Button(db.title) {
                            Task { await viewModel.selectPathBDatabase(db) }
                        }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Choose Database")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func pathCard(
        systemImage: String,
        title: String,
        description: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.accent)
                    .frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.headline)
                    Text(description).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoading)
    }
}
