import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var showingEditMapping = false
    @State private var showingSignOutAlert = false

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }

    var body: some View {
        NavigationStack {
            Form {
                mappingSection
                aliasSection
                syncSection
                signOutSection
                versionSection
            }
            .navigationTitle("Configurações")
            .sheet(isPresented: $showingEditMapping) {
                if let mapping = appState.fieldMapping {
                    EditFieldMappingView(mapping: mapping)
                }
            }
            .alert("Sair da conta?", isPresented: $showingSignOutAlert) {
                Button("Sair", role: .destructive) { appState.signOut() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Você precisará conectar o Notion novamente.")
            }
        }
    }

    @ViewBuilder
    private var mappingSection: some View {
        Section("Mapeamento de campos") {
            if let mapping = appState.fieldMapping {
                LabeledContent("Nome", value: mapping.nameField)
                LabeledContent("Valor", value: mapping.amountField)
                LabeledContent("Data", value: mapping.dateField)
                Button("Editar mapeamento") {
                    showingEditMapping = true
                }
            } else {
                Text("Nenhum banco configurado.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var aliasSection: some View {
        Section("Merchants") {
            NavigationLink("Apelidos de Merchants") {
                MerchantAliasListView()
            }
        }
    }

    @ViewBuilder
    private var syncSection: some View {
        Section("Sincronização") {
            LabeledContent("iCloud") {
                syncStatusView
            }
        }
    }

    @ViewBuilder
    private var signOutSection: some View {
        Section {
            Button("Sair", role: .destructive) {
                showingSignOutAlert = true
            }
        }
    }

    @ViewBuilder
    private var versionSection: some View {
        Section {
            LabeledContent("Versão", value: "\(appVersion) (\(buildNumber))")
        }
    }

    @ViewBuilder
    private var syncStatusView: some View {
        switch appState.iCloudSyncStatus {
        case .idle:
            Text("Sincronizado")
                .foregroundStyle(.secondary)
        case .syncing:
            HStack(spacing: 4) {
                ProgressView()
                Text("Sincronizando…")
            }
        case .failed:
            Label("Erro", systemImage: "exclamationmark.triangle")
                .foregroundStyle(.red)
        }
    }
}
