import SwiftUI

struct PartidosView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var partidos: [Partido] = []
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var jornadaSeleccionada: Int? = nil

    var jornadasDisponibles: [Int] {
        Array(Set(partidos.compactMap { $0.jornada })).sorted()
    }

    var partidosFiltrados: [Partido] {
        guard let j = jornadaSeleccionada else { return partidos }
        return partidos.filter { $0.jornada == j }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    VStack(spacing: 0) {
                        if jornadasDisponibles.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    JornadaChip(label: "Todas", seleccionada: jornadaSeleccionada == nil) {
                                        jornadaSeleccionada = nil
                                    }
                                    ForEach(jornadasDisponibles, id: \.self) { j in
                                        JornadaChip(label: "J\(j)", seleccionada: jornadaSeleccionada == j) {
                                            jornadaSeleccionada = j
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                            }
                            Divider()
                        }
                        List(partidosFiltrados) { partido in
                            NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
                                PartidoRowView(partido: partido, equipos: equipos)
                            }
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        .listStyle(.plain)
                        .refreshable { await cargar() }
                    }
                }
            }
            .navigationTitle("Partidos")
            .task { await cargar() }
        }
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            let ps = try await service.fetchPartidos()
            var eq: [UUID: Equipo] = [:]
            for p in ps {
                if eq[p.equipoLocalId] == nil {
                    eq[p.equipoLocalId] = try await service.fetchEquipo(id: p.equipoLocalId)
                }
                if eq[p.equipoVisitanteId] == nil {
                    eq[p.equipoVisitanteId] = try await service.fetchEquipo(id: p.equipoVisitanteId)
                }
            }
            await MainActor.run {
                self.partidos = ps
                self.equipos = eq
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudieron cargar los partidos"
                self.cargando = false
            }
        }
    }
}

struct PartidoRowView: View {
    let partido: Partido
    let equipos: [UUID: Equipo]

    private var local: String { equipos[partido.equipoLocalId]?.nombre ?? "..." }
    private var visitante: String { equipos[partido.equipoVisitanteId]?.nombre ?? "..." }

    var body: some View {
        VStack(spacing: 10) {
            // Metadatos
            HStack {
                if let fecha = partido.fecha {
                    Label(fecha, systemImage: "calendar")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let jornada = partido.jornada {
                    Text("Jornada \(jornada)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Equipos y marcador
            HStack(spacing: 10) {
                Text(local)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: .infinity, alignment: .trailing)

                Text("\(partido.golesLocal) – \(partido.golesVisitante)")
                    .font(.title3)
                    .fontWeight(.bold)
                    .monospacedDigit()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(8)

                Text(visitante)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(.vertical, 6)
    }
}

struct ErrorStateView: View {
    let mensaje: String
    let reintentar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44))
                .foregroundColor(.orange)
            Text(mensaje)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Comprueba tu conexión e inténtalo de nuevo")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar", action: reintentar)
                .buttonStyle(.bordered)
                .controlSize(.large)
        }
        .padding(32)
    }
}
