import SwiftUI

struct InicioView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var competiciones: [Competicion] = []
    @State private var equipos: [Equipo] = []
    @State private var busqueda = ""
    @State private var cargando = true
    @State private var errorMsg: String? = nil
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
        guard buscando else { return competiciones }
        let q = busqueda.lowercased()
        return competiciones.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.grupo?.lowercased().contains(q) ?? false) ||
            $0.temporada.lowercased().contains(q)
        }
    }

    var equiposFiltrados: [Equipo] {
        guard buscando else { return [] }
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
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    contenido
                }
            }
            .navigationTitle("ResulGalicia")
            .searchable(text: $busqueda, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar liga o equipo...")
            .task { await cargar() }
            .refreshable { await cargar() }
        }
    }

    // MARK: - Contenido principal

    var contenido: some View {
        List {
            if buscando {
                resultadosBusqueda
            } else {
                contenidoNormal
            }
        }
        .listStyle(.insetGrouped)
        .animation(.default, value: busqueda)
    }

    // MARK: - Vista normal (sin búsqueda)

    @ViewBuilder
    var contenidoNormal: some View {
        // Favoritos como scroll horizontal
        if !competicionesFavoritas.isEmpty {
            Section {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(competicionesFavoritas) { comp in
                            NavigationLink(destination: LigaView(competicion: comp)) {
                                LigaCardFavorito(competicion: comp) {
                                    toggleFavorito(comp.id)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 14, bottom: 8, trailing: 14))
            } header: {
                Label("Favoritos", systemImage: "star.fill")
                    .foregroundColor(.yellow)
            }
        }

        // Todas las ligas
        Section {
            if competiciones.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 10) {
                        Image(systemName: "trophy").font(.largeTitle).foregroundColor(.secondary)
                        Text("No hay ligas disponibles").foregroundColor(.secondary)
                    }
                    .padding()
                    Spacer()
                }
            } else {
                ForEach(competiciones) { comp in
                    NavigationLink(destination: LigaView(competicion: comp)) {
                        LigaRowGrande(
                            competicion: comp,
                            esFavorito: favoritoIds.contains(comp.id)
                        )
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button {
                            withAnimation { toggleFavorito(comp.id) }
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
            if !competiciones.isEmpty {
                Text("Desliza a la izquierda para añadir a favoritos")
                    .font(.caption2)
            }
        }
    }

    // MARK: - Resultados de búsqueda

    @ViewBuilder
    var resultadosBusqueda: some View {
        if competicionesFiltradas.isEmpty && equiposFiltrados.isEmpty {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 36)).foregroundColor(.secondary)
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
                            LigaRowGrande(competicion: comp, esFavorito: favoritoIds.contains(comp.id))
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button {
                                withAnimation { toggleFavorito(comp.id) }
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
                            HStack(spacing: 14) {
                                InicialCircle(nombre: equipo.nombre, color: .blue, size: 42)
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

    // MARK: - Carga

    func cargar() async {
        await MainActor.run { errorMsg = nil }
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
            await MainActor.run {
                self.errorMsg = "No se pudieron cargar las ligas"
                self.cargando = false
            }
        }
    }
}

// MARK: - Componentes

struct LigaRowGrande: View {
    let competicion: Competicion
    let esFavorito: Bool

    // Color de acento por categoría (extensible)
    var accentColor: Color {
        let nombre = competicion.nombre.lowercased()
        if nombre.contains("tercera") { return .blue }
        if nombre.contains("segunda") { return .orange }
        if nombre.contains("primera") { return .green }
        return .purple
    }

    var body: some View {
        HStack(spacing: 14) {
            // Icono de competición
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(accentColor.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "trophy.fill")
                    .font(.title2)
                    .foregroundColor(accentColor)
            }

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text(competicion.nombre)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.primary).lineLimit(2)

                HStack(spacing: 6) {
                    if let grupo = competicion.grupo {
                        Label("Grupo \(grupo)", systemImage: "square.grid.2x2")
                            .font(.caption2).foregroundColor(.secondary)
                        Text("·").font(.caption2).foregroundColor(.secondary)
                    }
                    Label(competicion.temporada, systemImage: "calendar")
                        .font(.caption2).foregroundColor(.secondary)
                }
            }

            Spacer()

            if esFavorito {
                Image(systemName: "star.fill")
                    .font(.caption).foregroundColor(.yellow)
            }
        }
        .padding(.vertical, 6)
    }
}

struct LigaCardFavorito: View {
    let competicion: Competicion
    let onQuitar: () -> Void

    var accentColor: Color {
        let n = competicion.nombre.lowercased()
        if n.contains("tercera") { return .blue }
        if n.contains("segunda") { return .orange }
        if n.contains("primera") { return .green }
        return .purple
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Franja de color
            accentColor.frame(height: 3)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: "trophy.fill")
                        .font(.footnote).foregroundColor(accentColor)
                    Spacer()
                    Button(action: onQuitar) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11)).foregroundColor(.yellow)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                VStack(alignment: .leading, spacing: 2) {
                    Text(competicion.nombre)
                        .font(.caption).fontWeight(.semibold)
                        .foregroundColor(.primary).lineLimit(2)
                    if let grupo = competicion.grupo {
                        Text("Gr. \(grupo)")
                            .font(.caption2).foregroundColor(.secondary)
                    }
                    Text(competicion.temporada)
                        .font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(12)
        }
        .frame(width: 148, height: 108)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, x: 0, y: 2)
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
        ZStack {
            Circle()
                .fill(color.opacity(0.14))
                .frame(width: size, height: size)
            Text(String(nombre.prefix(2)).uppercased())
                .font(.system(size: size * 0.33, weight: .bold))
                .foregroundColor(color.opacity(0.85))
        }
    }
}
