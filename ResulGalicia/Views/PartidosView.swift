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
                    ErrorStateView(mensaje: msg) {
                        Task { await cargar() }
                    }
                } else {
                    VStack(spacing: 0) {
                        if jornadasDisponibles.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    jornadaChip(label: "Todas", jornada: nil)
                                    ForEach(jornadasDisponibles, id: \.self) { j in
                                        jornadaChip(label: "J\(j)", jornada: j)
                                    }
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 8)
                            }
                            Divider()
                        }
                        List(partidosFiltrados) { partido in
                            NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
                                PartidoRowView(partido: partido, equipos: equipos)
                            }
                        }
                        .listStyle(.plain)
                        .refreshable { await cargar() }
                    }
                }
            }
            .navigationTitle("Partidos")
            .task {
                await cargar()
            }
        }
    }

    func jornadaChip(label: String, jornada: Int?) -> some View {
        let seleccionada = jornadaSeleccionada == jornada
        return Button(action: { jornadaSeleccionada = jornada }) {
            Text(label)
                .font(.caption)
                .fontWeight(seleccionada ? .bold : .regular)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(seleccionada ? Color.blue : Color(.systemGray5))
                .foregroundColor(seleccionada ? .white : .primary)
                .cornerRadius(16)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                if let fecha = partido.fecha {
                    Text(fecha)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let jornada = partido.jornada {
                    Text("J\(jornada)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            HStack {
                Text(equipos[partido.equipoLocalId]?.nombre ?? "...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                Text(equipos[partido.equipoVisitanteId]?.nombre ?? "...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ErrorStateView: View {
    let mensaje: String
    let reintentar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40))
                .foregroundColor(.orange)
            Text(mensaje)
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Comprueba tu conexión e inténtalo de nuevo")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Reintentar", action: reintentar)
                .buttonStyle(.bordered)
        }
        .padding(32)
    }
}
