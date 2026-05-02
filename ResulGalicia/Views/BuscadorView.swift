import SwiftUI

struct BuscadorView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var clubes: [Club] = []
    @State private var jugadores: [Jugador] = []
    @State private var busqueda = ""
    @State private var cargando = true

    var clubesFiltrados: [Club] {
        guard busqueda.count >= 2 else { return [] }
        let q = busqueda.lowercased()
        return clubes.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.localidad?.lowercased().contains(q) ?? false)
        }
    }

    var jugadoresFiltrados: [Jugador] {
        guard busqueda.count >= 2 else { return [] }
        let q = busqueda.lowercased()
        return jugadores.filter { $0.nombre.lowercased().contains(q) }
    }

    var hayResultados: Bool { !clubesFiltrados.isEmpty || !jugadoresFiltrados.isEmpty }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else {
                    contenido
                }
            }
            .navigationTitle("Buscador")
            .searchable(
                text: $busqueda,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: "Clubes, jugadores..."
            )
            .task { await cargar() }
        }
    }

    // MARK: - Contenido

    var contenido: some View {
        ScrollView {
            if busqueda.count < 2 {
                estadoVacio
            } else if !hayResultados {
                sinResultados
            } else {
                resultados
            }
        }
        .background(Color(.systemGroupedBackground))
        .animation(.default, value: busqueda)
    }

    var estadoVacio: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle().fill(Color.brand.opacity(0.08)).frame(width: 100, height: 100)
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40, weight: .light))
                    .foregroundColor(.brand.opacity(0.5))
            }
            VStack(spacing: 8) {
                Text("Busca clubes y jugadores")
                    .font(.title3).fontWeight(.semibold)
                Text("Escribe al menos 2 letras para buscar en toda la base de datos.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    var sinResultados: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 38)).foregroundColor(.secondary.opacity(0.35))
            Text("Sin resultados para «\(busqueda)»")
                .font(.subheadline).foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }

    var resultados: some View {
        LazyVStack(spacing: 0, pinnedViews: []) {
            if !clubesFiltrados.isEmpty {
                seccionLabel("Clubes")
                VStack(spacing: 0) {
                    ForEach(clubesFiltrados.prefix(15)) { club in
                        NavigationLink(destination: ClubDetalleView(club: club)) {
                            HStack(spacing: 14) {
                                EscudoView(url: club.escudoUrl, size: 40)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(club.nombre)
                                        .font(.subheadline).fontWeight(.semibold)
                                        .foregroundColor(.primary).lineLimit(1)
                                    if let loc = club.localidad {
                                        Text([loc, club.provincia].compactMap { $0 }.joined(separator: " · "))
                                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                                    }
                                }
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        if club.id != clubesFiltrados.prefix(15).last?.id {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }

            if !jugadoresFiltrados.isEmpty {
                seccionLabel("Jugadores")
                VStack(spacing: 0) {
                    ForEach(jugadoresFiltrados.prefix(30)) { jugador in
                        NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                            HStack(spacing: 12) {
                                InicialCircle(nombre: jugador.nombre, color: .brand, size: 40)
                                Text(nombreCorto(jugador.nombre))
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundColor(.primary).lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        if jugador.id != jugadoresFiltrados.prefix(30).last?.id {
                            Divider().padding(.leading, 68)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 14)
    }

    func seccionLabel(_ texto: String) -> some View {
        Text(texto.uppercased())
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.secondary)
            .kerning(0.5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 16).padding(.bottom, 8)
    }

    // MARK: - Carga

    func cargar() async {
        do {
            async let cs = service.fetchClubes()
            async let js = service.fetchTodosJugadores()
            let (clubResult, jugResult) = try await (cs, js)
            await MainActor.run {
                self.clubes = clubResult
                self.jugadores = jugResult
                self.cargando = false
            }
        } catch {
            await MainActor.run { self.cargando = false }
        }
    }
}
