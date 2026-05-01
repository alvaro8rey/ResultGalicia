import SwiftUI

// MARK: - MiEquipoView (contenedor con selector)

struct MiEquipoView: View {
    @EnvironmentObject var service: SupabaseService
    @AppStorage("miEquipoId") private var miEquipoIdString: String = ""
    @State private var showSelector = false

    var miEquipoId: UUID? { UUID(uuidString: miEquipoIdString) }

    var body: some View {
        NavigationStack {
            if let equipoId = miEquipoId {
                MiEquipoDashboard(
                    equipoId: equipoId,
                    onCambiar: { showSelector = true }
                )
            } else {
                sinEquipoView
                    .navigationTitle("Inicio")
            }
        }
        .sheet(isPresented: $showSelector) {
            SelectorEquipoSheet { equipo in
                miEquipoIdString = equipo.id.uuidString
                showSelector = false
            }
            .environmentObject(service)
        }
    }

    var sinEquipoView: some View {
        VStack(spacing: 28) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.brand.opacity(0.08))
                    .frame(width: 120, height: 120)
                Image(systemName: "sportscourt.fill")
                    .font(.system(size: 52))
                    .foregroundColor(.blue.opacity(0.4))
            }
            VStack(spacing: 10) {
                Text("Elige tu equipo")
                    .font(.title2).fontWeight(.bold)
                Text("Sigue a tu equipo favorito: resultados, clasificación y estadísticas de un vistazo.")
                    .font(.subheadline).foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            Button {
                showSelector = true
            } label: {
                Label("Seleccionar equipo", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brand)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal, 40)
            }
            Spacer()
        }
    }
}

// MARK: - Sheet selector de equipo

struct SelectorEquipoSheet: View {
    @EnvironmentObject var service: SupabaseService
    let onSelect: (Equipo) -> Void
    @State private var equipos: [Equipo] = []
    @State private var busqueda = ""
    @Environment(\.dismiss) private var dismiss

    var equiposFiltrados: [Equipo] {
        guard !busqueda.isEmpty else { return equipos }
        return equipos.filter { $0.nombre.lowercased().contains(busqueda.lowercased()) }
    }

