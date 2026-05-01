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
    @State private var golesEquipo: [Gol] = []
    @State private var tarjetasEquipo: [Tarjeta] = []
    @State private var alineacionesEquipo: [Alineacion] = []
    @State private var clasificacion: [FilaClasificacion] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var tabVista = "partidos"

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

    // MARK: - Líderes del equipo

    struct LiderStat {
        let jugador: Jugador
        let valor: Int
        let etiqueta: String
    }

    var liderGoles: LiderStat? {
        let conteo = Dictionary(grouping: golesEquipo, by: \.jugadorId)
            .mapValues { $0.count }
        guard let (jugId, total) = conteo.max(by: { $0.value < $1.value }),
              let jug = jugadores.first(where: { $0.id == jugId }) else { return nil }
        return LiderStat(jugador: jug, valor: total, etiqueta: total == 1 ? "gol" : "goles")
    }

    var liderTarjetas: LiderStat? {
        let conteo = Dictionary(grouping: tarjetasEquipo, by: \.jugadorId)
            .mapValues { $0.count }
        guard let (jugId, total) = conteo.max(by: { $0.value < $1.value }),
              let jug = jugadores.first(where: { $0.id == jugId }) else { return nil }
        return LiderStat(jugador: jug, valor: total, etiqueta: total == 1 ? "tarjeta" : "tarjetas")
    }

    var liderMinutos: LiderStat? {
        let minutos = Dictionary(grouping: alineacionesEquipo, by: \.jugadorId)
            .mapValues { $0.reduce(0) { $0 + $1.minutosJugados } }
        guard let (jugId, total) = minutos.max(by: { $0.value < $1.value }),
              let jug = jugadores.first(where: { $0.id == jugId }) else { return nil }
        return LiderStat(jugador: jug, valor: total, etiqueta: "min")
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Cabecera
                ZStack {
                    Color(red: 0.06, green: 0.06, blue: 0.09)
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 18)
                                .fill(.white.opacity(0.08))
                                .frame(width: 72, height: 72)
                            Text(String(equipo.nombre.prefix(2)).uppercased())
                                .font(.system(size: 26, weight: .black))
                                .foregroundColor(.white)
                        }
                        Text(equipo.nombre)
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.vertical, 26).padding(.horizontal, 20)
                }
                .frame(maxWidth: .infinity)
                .cornerRadius(16)

                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    // Líderes del equipo
                    if liderGoles != nil || liderMinutos != nil || liderTarjetas != nil {
                        lideresSección
                    }

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

                    // Tab selector
                    Picker("", selection: $tabVista) {
                        Text("Partidos").tag("partidos")
                        Text("Clasificación").tag("clasificacion")
                        Text("Plantilla").tag("plantilla")
                    }
                    .pickerStyle(.segmented)

                    if tabVista == "clasificacion" {
                        // Clasificación inline
                        VStack(spacing: 0) {
                            ClasificacionCabecera()
                                .padding(.horizontal, 12).padding(.vertical, 8)
                                .background(Color(.secondarySystemGroupedBackground))
                            ForEach(Array(clasificacion.enumerated()), id: \.element.id) { i, fila in
                                let esPropia = fila.id == equipo.id
                                ClasificacionRow(posicion: i + 1, fila: fila, total: clasificacion.count)
                                    .padding(.horizontal, 12).padding(.vertical, 2)
                                    .background(esPropia ? Color.blue.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                                if i < clasificacion.count - 1 {
                                    Divider().padding(.leading, 12)
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    } else if tabVista == "plantilla" {
                        // Plantilla
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
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
                    } else {
                        // Partidos
                        VStack(spacing: 0) {
                            ForEach(partidos.prefix(10)) { partido in
                                NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
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
                                }
                                if partido.id != partidos.prefix(10).last?.id {
                                    Divider()
                                }
                            }
                        }
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(14)
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

    var lideresSección: some View {
        VStack(spacing: 0) {
            Text("DESTACADOS")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

            VStack(spacing: 1) {
                if let l = liderGoles {
                    liderFila(
                        icono: "⚽",
                        titulo: "Máximo goleador",
                        jugador: l.jugador,
                        valor: "\(l.valor) \(l.etiqueta)"
                    )
                    Divider().padding(.leading, 56)
                }
                if let l = liderMinutos {
                    liderFila(
                        icono: "⏱️",
                        titulo: "Más minutos",
                        jugador: l.jugador,
                        valor: "\(l.valor)'"
                    )
                    Divider().padding(.leading, 56)
                }
                if let l = liderTarjetas {
                    liderFila(
                        icono: "🟨",
                        titulo: "Más tarjetas",
                        jugador: l.jugador,
                        valor: "\(l.valor) \(l.etiqueta)"
                    )
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(14)
        }
    }

    func liderFila(icono: String, titulo: String, jugador: Jugador, valor: String) -> some View {
        NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
            HStack(spacing: 14) {
                Text(icono)
                    .font(.title3)
                    .frame(width: 36, height: 36)
                    .background(Color(.tertiarySystemFill))
                    .cornerRadius(10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(titulo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(jugador.nombre)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                }

                Spacer()

                Text(valor)
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
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
            async let g = service.fetchGolesEquipo(equipoId: equipo.id)
            async let t = service.fetchTarjetasEquipo(equipoId: equipo.id)
            async let a = service.fetchAlineacionesEquipo(equipoId: equipo.id)
            let (js, ps, gs, ts, as_) = try await (j, p, g, t, a)

            var eq: [UUID: Equipo] = [equipo.id: equipo]
            for partido in ps {
                if eq[partido.equipoLocalId] == nil {
                    eq[partido.equipoLocalId] = try await service.fetchEquipo(id: partido.equipoLocalId)
                }
                if eq[partido.equipoVisitanteId] == nil {
                    eq[partido.equipoVisitanteId] = try await service.fetchEquipo(id: partido.equipoVisitanteId)
                }
            }

            // Clasificación de la competición
            var clasi: [FilaClasificacion] = []
            if let competicionId = ps.first?.competicionId {
                let todosPartidos = try await service.fetchPartidos(competicionId: competicionId)
                let teamIds = Set(todosPartidos.flatMap { [$0.equipoLocalId, $0.equipoVisitanteId] })
                var todosEquipos: [Equipo] = []
                for tid in teamIds {
                    if let e = eq[tid] { todosEquipos.append(e) }
                    else {
                        let e = try await service.fetchEquipo(id: tid)
                        todosEquipos.append(e)
                        eq[tid] = e
                    }
                }
                clasi = calcularClasificacion(equipos: todosEquipos, partidos: todosPartidos)
            }

            await MainActor.run {
                self.jugadores = js
                self.partidos = ps
                self.equipos = eq
                self.golesEquipo = gs
                self.tarjetasEquipo = ts
                self.alineacionesEquipo = as_
                self.clasificacion = clasi
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
