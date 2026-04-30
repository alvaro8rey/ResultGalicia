import SwiftUI

struct ClasificacionView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var partidos: [Partido] = []
    @State private var goles: [Gol] = []
    @State private var jugadores: [UUID: Jugador] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var vistaActual: String = "clasificacion"

    struct FilaClasificacion: Identifiable {
        let id: UUID
        let nombre: String
        var pj: Int = 0
        var pg: Int = 0
        var pe: Int = 0
        var pp: Int = 0
        var gf: Int = 0
        var gc: Int = 0
        var puntos: Int { pg * 3 + pe }
        var dg: Int { gf - gc }
    }

    struct FilaGoleador: Identifiable {
        let id: UUID
        let nombre: String
        let equipo: String
        let goles: Int
    }

    var clasificacion: [FilaClasificacion] {
        var filas: [UUID: FilaClasificacion] = [:]
        for e in equipos {
            filas[e.id] = FilaClasificacion(id: e.id, nombre: e.nombre)
        }
        for p in partidos {
            guard var local = filas[p.equipoLocalId],
                  var visitante = filas[p.equipoVisitanteId] else { continue }
            local.pj += 1
            visitante.pj += 1
            local.gf += p.golesLocal
            local.gc += p.golesVisitante
            visitante.gf += p.golesVisitante
            visitante.gc += p.golesLocal
            if p.golesLocal > p.golesVisitante {
                local.pg += 1
                visitante.pp += 1
            } else if p.golesLocal < p.golesVisitante {
                visitante.pg += 1
                local.pp += 1
            } else {
                local.pe += 1
                visitante.pe += 1
            }
            filas[p.equipoLocalId] = local
            filas[p.equipoVisitanteId] = visitante
        }
        return filas.values.sorted { $0.puntos != $1.puntos ? $0.puntos > $1.puntos : $0.dg > $1.dg }
    }

    var topGoleadores: [FilaGoleador] {
        var conteo: [UUID: Int] = [:]
        for gol in goles {
            conteo[gol.jugadorId, default: 0] += 1
        }
        return conteo
            .compactMap { (jugadorId, total) -> FilaGoleador? in
                guard let jugador = jugadores[jugadorId] else { return nil }
                let nombreEquipo = equipos.first(where: { $0.id == jugador.equipoId })?.nombre ?? ""
                return FilaGoleador(id: jugadorId, nombre: jugador.nombre, equipo: nombreEquipo, goles: total)
            }
            .sorted { $0.goles > $1.goles }
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
                        Picker("Vista", selection: $vistaActual) {
                            Text("Clasificación").tag("clasificacion")
                            Text("Goleadores").tag("goleadores")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .padding(.vertical, 8)

                        if vistaActual == "clasificacion" {
                            listaClasificacion
                        } else {
                            listaGoleadores
                        }
                    }
                }
            }
            .navigationTitle("Clasificación")
            .task { await cargar() }
        }
    }

    var listaClasificacion: some View {
        List {
            HStack {
                Text("#").frame(width: 24)
                Text("Equipo").frame(maxWidth: .infinity, alignment: .leading)
                Text("PJ").frame(width: 28)
                Text("PG").frame(width: 28)
                Text("PE").frame(width: 28)
                Text("PP").frame(width: 28)
                Text("GD").frame(width: 32)
                Text("Pts").frame(width: 32)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            ForEach(Array(clasificacion.enumerated()), id: \.element.id) { i, fila in
                HStack {
                    Text("\(i + 1)").frame(width: 24).font(.caption).foregroundColor(.secondary)
                    Text(fila.nombre).frame(maxWidth: .infinity, alignment: .leading).font(.subheadline)
                    Text("\(fila.pj)").frame(width: 28).font(.caption)
                    Text("\(fila.pg)").frame(width: 28).font(.caption)
                    Text("\(fila.pe)").frame(width: 28).font(.caption)
                    Text("\(fila.pp)").frame(width: 28).font(.caption)
                    Text("\(fila.dg)").frame(width: 32).font(.caption)
                    Text("\(fila.puntos)").frame(width: 32).font(.caption).fontWeight(.bold)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await cargar() }
    }

    var listaGoleadores: some View {
        List {
            HStack {
                Text("#").frame(width: 24)
                Text("Jugador").frame(maxWidth: .infinity, alignment: .leading)
                Text("Equipo").frame(maxWidth: .infinity, alignment: .leading)
                Text("Gls").frame(width: 36)
            }
            .font(.caption)
            .foregroundColor(.secondary)

            ForEach(Array(topGoleadores.enumerated()), id: \.element.id) { i, fila in
                HStack {
                    Text("\(i + 1)").frame(width: 24).font(.caption).foregroundColor(.secondary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fila.nombre).font(.subheadline)
                        Text(fila.equipo).font(.caption2).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    HStack(spacing: 4) {
                        Text("⚽")
                            .font(.caption)
                        Text("\(fila.goles)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                    }
                    .frame(width: 36)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await cargar() }
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let e = service.fetchEquipos()
            async let p = service.fetchPartidos()
            async let g = service.fetchTodosGoles()
            async let j = service.fetchTodosJugadores()
            let (es, ps, gs, js) = try await (e, p, g, j)
            let jugadoresMap = Dictionary(uniqueKeysWithValues: js.map { ($0.id, $0) })
            await MainActor.run {
                self.equipos = es
                self.partidos = ps
                self.goles = gs
                self.jugadores = jugadoresMap
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar la clasificación"
                self.cargando = false
            }
        }
    }
}
