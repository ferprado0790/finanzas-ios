import SwiftUI

/// Elegir el banco. En España la lista pasa de cien entidades, así que lo que
/// manda es el buscador; la lista completa está debajo por si acaso.
struct InstitutionPickerView: View {

    @Bindable var vm: BankViewModel
    let onPick: (BankInstitution) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [BankInstitution] {
        let needle = query.folding(options: [.diacriticInsensitive, .caseInsensitive],
                                   locale: AppConfig.locale)
            .trimmingCharacters(in: .whitespaces)
        guard !needle.isEmpty else { return vm.institutions }
        return vm.institutions.filter {
            $0.name.folding(options: [.diacriticInsensitive, .caseInsensitive],
                            locale: AppConfig.locale).contains(needle)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.institutions.isEmpty {
                    if let error = vm.errorMessage {
                        ScrollView {
                            ErrorBanner(message: error) {
                                Task { await vm.loadInstitutions() }
                            }
                            .padding(20)
                        }
                    } else {
                        ProgressView("Cargando bancos…")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .tint(Theme.primaryLight)
                            .foregroundStyle(Theme.textMuted)
                    }
                } else {
                    List {
                        Section {
                            ForEach(filtered) { institution in
                                Button { onPick(institution) } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "building.columns")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Theme.primaryLight)
                                            .frame(width: 28)
                                        Text(institution.name)
                                            .font(.system(size: 15))
                                            .foregroundStyle(Theme.textPrimary)
                                        Spacer(minLength: 0)
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundStyle(Theme.textFaint)
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Theme.surface)
                            }
                        } footer: {
                            Text("Se abrirá la web de tu banco para que autorices el acceso. La autorización dura 90 días y hay que renovarla; la app te avisa antes.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textFaint)
                        }
                    }
                    .scrollContentBackground(.hidden)
                    .searchable(text: $query, prompt: "Busca tu banco")
                }
            }
            .finanzBackground()
            .navigationTitle("Elige tu banco")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }.foregroundStyle(Theme.textMuted)
                }
            }
            .task { await vm.loadInstitutions() }
        }
    }
}
