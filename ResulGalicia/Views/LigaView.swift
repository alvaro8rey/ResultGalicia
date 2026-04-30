import SwiftUI

// MARK: - Tipos compartidos de clasificación

struct FilaClasificacion: Identifiable {
    let id: UUID
    let nombre: String
    var pj = 0, pg = 0, pe = 0, pp = 0, gf = 0, gc = 0
    var pts: Int { pg * 3 + pe }
    var dg: Int { gf - gc }
}

struct FilaGoleador: Identifiable {
    let id: UUID
    let nombre: String
    let equipo: String
    let goles: Int
}

func calcularClasificacion(equipos: [Equipo], partidos: [Partido]) -> [FilaClasificacion] {
    var filas: [UUID: FilaClasificacion] = [:]
    for e in equipos { filas[e.id] = FilaClasificacion(id: e.id, nombre: e.nombre) }
    for p in partidos {
        guard var loc = filas[p.equipoLocalId], var vis = filas[p.equipoVisitanteId] else { continue }
        loc.pj += 1; vis.pj += 1
        loc.gf += p.golesLocal; loc.gc += p.golesVisitante
        vis.gf += p.golesVisitante; vis.gc += p.golesLocal
        if p.golesLocal > p.golesVisitante { loc.pg += 1; vis.pp += 1 }
        else if p.golesLocal < p.golesVisitante { vis.pg += 1; loc.pp += 1 }
        else { loc.pe += 1; vis.pe += 1 }
        filas[p.equipoLocalId] = loc
        filas[p.equipoVisitanteId] = vis
    }
    return filas.values.sorted { $0.pts != $1.pts ? $0.pts > $1.pts : $0.dg > $1.dg }
}

func calcularGoleadores(goles: [Gol], jugadores: [UUID: Jugador], equipos: [Equipo]) -> [FilaGoleador] {
    var conteo: [UUID: Int] = [:]
    for g in goles { conteo[g.jugadorId, default: 0] += 1 }
    return conteo.compactMap { (jugId, total) -> FilaGoleador? in
        guard let jug = jugadores[jugId] else { return nil }
        let equipo = equipos.first(where: { $0.id == jug.equipoId })?.nombre ?? ""
        return FilaGoleador(id: jugId, nombre: jug.nombre, equipo: equipo, goles: total)
    }.sorted { $0.goles > $1.goles }
}

// MARK: - LigaView

struct LigaView: View {
    let competicion: Competicion
    @EnvironmentObject var service: SupabaseService
    @State private var partidos: [Partido] = []
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var equiposList: [Equipo] = []
    @State private var goles: [Gol] = []
    @State private var jugadores: [UUID: Jugador] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var tab = "partidos"
    @State private var jornadaSeleccionada: Int? = nil

    var clasificacion: [FilaClasificacion] {
        calcularClasificacion(equipos: equiposList, partidos: partidos)
    }

    var topGoleadores: [FilaGoleador] {
        let matchIds = Set(partidos.map { $0.id })
        let golesLiga = goles.filter { matchIds.contains($0.partidoId) }
        return calcularGoleadores(goles: golesLiga, jugadores: jugadores, equipos: equiposList)
    }

    var jornadasDisponibles: [Int] {
        Array(Set(partidos.compactMap { $0.jornada })).sorted()
    }

    var partidosFiltrados: [Partido] {
        guard let j = jornadaSeleccionada else { return partidos }
        return partidos.filter { $0.jornada == j }
    }

    var titulo: String {
        var t = competicion.nombre
        if let g = competicion.grupo { t += " · Gr. \(g)" }
        return t
    }

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $tab) {
                Text("Partidos").tag("partidos")
                Text("Clasificación").tag("clasificacion")
                Text("Goleadores").tag("goleadores")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemBackground))

            Divider()

            if cargando {
                Spacer()
                ProgressView()
                Spacer()
            } else if let msg = errorMsg {
                Spacer()
                ErrorStateView(mensaje: msg) { Task { await cargar() } }
                Spacer()
            } else {
                switch tab {
                case "clasificacion": clasificacionView
                case "goleadores": goleadoresView
                default: partidosView
                }
            }
        }
        .navigationTitle(titulo)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    // MARK: - Partidos

    var partidosView: some View {
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
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                Divider()
            }

            if partidosFiltrados.isEmpty {
                Spacer()
                Text("No hay partidos").foregroundColor(.secondary).font(.subheadline)
                Spacer()
            } else {
                let grupos = Dictionary(grouping: partidosFiltrados) { $0.fecha ?? "Sin fecha" }
                let fechasOrdenadas = grupos.keys.sorted(by: >)
                List {
                    ForEach(fechasOrdenadas, id: \.self) { fecha in
                        Section {
                            ForEach(grupos[fecha]!) { partido in
                                NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
                                    PartidoRowFlash(partido: partido, equipos: equipos)
                                }
                                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 12))
                                .listRowSeparatorTint(Color(.separator).opacity(0.5))
                            }
                        } header: {
                            FechaHeader(texto: formatearFecha(fecha))
                        }
                    }
                }
                .listStyle(.plain)
                .refreshable { await cargar() }
            }
        }
    }

    // MARK: - Clasificación

    var clasificacionView: some View {
        let tabla = clasificacion
        let total = tabla.count
        return List {
            Section {
                ClasificacionCabecera()
                ForEach(Array(tabla.enumerated()), id: \.element.id) { i, fila in
                    ClasificacionRow(posicion: i + 1, fila: fila, total: total)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await cargar() }
    }

    // MARK: - Goleadores

    var goleadoresView: some View {
        GoleadoresList(lista: topGoleadores)
            .refreshable { await cargar() }
    }

    // MARK: - Carga

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            let ps = try await service.fetchPartidos(competicionId: competicion.id)
            var eq: [UUID: Equipo] = [:]
            for p in ps {
                if eq[p.equipoLocalId] == nil {
                    eq[p.equipoLocalId] = try await service.fetchEquipo(id: p.equipoLocalId)
                }
                if eq[p.equipoVisitanteId] == nil {
                    eq[p.equipoVisitanteId] = try await service.fetchEquipo(id: p.equipoVisitanteId)
                }
            }
            let eqList = Array(eq.values).sorted { $0.nombre < $1.nombre }

            async let todosGoles = service.fetchTodosGoles()
            async let todosJugs = service.fetchTodosJugadores()
            let (gs, js) = try await (todosGoles, todosJugs)

            await MainActor.run {
                self.partidos = ps
                self.equipos = eq
                self.equiposList = eqList
                self.goles = gs
                self.jugadores = Dictionary(uniqueKeysWithValues: js.map { ($0.id, $0) })
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar la liga"
                self.cargando = false
            }
        }
    }
}