    var body: some View {
        NavigationStack {
            List(equiposFiltrados) { equipo in
                Button {
                    onSelect(equipo)
                } label: {
                    HStack(spacing: 14) {
                        InicialCircle(nombre: equipo.nombre, color: .brand, size: 40)
                        Text(equipo.nombre)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .listStyle(.plain)
            .searchable(text: $busqueda, prompt: "Buscar equipo...")
            .navigationTitle("Elige tu equipo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .task {
                equipos = (try? await service.fetchEquipos()) ?? []
            }
        }
    }
}

// MARK: - Dashboard del equipo

struct MiEquipoDashboard: View {
    let equipoId: UUID
    let onCambiar: () -> Void

    @EnvironmentObject var service: SupabaseService
    @State private var equipo: Equipo? = nil
    @State private var partidos: [Partido] = []
    @State private var equiposMap: [UUID: Equipo] = [:]
    @State private var jugadores: [Jugador] = []
    @State private var golesEquipo: [Gol] = []
    @State private var tarjetasEquipo: [Tarjeta] = []
    @State private var alineacionesEquipo: [Alineacion] = []
    @State private var clasificacion: [FilaClasificacion] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var tabVista = "resultados"

    // MARK: Líderes

    var liderGoles: (Jugador, Int)? {
        let c = Dictionary(grouping: golesEquipo, by: \.jugadorId).mapValues { $0.count }
        guard let (id, n) = c.max(by: { $0.value < $1.value }),
              let j = jugadores.first(where: { $0.id == id }) else { return nil }
        return (j, n)
    }
    var liderMinutos: (Jugador, Int)? {
        let c = Dictionary(grouping: alineacionesEquipo, by: \.jugadorId)
            .mapValues { $0.reduce(0) { $0 + $1.minutosJugados } }
        guard let (id, n) = c.max(by: { $0.value < $1.value }),
              let j = jugadores.first(where: { $0.id == id }) else { return nil }
        return (j, n)
    }
    var liderTarjetas: (Jugador, Int)? {
        let c = Dictionary(grouping: tarjetasEquipo, by: \.jugadorId).mapValues { $0.count }
        guard let (id, n) = c.max(by: { $0.value < $1.value }),
              let j = jugadores.first(where: { $0.id == id }) else { return nil }
        return (j, n)
    }

    // Posición en la clasificación
    var posicion: Int? {
        guard let e = equipo else { return nil }
        return clasificacion.firstIndex(where: { $0.id == e.id }).map { $0 + 1 }
    }
    var filaPropia: FilaClasificacion? {
        guard let e = equipo else { return nil }
        return clasificacion.first(where: { $0.id == e.id })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if let eq = equipo {
                    cabeceraView(eq: eq)
                }

                if cargando {
                    ProgressView().padding(40)
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }.padding()
                } else {
                    VStack(spacing: 14) {
                        // Stats rápidas
                        if let fila = filaPropia {
                            statsRapidas(fila: fila)
                        }

                        // Últimos resultados (scroll horizontal)
                        ultimosResultados

                        // Selector Clasificación / Plantilla / Destacados
                        tabSelector

                        switch tabVista {
                        case "clasificacion":
                            tablaClasificacion
                        case "plantilla":
                            tablaPlantilla
                        default:
                            tablaDestacados
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Mi Equipo")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Cambiar") { onCambiar() }
                    .font(.subheadline)
            }
        }
        .task { await cargar() }
        .refreshable { await cargar() }
    }

    // MARK: Cabecera

    func cabeceraView(eq: Equipo) -> some View {
        ZStack {
            Color.brandDark

            VStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .fill(.white.opacity(0.08))
                        .frame(width: 78, height: 78)
                    Text(String(eq.nombre.prefix(2)).uppercased())
                        .font(.system(size: 28, weight: .black))
                        .foregroundColor(.white)
                }
                Text(eq.nombre)
                    .font(.title2).fontWeight(.bold).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if let pos = posicion {
                    HStack(spacing: 5) {
                        Image(systemName: "list.number")
                            .font(.caption2).foregroundColor(.white.opacity(0.5))
                        Text("\(pos)º en la clasificación")
                            .font(.caption).foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            .padding(.vertical, 28).padding(.horizontal, 20)
        }
    }

    // MARK: Stats rápidas

    func statsRapidas(fila: FilaClasificacion) -> some View {
        HStack(spacing: 8) {
            statPill(valor: "\(fila.pts)", etiqueta: "Pts", color: .brand)
            statPill(valor: "\(fila.pg)", etiqueta: "PG", color: .win)
            statPill(valor: "\(fila.pe)", etiqueta: "PE", color: .draw)
            statPill(valor: "\(fila.pp)", etiqueta: "PP", color: .loss)
            statPill(valor: fila.dg >= 0 ? "+\(fila.dg)" : "\(fila.dg)", etiqueta: "GD", color: .secondary)
        }
    }

    func statPill(valor: String, etiqueta: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.system(size: 18, weight: .bold)).monospacedDigit()
                .foregroundColor(color == .secondary ? .primary : color)
            Text(etiqueta)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }

    // MARK: Últimos resultados

    var ultimosResultados: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("ÚLTIMOS RESULTADOS")
                    .font(.system(size: 11, weight: .bold)).foregroundColor(.secondary).kerning(1)
                Spacer()
                NavigationLink(destination: EquipoDetalleView(equipo: equipo!)) {
                    Text("Ver todo").font(.caption).foregroundColor(.brand)
                }
            }
            .padding(.horizontal, 16).padding(.top, 14).padding(.bottom, 10)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(partidos.prefix(8)) { partido in
                        NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equiposMap)) {
                            resultadoCard(partido: partido)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16).padding(.bottom, 14)
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func resultadoCard(partido: Partido) -> some View {
        guard let eq = equipo else { return AnyView(EmptyView()) }
        let esLocal = partido.equipoLocalId == eq.id
        let golesEq = esLocal ? partido.golesLocal : partido.golesVisitante
        let golesRiv = esLocal ? partido.golesVisitante : partido.golesLocal
        let rival = equiposMap[esLocal ? partido.equipoVisitanteId : partido.equipoLocalId]?.nombre ?? "—"
        let (letra, acento): (String, Color) = golesEq > golesRiv ? ("V", Color.win) : golesEq < golesRiv ? ("D", Color.loss) : ("E", Color.draw)

        return AnyView(
            VStack(spacing: 0) {
                // Franja de resultado
                acento
                    .frame(height: 3)
                    .cornerRadius(1.5)

                VStack(spacing: 7) {
                    Text(letra)
                        .font(.system(size: 11, weight: .black))
                        .foregroundColor(acento)

                    Text("\(golesEq)–\(golesRiv)")
                        .font(.system(size: 18, weight: .bold)).monospacedDigit()

                    Text(rival)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(2).multilineTextAlignment(.center)
                        .frame(width: 72)

                    if let j = partido.jornada {
                        Text("J\(j)")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(.secondary.opacity(0.6))
                    }
                }
                .padding(.horizontal, 10).padding(.vertical, 10)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .cornerRadius(10)
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(acento.opacity(0.15), lineWidth: 1))
        )
    }

    // MARK: Tab selector

    var tabSelector: some View {
        Picker("", selection: $tabVista) {
            Text("Destacados").tag("destacados")
            Text("Clasificación").tag("clasificacion")
            Text("Plantilla").tag("plantilla")
        }
        .pickerStyle(.segmented)
    }

    // MARK: Clasificación

