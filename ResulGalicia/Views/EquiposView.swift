import SwiftUI

struct EquiposView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var cargando = true

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else {
                    List(equipos) { equipo in
                        NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.blue.opacity(0.15))
                                    .frame(width: 44, height: 44)
                                    .overlay(
                                        Text(String(equipo.nombre.prefix(2)))
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.blue)
                                    )
                                Text(equipo.nombre)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Equipos")
            .task { await cargar() }
        }
    }

    func cargar() async {
        do {
            let es = try await service.fetchEquipos()
            await MainActor.run {
                self.equipos = es
                self.cargando = false
            }
        } catch {
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}

struct EquipoDetalleView: View {
    let equipo: Equipo
    @EnvironmentObject var service: SupabaseService
    @State private var jugadores: [Jugador] = []
    @State private var partidos: [Partido] = []
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var cargando = true

    var victorias: Int { partidos.filter {
        ($0.equipoLocalId == equipo.id && $0.golesLocal > $0.golesVisitante) ||
        ($0.equipoVisitanteId == equipo.id && $0.golesVisitante > $0.golesLocal)
    }.count }

    var empates: Int { partidos.filter { $0.golesLocal == $0.golesVisitante }.count }
    var derrotas: Int { partidos.count - victorias - empates }
    var puntos: Int { victorias * 3 + empates }
    var golesFavor: Int {
        partidos.reduce(0) {
            $0 + ($1.equipoLocalId == equipo.id ? $1.golesLocal : $1.golesVisitante)
        }
    }
    var golesContra: Int {
        partidos.reduce(0) {
            $0 + ($1.equipoLocalId == equipo.id ? $1.golesVisitante : $1.golesLocal)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Cabecera equipo
                VStack(spacing: 8) {
                    Circle()
                        .fill(Color.blue.opacity(0.15))
                        .frame(width: 72, height: 72)
                        .overlay(
                            Text(String(equipo.nombre.prefix(2)))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.blue)
                        )
                    Text(equipo.nombre)
                        .font(.title3)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if cargando {
                    ProgressView()
                } else {
                    // Stats
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Temporada")
                            .font(.headline)
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            StatBox(valor: "\(puntos)", etiqueta: "Pts")
                            StatBox(valor: "\(victorias)", etiqueta: "PG")
                            StatBox(valor: "\(empates)", etiqueta: "PE")
                            StatBox(valor: "\(derrotas)", etiqueta: "PP")
                        }
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 10) {
                            StatBox(valor: "\(golesFavor)", etiqueta: "GF")
                            StatBox(valor: "\(golesContra)", etiqueta: "GC")
                            StatBox(valor: "\(golesFavor - golesContra > 0 ? "+" : "")\(golesFavor - golesContra)", etiqueta: "DG")
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Plantilla
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Plantilla (\(jugadores.count))")
                            .font(.headline)
                        ForEach(jugadores) { jugador in
                            NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                                HStack(spacing: 12) {
                                    Circle()
                                        .fill(Color.green.opacity(0.15))
                                        .frame(width: 36, height: 36)
                                        .overlay(
                                            Text(String(jugador.nombre.split(separator: ",").first?.prefix(1) ?? "?"))
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.green)
                                        )
                                    Text(jugador.nombre)
                                        .font(.subheadline)
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            if jugador.id != jugadores.last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    // Últimos partidos
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Partidos")
                            .font(.headline)
                        ForEach(partidos.prefix(10)) { partido in
                            HStack {
                                Text(partido.fecha ?? "")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 90, alignment: .leading)
                                Text(equipos[partido.equipoLocalId]?.nombre ?? "")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                Text("\(partido.golesLocal)-\(partido.golesVisitante)")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                Text(equipos[partido.equipoVisitanteId]?.nombre ?? "")
                                    .font(.caption)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                resultadoIcon(partido: partido)
                            }
                            if partido.id != partidos.prefix(10).last?.id {
                                Divider()
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
        .navigationTitle(equipo.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    func resultadoIcon(partido: Partido) -> some View {
        let gano = (partido.equipoLocalId == equipo.id && partido.golesLocal > partido.golesVisitante) ||
                   (partido.equipoVisitanteId == equipo.id && partido.golesVisitante > partido.golesLocal)
        let empato = partido.golesLocal == partido.golesVisitante
        return Text(gano ? "V" : empato ? "E" : "D")
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(gano ? Color.green : empato ? Color.orange : Color.red)
            .cornerRadius(4)
    }

    func cargar() async {
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
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}