// MARK: - Subcomponentes reutilizables

struct ClasificacionCabecera: View {
    var body: some View {
        HStack {
            Text("#").frame(width: 24).font(.caption2).foregroundColor(.secondary)
            Text("Equipo").frame(maxWidth: .infinity, alignment: .leading).font(.caption2).foregroundColor(.secondary)
            Text("PJ").frame(width: 26).font(.caption2).foregroundColor(.secondary)
            Text("PG").frame(width: 26).font(.caption2).foregroundColor(.secondary)
            Text("PE").frame(width: 26).font(.caption2).foregroundColor(.secondary)
            Text("PP").frame(width: 26).font(.caption2).foregroundColor(.secondary)
            Text("GD").frame(width: 30).font(.caption2).foregroundColor(.secondary)
            Text("Pts").frame(width: 30).font(.caption2).foregroundColor(.secondary).fontWeight(.bold)
        }
        .padding(.vertical, 2)
    }
}

struct ClasificacionRow: View {
    let posicion: Int
    let fila: FilaClasificacion
    let total: Int

    var posicionColor: Color {
        if posicion <= 2 { return .green }
        if posicion >= total - 1 { return .red }
        return .primary
    }

    var body: some View {
        HStack {
            ZStack {
                if posicion <= 2 {
                    Circle().fill(Color.green.opacity(0.12)).frame(width: 26, height: 26)
                } else if posicion >= total - 1 {
                    Circle().fill(Color.red.opacity(0.12)).frame(width: 26, height: 26)
                }
                Text("\(posicion)").font(.caption).fontWeight(.semibold).foregroundColor(posicionColor)
            }
            .frame(width: 24)

            Text(fila.nombre).font(.subheadline).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
            Text("\(fila.pj)").frame(width: 26).font(.caption).foregroundColor(.secondary)
            Text("\(fila.pg)").frame(width: 26).font(.caption).foregroundColor(.secondary)
            Text("\(fila.pe)").frame(width: 26).font(.caption).foregroundColor(.secondary)
            Text("\(fila.pp)").frame(width: 26).font(.caption).foregroundColor(.secondary)
            Text(fila.dg >= 0 ? "+\(fila.dg)" : "\(fila.dg)").frame(width: 30).font(.caption).foregroundColor(.secondary)
            Text("\(fila.pts)").frame(width: 30).font(.subheadline).fontWeight(.bold)
        }
    }
}

struct GoleadoresList: View {
    let lista: [FilaGoleador]

    var body: some View {
        List {
            ForEach(Array(lista.enumerated()), id: \.element.id) { i, fila in
                HStack(spacing: 14) {
                    Text("\(i + 1)")
                        .font(.caption).foregroundColor(.secondary)
                        .frame(width: 22, alignment: .trailing)
                    InicialCircle(nombre: fila.nombre, color: .green, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(fila.nombre).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                        Text(fila.equipo).font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Text("\(fila.goles)").font(.title3).fontWeight(.bold)
                        Text("⚽").font(.subheadline)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .listStyle(.plain)
    }
}

struct JornadaChip: View {
    let label: String
    let seleccionada: Bool
    let accion: () -> Void

    var body: some View {
        Button(action: accion) {
            Text(label)
                .font(.caption).fontWeight(seleccionada ? .bold : .regular)
                .padding(.horizontal, 14).padding(.vertical, 7)
                .background(seleccionada ? Color.accentColor : Color(.systemGray5))
                .foregroundColor(seleccionada ? .white : .primary)
                .cornerRadius(20)
        }
    }
}
