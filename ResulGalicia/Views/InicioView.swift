import SwiftUI

struct InicioView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var competiciones: [Competicion] = []
    @State private var equipos: [Equipo] = []
    @State private var busqueda = ""
    @State private var cargando = true
    @AppStorage("favoritosCompeticiones") private var favoritosString: String = ""

    var favoritoIds: Set<UUID> {
        Set(favoritosString.split(separator: ",").compactMap { UUID(uuidString: String($0)) })
    }

    func toggleFavorito(_ id: UUID) {
        var ids = favoritoIds
        if ids.contains(id) { ids.remove(id) } else { ids.insert(id) }
        favoritosString = ids.map { $0.uuidString }.joined(separator: ",")
    }

    var competicionesFiltradas: [Competicion] {
        guard !busqueda.isEmpty else { return competiciones }
        let q = busqueda.lowercased()
        return competiciones.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.grupo?.lowercased().contains(q) ?? false) ||
            $0.temporada.lowercased().contains(q)
        }
    }

    var equiposFiltrados: [Equipo] {
        guard !busqueda.isEmpty else { return [] }
        let q = busqueda.lowercased()
        return equipos.filter { $0.nombre.lowercased().contains(q) }
    }

    var competicionesFavoritas: [Competicion] {
        competiciones.filter { favoritoIds.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else {
                    listaContenido
                }
            }
            .navigationTitle("ResulGalicia")
            .searchable(text: $busqueda, prompt: "Buscar liga o equipo...")
            .task { await cargar() }
            .refreshable { await cargar() }
        }
    }

    var listaContenido: some View {
        List {
            if busqueda.isEmpty {
                contenidoDefault
            } else {
                resultadosBusqueda
            }
        }
        .listStyle(.insetGrouped)
    }

    @ViewBuilder
    var contenidoDefault: some View {
        if !competicionesFavoritas.isEmpty {
            Section {
                ForEach(competicionesFavoritas) { comp in
                    NavigationLink(destination: LigaView(competicion: comp)) {
                        CompeticionRow(competicion: comp, esFavorito: true)
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) { toggleFavorito(comp.id) } label: {
                            Label("Quitar", systemImage: "star.slash.fill")
                        }
                        .tint(.orange)
                    }
                }
            } header: {
                Label("Favoritos", systemImage: "star.fill").foregroundColor(.yellow)
            }
        }

        Section {
            if competiciones.isEmpty {
                Text("No hay ligas disponibles")
                    .foregroundColor(.secondary).font(.subheadline)
            } else {
                ForEach(competiciones) { comp in
                    NavigationLink(destination: LigaView(competicion: comp)) {
                        CompeticionRow(competicion: comp, esFavorito: favoritoIds.contains(comp.id))
                    }
                    .swipeActions(edge: .trailing) {
                        Button {
                            toggleFavorito(comp.id)
                        } label: {
                            Label(
                                favoritoIds.contains(comp.id) ? "Quitar" : "Favorito",
                                systemImage: favoritoIds.contains(comp.id) ? "star.slash.fill" : "star.fill"
                            )
                        }
                        .tint(.yellow)
                    }
                }
            }
        } header: {
            Text("Ligas")
        } footer: {
            Text("Desliza una liga hacia la izquierda para añadirla a favoritos")
                .font(.caption)
        }
    }

    @ViewBuilder
    var resultadosBusqueda: some View {
        if competicionesFiltradas.isEmpty && equiposFiltrados.isEmpty {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.largeTitle).foregroundColor(.secondary)
                        Text("Sin resultados para «\(busqueda)»")
                            .foregroundColor(.secondary).font(.subheadline)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
            }
        } else {
            if !competicionesFiltradas.isEmpty {
                Section("Ligas") {
                    ForEach(competicionesFiltradas) { comp in
                        NavigationLink(destination: LigaView(competicion: comp)) {
                            CompeticionRow(competicion: comp, esFavorito: favoritoIds.contains(comp.id))
                        }
                    }
                }
            }
            if !equiposFiltrados.isEmpty {
                Section("Equipos") {
                    ForEach(equiposFiltrados) { equipo in
                        NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                            HStack(spacing: 12) {
                                InicialCircle(nombre: equipo.nombre, color: .blue, size: 40)
                                Text(equipo.nombre)
                                    .font(.subheadline).fontWeight(.medium)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
    }

    func cargar() async {
        do {
            async let c = service.fetchCompeticiones()
            async let e = service.fetchEquipos()
            let (cs, es) = try await (c, e)
            await MainActor.run {
                self.competiciones = cs
                self.equipos = es
                self.cargando = false
            }
        } catch {
            await MainActor.run { cargando = false }
        }
    }
}

struct CompeticionRow: View {
    let competicion: Competicion
    let esFavorito: Bool

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 46, height: 46)
                Image(systemName: "trophy.fill")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(competicion.nombre)
                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    if let grupo = competicion.grupo {
                        Text("Grupo \(grupo)")
                            .font(.caption).foregroundColor(.secondary)
                        Text("·").font(.caption).foregroundColor(.secondary)
                    }
                    Text(competicion.temporada)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if esFavorito {
                Image(systemName: "star.fill")
                    .font(.caption).foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 4)
    }
}

struct InicialCircle: View {
    let nombre: String
    let color: Color
    let size: CGFloat

    var body: some View {
        Circle()
            .fill(color.opacity(0.12))
            .frame(width: size, height: size)
            .overlay(
                Text(String(nombre.prefix(2)).uppercased())
                    .font(size >= 44 ? .subheadline : .caption)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            )
    }
}
