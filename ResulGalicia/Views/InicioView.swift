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

    // MARK: - Contenido

    var contenido: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: []) {
                if buscando {
                    resultadosBusqueda
                } else {
                    contenidoNormal
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.default, value: busqueda)
    }

    // MARK: - Sin búsqueda

    @ViewBuilder
    var contenidoNormal: some View {
        // Favoritos
        if !competicionesFavoritas.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                sectionLabel("Favoritos", icon: "star.fill", iconColor: .yellow)
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(competicionesFavoritas) { comp in
                            NavigationLink(destination: LigaView(competicion: comp)) {
                                LigaCardFavorito(competicion: comp) {
                                    withAnimation { toggleFavorito(comp.id) }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 2)
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
        }

        // Ligas
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel("Competiciones", icon: "trophy.fill", iconColor: .secondary)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            if competiciones.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "trophy").font(.largeTitle).foregroundColor(.secondary)
                    Text("No hay ligas disponibles").foregroundColor(.secondary).font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
            } else {
                VStack(spacing: 0) {
                    ForEach(competiciones) { comp in
                        ligaRow(comp)
                        if comp.id != competiciones.last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
        .padding(.bottom, 20)
    }

    // MARK: - Resultados de búsqueda

    @ViewBuilder
    var resultadosBusqueda: some View {
        if competicionesFiltradas.isEmpty && equiposFiltrados.isEmpty {
            VStack(spacing: 14) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40)).foregroundColor(.secondary.opacity(0.4))
                Text("Sin resultados para «\(busqueda)»")
                    .foregroundColor(.secondary).font(.subheadline)
            }
            .frame(maxWidth: .infinity)
            .padding(60)
        } else {
            VStack(spacing: 0) {
                if !competicionesFiltradas.isEmpty {
                    sectionLabel("Ligas", icon: "trophy.fill", iconColor: .secondary)
                        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(competicionesFiltradas) { comp in
                            ligaRow(comp)
                            if comp.id != competicionesFiltradas.last?.id {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }

                if !equiposFiltrados.isEmpty {
                    sectionLabel("Equipos", icon: "person.3.fill", iconColor: .secondary)
                        .padding(.horizontal, 16).padding(.top, 20).padding(.bottom, 8)

                    VStack(spacing: 0) {
                        ForEach(equiposFiltrados) { equipo in
                            NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                                HStack(spacing: 12) {
                                    InicialCircle(nombre: equipo.nombre, color: .blue, size: 40)
                                    Text(equipo.nombre)
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundColor(.secondary)
                                }
                                .padding(.horizontal, 16).padding(.vertical, 12)
                            }
                            if equipo.id != equiposFiltrados.last?.id {
                                Divider().padding(.leading, 68)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Fila de liga con swipe

    @ViewBuilder
    func ligaRow(_ comp: Competicion) -> some View {
        NavigationLink(destination: LigaView(competicion: comp)) {
            LigaRowGrande(competicion: comp, esFavorito: favoritoIds.contains(comp.id))
        }
        .contextMenu {
            Button {
                withAnimation { toggleFavorito(comp.id) }
            } label: {
                Label(
                    favoritoIds.contains(comp.id) ? "Quitar de favoritos" : "Añadir a favoritos",
                    systemImage: favoritoIds.contains(comp.id) ? "star.slash" : "star"
                )
            }
        }
    }

    // MARK: - Helper

    func sectionLabel(_ texto: String, icon: String, iconColor: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(iconColor)
            Text(texto.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(0.5)
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

// MARK: - LigaRowGrande

struct LigaRowGrande: View {
    let competicion: Competicion
    let esFavorito: Bool

    var accentColor: Color {
        let n = competicion.nombre.lowercased()
        if n.contains("tercera") { return .blue }
        if n.contains("segunda") { return .orange }
        if n.contains("primera") { return .green }
        return .purple
    }

    var subtitulo: String {
        var partes: [String] = []
        if let g = competicion.grupo { partes.append(g) }
        partes.append(competicion.temporada)
        return partes.joined(separator: " · ")
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(accentColor.opacity(0.1))
                    .frame(width: 40, height: 40)
                Image(systemName: "trophy.fill")
                    .font(.system(size: 17))
                    .foregroundColor(accentColor)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(competicion.nombre)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                Text(subtitulo)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if esFavorito {
                Image(systemName: "star.fill")
                    .font(.caption2).foregroundColor(.yellow)
            }

            Image(systemName: "chevron.right")
                .font(.caption2).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - LigaCardFavorito

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
            accentColor.frame(height: 3)

            VStack(alignment: .leading, spacing: 0) {
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
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    if let grupo = competicion.grupo {
                        Text(grupo)
                            .font(.caption2).foregroundColor(.secondary)
                            .lineLimit(1)
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
        .shadow(color: .black.opacity(0.06), radius: 5, x: 0, y: 2)
    }
}

// MARK: - InicialCircle

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
