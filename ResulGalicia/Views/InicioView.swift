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

    var buscando: Bool { !busqueda.isEmpty }

    var competicionesFiltradas: [Competicion] {
        let q = busqueda.lowercased()
        return competiciones.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.grupo?.lowercased().contains(q) ?? false) ||
            $0.temporada.lowercased().contains(q)
        }
    }

    var equiposFiltrados: [Equipo] {
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
                } else if buscando {
                    resultadosBusqueda
                } else {
                    vistaPrincipal
                }
            }
            .navigationTitle("ResulGalicia")
            .searchable(text: $busqueda, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar liga o equipo...")
            .task { await cargar() }
            .refreshable { await cargar() }
        }
    }

    // MARK: - Vista principal (sin búsqueda)

    var vistaPrincipal: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if !competicionesFavoritas.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Favoritos", systemImage: "star.fill")
                            .font(.headline).foregroundColor(.primary)
                            .padding(.horizontal, 16)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(competicionesFavoritas) { comp in
                                    NavigationLink(destination: LigaView(competicion: comp)) {
                                        LigaCard(competicion: comp, esFavorito: true, toggleFavorito: { toggleFavorito(comp.id) })
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                    }
                }

                // Prompt si no hay favoritos o siempre como pie
                VStack(spacing: 20) {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(.blue.opacity(0.15), .blue.opacity(0.3))
                    Text("Busca una liga o equipo")
                        .font(.title3).fontWeight(.semibold)
                    Text("Escribe en la barra de búsqueda para encontrar competiciones y equipos. Desliza una liga a la izquierda para guardarla como favorita.")
                        .font(.subheadline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, competicionesFavoritas.isEmpty ? 60 : 24)
            }
            .padding(.vertical, 16)
        }
    }

    // MARK: - Resultados de búsqueda

    var resultadosBusqueda: some View {
        List {
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
                }
                if !equiposFiltrados.isEmpty {
                    Section("Equipos") {
                        ForEach(equiposFiltrados) { equipo in
                            NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                                HStack(spacing: 12) {
                                    InicialCircle(nombre: equipo.nombre, color: .blue, size: 40)
                                    Text(equipo.nombre).font(.subheadline).fontWeight(.medium)
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
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

// MARK: - Liga Card (favoritos)

struct LigaCard: View {
    let competicion: Competicion
    let esFavorito: Bool
    let toggleFavorito: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title2).foregroundColor(.blue)
                Spacer()
                Button(action: toggleFavorito) {
                    Image(systemName: esFavorito ? "star.fill" : "star")
                        .foregroundColor(.yellow)
                }
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(competicion.nombre)
                    .font(.subheadline).fontWeight(.bold)
                    .lineLimit(2).foregroundColor(.primary)
                if let grupo = competicion.grupo {
                    Text("Grupo \(grupo)")
                        .font(.caption).foregroundColor(.secondary)
                }
                Text(competicion.temporada)
                    .font(.caption2).foregroundColor(.secondary)
            }
        }
        .padding(14)
        .frame(width: 160)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(14)
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
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
                    .font(.title3).foregroundColor(.blue)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(competicion.nombre)
                    .font(.subheadline).fontWeight(.semibold).lineLimit(1)
                HStack(spacing: 6) {
                    if let grupo = competicion.grupo {
                        Text("Grupo \(grupo)").font(.caption).foregroundColor(.secondary)
                        Text("·").font(.caption).foregroundColor(.secondary)
                    }
                    Text(competicion.temporada).font(.caption).foregroundColor(.secondary)
                }
            }
            Spacer()
            if esFavorito {
                Image(systemName: "star.fill").font(.caption).foregroundColor(.yellow)
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
                    .font(size >= 44 ? .subheadline : size >= 32 ? .caption : .caption2)
                    .fontWeight(.bold)
                    .foregroundColor(color)
            )
    }
}
