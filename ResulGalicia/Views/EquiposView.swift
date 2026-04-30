import SwiftUI

struct EquiposView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    List(equipos) { equipo in
                        NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                            HStack(spacing: 14) {
                                InicialCircle(nombre: equipo.nombre, color: .blue, size: 44)
                                Text(equipo.nombre)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                    .refreshable { await cargar() }
                }
            }
            .navigationTitle("Equipos")
            .task { await cargar() }
        }
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            let es = try await service.fetchEquipos()
            await MainActor.run { self.equipos = es; self.cargando = false }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudieron cargar los equipos"
                self.cargando = false
            }
        }
    }
}

// MARK: - Equipo Detalle

struct EquipoDetalleView: View {
    let equipo: Equipo
    @EnvironmentObject var service: SupabaseService
    @State private var jugadores: [Jugador] = []
    @State private var partidos: [Partido] = []
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    var victorias: Int {
        partidos.filter {
            ($0.equipoLocalId == equipo.id && $0.golesLocal > $0.golesVisitante) ||
            ($0.equipoVisitanteId == equipo.id && $0.golesVisitante > $0.golesLocal)
        }.count
    }
    var empates: Int { partidos.filter { $0.golesLocal == $0.golesVisitante }.count }
    var derrotas: Int { partidos.count - victorias - empates }
    var puntos: Int { victorias * 3 + empates }
    var golesFavor: Int {
        partidos.reduce(0) { $0 + ($1.equipoLocalId == equipo.id ? $1.golesLocal : $1.golesVisitante) }
    }
    var golesContra: Int {
        partidos.reduce(0) { $0 + ($1.equipoLocalId == equipo.id ? $1.golesVisitante : $1.golesLocal) }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Cabecera
                VStack(spacing: 10) {
                    InicialCircle(nombre: equipo.nombre, color: .blue, size: 72)
                    Text(equipo.nombre)
                        .font(.title2).fontWeight(.bold).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(16)

                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    // Stats temporada
                    InfoCard(titulo: "Temporada") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                            StatBox(valor: "\(puntos)", etiqueta: "Pts")
                            StatBox(valor: "\(victorias)", etiqueta: "PG")
                            StatBox(valor: "\(empates)", etiqueta: "PE")
                            StatBox(valor: "\(derrotas)", etiqueta: "PP")
                        }
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
                            StatBox(valor: "\(golesFavor)", etiqueta: "GF")
                            StatBox(valor: "\(golesContra)", etiqueta: "GC")
                            StatBox(
                                valor: "\(golesFavor - golesContra >= 0 ? "+" : "")\(golesFavor - golesContra)",
                                etiqueta: "DG"
                            )
                        }
                    }

                    // Plantilla
                    InfoCard(titulo: "Plantilla (\(jugadores.count))") {
                        VStack(spacing: 0) {
                            ForEach(jugadores) { jugador in
                                NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                                    HStack(spacing: 12) {
                                        InicialCircle(
                                            nombre: String(jugador.nombre.split(separator: ",").first ?? "?"),
                                            color: .green, size: 36
                                        )
                                        Text(jugador.nombre)
                                            .font(.subheadline)
                                            .foregroundColor(.primary)
                                            .lineLimit(1)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .font(.caption2).foregroundColor(.secondary)
                                    }
                                    .padding(.vertical, 8)
                                }
                                if jugador.id != jugadores.last?.id {
                                    Divider().padding(.leading, 48)
                                }
                            }
                        }
                    }

                    // Partidos
                    InfoCard(titulo: "Partidos") {
                        VStack(spacing: 0) {
                            ForEach(partidos.prefix(10)) { partido in
                                HStack(spacing: 8) {
                                    Text(partido.fecha ?? "")
                                        .font(.caption2).foregroundColor(.secondary).lineLimit(1)
                                        .frame(width: 80, alignment: .leading)
                                    Text(equipos[partido.equipoLocalId]?.nombre ?? "")
                                        .font(.caption).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                    Text("\(partido.golesLocal)–\(partido.golesVisitante)")
                                        .font(.caption).fontWeight(.bold).monospacedDigit()
                                        .padding(.horizontal, 6)
                                    Text(equipos[partido.equipoVisitanteId]?.nombre ?? "")
                                        .font(.caption).lineLimit(1)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    resultadoBadge(partido: partido)
                                }
                                .padding(.vertical, 7)
                                if partido.id != partidos.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(equipo.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    func resultadoBadge(partido: Partido) -> some View {
        let gano = (partido.equipoLocalId == equipo.id && partido.golesLocal > partido.golesVisitante) ||
                   (partido.equipoVisitanteId == equipo.id && partido.golesVisitante > partido.golesLocal)
        let empato = partido.golesLocal == partido.golesVisitante
        let color: Color = gano ? .green : empato ? .orange : .red
        let letra = gano ? "V" : empato ? "E" : "D"
        return Text(letra)
            .font(.caption2).fontWeight(.bold).foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(color).cornerRadius(5)
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let j = service.fetchJugadores(equipoId: equipo.id)
            async let p = service.fetchPartidosPorEquipo(equipoId: equipo.id)
            let (js, ps) = try await (j, p)
            var eq: [UUID: Equipo] = [:]
            for partido in ps {
                if eq[partido.equipoLocalId] == nil {
                    eq[partido.equipoLocalId] = try await service.fetchEquipo(id: partido.equipoLocalId)
                }
                if eq[partido.equipoVisitanteId] == nil {
                    eq[partido.equipoVisitanteId] = try await service.fetchEquipo(id: partido.equipoVisitanteId)
                }
            }
            await MainActor.run {
                self.jugadores = js
                self.partidos = ps
                self.equipos = eq
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar el equipo"
                self.cargando = false
            }
        }
    }
}