    var tablaClasificacion: some View {
        VStack(spacing: 0) {
            ClasificacionCabecera()
                .padding(.horizontal, 12).padding(.vertical, 8)
                .background(Color(.secondarySystemGroupedBackground))

            ForEach(Array(clasificacion.enumerated()), id: \.element.id) { i, fila in
                let esPropia = fila.id == equipo?.id
                ClasificacionRow(posicion: i + 1, fila: fila, total: clasificacion.count)
                    .padding(.horizontal, 12).padding(.vertical, 2)
                    .background(esPropia ? Color.brand.opacity(0.08) : Color(.secondarySystemGroupedBackground))
                    .overlay(
                        esPropia ?
                        RoundedRectangle(cornerRadius: 0)
                            .stroke(Color.brand.opacity(0.3), lineWidth: 1) : nil
                    )
                if i < clasificacion.count - 1 {
                    Divider().padding(.leading, 12)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: Plantilla

    var tablaPlantilla: some View {
        VStack(spacing: 0) {
            ForEach(jugadores) { jugador in
                NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                    HStack(spacing: 12) {
                        InicialCircle(
                            nombre: String(jugador.nombre.split(separator: ",").first ?? Substring(jugador.nombre)),
                            color: .green, size: 36
                        )
                        Text(jugador.nombre)
                            .font(.subheadline).foregroundColor(.primary).lineLimit(1)
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 16).padding(.vertical, 10)
                }
                if jugador.id != jugadores.last?.id {
                    Divider().padding(.leading, 64)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: Destacados

    var tablaDestacados: some View {
        VStack(spacing: 1) {
            if let (jug, n) = liderGoles {
                liderFila(icono: "⚽", titulo: "Máximo goleador", jugador: jug, valor: "\(n) \(n == 1 ? "gol" : "goles")")
                Divider().padding(.leading, 66)
            }
            if let (jug, n) = liderMinutos {
                liderFila(icono: "⏱️", titulo: "Más minutos", jugador: jug, valor: "\(n)'")
                Divider().padding(.leading, 66)
            }
            if let (jug, n) = liderTarjetas {
                liderFila(icono: "🟨", titulo: "Más tarjetas", jugador: jug, valor: "\(n) \(n == 1 ? "tarjeta" : "tarjetas")")
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
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
                    Text(titulo).font(.caption).foregroundColor(.secondary)
                    Text(jugador.nombre).font(.subheadline).fontWeight(.semibold).lineLimit(1)
                }
                Spacer()
                Text(valor).font(.subheadline).fontWeight(.bold)
            }
            .padding(.horizontal, 16).padding(.vertical, 12)
        }
    }

    // MARK: Carga

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let eq = service.fetchEquipo(id: equipoId)
            async let js = service.fetchJugadores(equipoId: equipoId)
            async let ps = service.fetchPartidosPorEquipo(equipoId: equipoId)
            async let gs = service.fetchGolesEquipo(equipoId: equipoId)
            async let ts = service.fetchTarjetasEquipo(equipoId: equipoId)
            async let as_ = service.fetchAlineacionesEquipo(equipoId: equipoId)

            let (eqResult, jugResult, partResult, golesResult, tarjResult, alinResult) =
                try await (eq, js, ps, gs, ts, as_)

            // Construir mapa de equipos
            var eqMap: [UUID: Equipo] = [equipoId: eqResult]
            for p in partResult {
                if eqMap[p.equipoLocalId] == nil {
                    eqMap[p.equipoLocalId] = try await service.fetchEquipo(id: p.equipoLocalId)
                }
                if eqMap[p.equipoVisitanteId] == nil {
                    eqMap[p.equipoVisitanteId] = try await service.fetchEquipo(id: p.equipoVisitanteId)
                }
            }

            // Clasificación de la competición
            var clasi: [FilaClasificacion] = []
            if let competicionId = partResult.first?.competicionId {
                let todosPartidos = try await service.fetchPartidos(competicionId: competicionId)
                let teamIds = Set(todosPartidos.flatMap { [$0.equipoLocalId, $0.equipoVisitanteId] })
                var todosEquipos: [Equipo] = []
                for tid in teamIds {
                    if let e = eqMap[tid] { todosEquipos.append(e) }
                    else {
                        let e = try await service.fetchEquipo(id: tid)
                        todosEquipos.append(e)
                        eqMap[tid] = e
                    }
                }
                clasi = calcularClasificacion(equipos: todosEquipos, partidos: todosPartidos)
            }

            await MainActor.run {
                self.equipo = eqResult
                self.jugadores = jugResult
                self.partidos = partResult
                self.equiposMap = eqMap
                self.golesEquipo = golesResult
                self.tarjetasEquipo = tarjResult
                self.alineacionesEquipo = alinResult
                self.clasificacion = clasi
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar tu equipo"
                self.cargando = false
            }
        }
    }
}
