import SwiftUI

// MARK: - Hub principal del Buscador

struct BuscadorView: View {
    @EnvironmentObject var service: SupabaseService

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    NavigationLink(destination: ClubesView().environmentObject(service)) {
                        HubCard(
                            icono: "building.2.fill",
                            titulo: "Clubes",
                            subtitulo: "Busca por nombre, provincia, delegación, localidad..."
                        )
                    }
                    NavigationLink(destination: EquiposSearchView().environmentObject(service)) {
                        HubCard(
                            icono: "person.3.fill",
                            titulo: "Equipos",
                            subtitulo: "Busca por nombre, competición y grupo..."
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Buscador")
        }
    }
}

struct HubCard: View {
    let icono: String
    let titulo: String
    let subtitulo: String

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.brand.opacity(0.10))
                    .frame(width: 54, height: 54)
                Image(systemName: icono)
                    .font(.system(size: 22))
                    .foregroundColor(.brand)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(titulo)
                    .font(.headline).foregroundColor(.primary)
                Text(subtitulo)
                    .font(.caption).foregroundColor(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption).foregroundColor(.secondary.opacity(0.4))
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}

// MARK: - Buscador de equipos con filtros

struct EquiposSearchView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var todosEquipos: [Equipo] = []
    @State private var competiciones: [Competicion] = []
    @State private var cargando = true

    @State private var filtroNombre      = ""
    @State private var filtroCompeticion: Competicion? = nil

    @State private var resultados: [Equipo] = []
    @State private var buscando = false
    @State private var haBuscado = false

    var hayFiltros: Bool {
        !filtroNombre.isEmpty || filtroCompeticion != nil
    }

    var body: some View {
        Group {
            if cargando {
                ProgressView()
            } else {
                contenido
            }
        }
        .navigationTitle("Equipos")
        .task { await cargar() }
    }

    var contenido: some View {
        ScrollView {
            VStack(spacing: 0) {
                filtrosCard
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                resultadosSection
                    .padding(.top, 14)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
        .scrollDismissesKeyboard(.immediately)
        .onTapGesture { ocultarTeclado() }
    }

    // MARK: - Filtros

    var filtrosCard: some View {
        VStack(spacing: 0) {
            campoTexto(label: "Nombre", placeholder: "Nombre del equipo", texto: $filtroNombre)
            Divider().padding(.leading, 16)

            campoPicker(
                label: "Competición",
                valor: filtroCompeticion.map { nombreCompeticion($0) } ?? "Todas",
                seleccionado: $filtroCompeticion
            )

            Divider()
            HStack(spacing: 10) {
                if hayFiltros || haBuscado {
                    Button { limpiar() } label: {
                        Text("Limpiar")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16).padding(.vertical, 9)
                            .background(Color(.systemGroupedBackground))
                            .cornerRadius(10)
                    }
                }
                Spacer()
                if hayFiltros {
                    Button {
                        Task { await buscar() }
                    } label: {
                        Group {
                            if buscando {
                                ProgressView().tint(.white)
                                    .padding(.horizontal, 24).padding(.vertical, 9)
                            } else {
                                Label("Buscar", systemImage: "magnifyingglass")
                                    .font(.subheadline).fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 18).padding(.vertical, 9)
                            }
                        }
                        .background(Color.brand)
                        .cornerRadius(10)
                    }
                    .disabled(buscando)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func campoTexto(label: String, placeholder: String, texto: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
            TextField(placeholder, text: texto)
                .font(.subheadline)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    func campoPicker(label: String, valor: String, seleccionado: Binding<Competicion?>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
                Menu {
                    Button("Todas") { seleccionado.wrappedValue = nil }
                    Divider()
                    ForEach(competiciones) { comp in
                        Button(nombreCompeticion(comp)) { seleccionado.wrappedValue = comp }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(valor)
                            .font(.subheadline)
                            .foregroundColor(seleccionado.wrappedValue == nil ? .secondary : .primary)
                            .lineLimit(1)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    func nombreCompeticion(_ comp: Competicion) -> String {
        var partes = [comp.nombre]
        if let g = comp.grupo { partes.append(g) }
        partes.append(comp.temporada)
        return partes.joined(separator: " · ")
    }

    // MARK: - Resultados

    var resultadosSection: some View {
        VStack(spacing: 0) {
            if !haBuscado {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 38)).foregroundColor(.secondary.opacity(0.3))
                    Text("Usa los filtros y pulsa Buscar")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else if resultados.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.3")
                        .font(.system(size: 38)).foregroundColor(.secondary.opacity(0.3))
                    Text("Sin equipos con esos filtros")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("\(resultados.count) \(resultados.count == 1 ? "equipo encontrado" : "equipos encontrados")")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)

                    VStack(spacing: 0) {
                        ForEach(resultados) { equipo in
                            NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                                HStack(spacing: 14) {
                                    EscudoView(url: service.escudoUrl(equipo: equipo), size: 40)
                                    Text(equipo.nombre)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.primary).lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundColor(.secondary.opacity(0.5))
                                }
                                .padding(.horizontal, 16).padding(.vertical, 11)
                            }
                            if equipo.id != resultados.last?.id {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    // MARK: - Acciones

    func buscar() async {
        ocultarTeclado()
        await MainActor.run { buscando = true }

        var equiposFiltrados: [Equipo]

        if let comp = filtroCompeticion {
            let ids = (try? await service.fetchEquipoIdsEnCompeticion(competicionId: comp.id)) ?? []
            equiposFiltrados = todosEquipos.filter { ids.contains($0.id) }
        } else {
            equiposFiltrados = todosEquipos
        }

        if !filtroNombre.isEmpty {
            equiposFiltrados = equiposFiltrados.filter {
                $0.nombre.localizedCaseInsensitiveContains(filtroNombre)
            }
        }

        await MainActor.run {
            resultados = equiposFiltrados.sorted { $0.nombre < $1.nombre }
            haBuscado = true
            buscando = false
        }
    }

    func limpiar() {
        filtroNombre = ""
        filtroCompeticion = nil
        resultados = []
        haBuscado = false
        ocultarTeclado()
    }

    func ocultarTeclado() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    func cargar() async {
        do {
            async let e = service.fetchEquipos()
            async let c = service.fetchCompeticiones()
            let (equipos, comps) = try await (e, c)
            await MainActor.run {
                todosEquipos = equipos
                competiciones = comps
                cargando = false
            }
        } catch {
            await MainActor.run { cargando = false }
        }
    }
}
