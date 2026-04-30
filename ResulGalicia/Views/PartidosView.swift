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

    var grupos: [(fecha: String, etiqueta: String, partidos: [Partido])] {
        var dict: [String: [Partido]] = [:]
        for p in partidosFiltrados {
            let key = p.fecha ?? "Sin fecha"
            dict[key, default: []].append(p)
        }
        return dict.keys.sorted(by: >).map { key in
            (fecha: key, etiqueta: formatearFecha(key), partidos: dict[key]!)
        }
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
                            filtroJornadas
                        }
                        listaPartidos
                    }
                }
            }
            .navigationTitle("Partidos")
            .background(Color(.systemGroupedBackground))
            .task { await cargar() }
        }
    }

    var filtroJornadas: some View {
        VStack(spacing: 0) {
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
                .padding(.horizontal, 16).padding(.vertical, 10)
            }
            .background(Color(.systemBackground))
            Divider()
        }
    }

    var listaPartidos: some View {
        List {
            ForEach(grupos, id: \.fecha) { grupo in
                Section {
                    ForEach(grupo.partidos) { partido in
                        NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
                            PartidoRowFlash(partido: partido, equipos: equipos)
                        }
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12))
                        .listRowSeparatorTint(Color(.separator).opacity(0.5))
                    }
                } header: {
                    FechaHeader(texto: grupo.etiqueta)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await cargar() }
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

// MARK: - Row estilo Flashscore

struct PartidoRowFlash: View {
    let partido: Partido
    let equipos: [UUID: Equipo]

    private var local: String { equipos[partido.equipoLocalId]?.nombre ?? "—" }
    private var visitante: String { equipos[partido.equipoVisitanteId]?.nombre ?? "—" }
    private var localGana: Bool { partido.golesLocal > partido.golesVisitante }
    private var visitanteGana: Bool { partido.golesVisitante > partido.golesLocal }
    private var empate: Bool { partido.golesLocal == partido.golesVisitante }

    var body: some View {
        HStack(spacing: 0) {
            // Estado
            VStack(spacing: 2) {
                Text("FT")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.secondary)
                    .kerning(0.5)
            }
            .frame(width: 40)
            .padding(.vertical, 16)

            // Separador vertical
            Rectangle()
                .fill(Color(.separator).opacity(0.5))
                .frame(width: 0.5)
                .padding(.vertical, 10)

            // Equipos + scores
            VStack(spacing: 0) {
                equipoFila(
                    nombre: local,
                    goles: partido.golesLocal,
                    gana: localGana
                )
                Rectangle()
                    .fill(Color(.separator).opacity(0.4))
                    .frame(height: 0.5)
                    .padding(.leading, 42)
                equipoFila(
                    nombre: visitante,
                    goles: partido.golesVisitante,
                    gana: visitanteGana
                )
            }
            .padding(.leading, 8)
        }
    }

    func equipoFila(nombre: String, goles: Int, gana: Bool) -> some View {
        HStack(spacing: 10) {
            // Círculo inicial pequeño
            Circle()
                .fill(Color.blue.opacity(0.1))
                .frame(width: 28, height: 28)
                .overlay(
                    Text(String(nombre.prefix(2)).uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.blue)
                )

            Text(nombre)
                .font(.subheadline)
                .fontWeight(gana ? .semibold : .regular)
                .foregroundColor(gana ? .primary : .secondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(goles)")
                .font(.subheadline)
                .fontWeight(gana ? .bold : .regular)
                .foregroundColor(gana ? .primary : .secondary)
                .monospacedDigit()
                .frame(width: 18, alignment: .trailing)
                .padding(.trailing, 12)
        }
        .padding(.vertical, 11)
    }
}

// MARK: - Cabecera de fecha

struct FechaHeader: View {
    let texto: String

    var body: some View {
        Text(texto.uppercased())
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .kerning(0.5)
            .textCase(nil)
            .padding(.vertical, 4)
    }
}

// MARK: - Helpers

func formatearFecha(_ fechaStr: String) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "es_ES")
    let formatos = ["yyyy-MM-dd", "dd/MM/yyyy", "yyyy-MM-dd'T'HH:mm:ss"]
    for formato in formatos {
        formatter.dateFormat = formato
        if let date = formatter.date(from: fechaStr) {
            formatter.dateFormat = "EEEE, d 'de' MMMM"
            return formatter.string(from: date).capitalized
        }
    }
    return fechaStr
}

// MARK: - ErrorStateView

struct ErrorStateView: View {
    let mensaje: String
    let reintentar: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 44)).foregroundColor(.orange)
            Text(mensaje).font(.headline).multilineTextAlignment(.center)
            Text("Comprueba tu conexión e inténtalo de nuevo")
                .font(.subheadline).foregroundColor(.secondary).multilineTextAlignment(.center)
            Button("Reintentar", action: reintentar)
                .buttonStyle(.bordered).controlSize(.large)
        }
        .padding(32)
    }
}
