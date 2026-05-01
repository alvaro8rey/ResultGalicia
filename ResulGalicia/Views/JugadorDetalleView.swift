import SwiftUI

struct JugadorDetalleView: View {
    let jugador: Jugador
    @EnvironmentObject var service: SupabaseService

    @State private var alineaciones: [Alineacion] = []
    @State private var goles: [Gol] = []
    @State private var tarjetas: [Tarjeta] = []
    @State private var partidos: [UUID: Partido] = [:]
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    // MARK: - Resumen por jornada

    struct JornadaResumen: Identifiable {
        let id: UUID // partidoId
        let jornada: Int
        let fecha: String
        let minutos: Int
        let esTitular: Bool
        let goles: Int
        let tarjetas: [Tarjeta]
        let oponenteNombre: String
        let resultadoLetra: String
        let resultadoColor: Color
        let marcador: String
    }

    var jornadasJugadas: [JornadaResumen] {
        alineaciones.compactMap { ali in
            guard let partido = partidos[ali.partidoId] else { return nil }
            let esLocal = partido.equipoLocalId == ali.equipoId
            let golesEq = esLocal ? partido.golesLocal : partido.golesVisitante
            let golesOp = esLocal ? partido.golesVisitante : partido.golesLocal
            let letra: String; let color: Color
            if golesEq > golesOp { letra = "V"; color = .green }
            else if golesEq < golesOp { letra = "D"; color = .red }
            else { letra = "E"; color = .orange }
            let oponenteId = esLocal ? partido.equipoVisitanteId : partido.equipoLocalId
            return JornadaResumen(
                id: ali.partidoId,
                jornada: partido.jornada ?? 0,
                fecha: partido.fecha ?? "",
                minutos: ali.minutosJugados,
                esTitular: ali.rol == "titular",
                goles: goles.filter { $0.partidoId == ali.partidoId }.count,
                tarjetas: tarjetas.filter { $0.partidoId == ali.partidoId },
                oponenteNombre: equipos[oponenteId]?.nombre ?? "—",
                resultadoLetra: letra,
                resultadoColor: color,
                marcador: "\(golesEq)–\(golesOp)"
            )
        }.sorted { $0.jornada < $1.jornada }
    }

    var minutosTotales: Int { alineaciones.reduce(0) { $0 + $1.minutosJugados } }
    var totalGoles: Int { goles.count }
    var amarillas: Int { tarjetas.filter { $0.tipo == "amarilla" }.count }
    var rojas: Int { tarjetas.filter { $0.tipo != "amarilla" }.count }
    var porcentaje: Int {
        let posibles = alineaciones.count * 90
        guard posibles > 0 else { return 0 }
        return Int(Double(minutosTotales) / Double(posibles) * 100)
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cabeceraView

                if cargando {
                    ProgressView().padding(40)
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }.padding()
                } else {
                    VStack(spacing: 14) {
                        statsGrid
                        if !jornadasJugadas.isEmpty {
                            graficaJornadas
                        }
                        if !goles.isEmpty {
                            listaGoles
                        }
                        if !tarjetas.isEmpty {
                            listaTarjetas
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Jugador")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    // MARK: - Cabecera

    var cabeceraView: some View {
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09)
            VStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(.white.opacity(0.08))
                        .frame(width: 70, height: 70)
                    Text(String(jugador.nombre.split(separator: " ").compactMap { $0.first }.prefix(2).map(String.init).joined()).uppercased().prefix(2))
                        .font(.system(size: 24, weight: .black))
                        .foregroundColor(.white)
                }
                Text(jugador.nombre)
                    .font(.title3).fontWeight(.bold).foregroundColor(.white)
                    .multilineTextAlignment(.center)
                if let equipo = equipos.values.first(where: { $0.id == jugador.equipoId }) {
                    Text(equipo.nombre)
                        .font(.caption).foregroundColor(.white.opacity(0.45))
                }
            }
            .padding(.vertical, 26)
        }
    }

    // MARK: - Stats grid

    var statsGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
            StatBox(valor: "\(alineaciones.count)", etiqueta: "Partidos")
            StatBox(valor: "\(totalGoles)", etiqueta: "Goles")
            StatBox(valor: "\(minutosTotales)'", etiqueta: "Minutos")
            StatBox(valor: "\(porcentaje)%", etiqueta: "% Jugado")
            StatBox(valor: "\(amarillas)", etiqueta: "🟨 Amarillas")
            StatBox(valor: "\(rojas)", etiqueta: "🟥 Rojas")
        }
    }

    // MARK: - Gráfica por jornada

    var graficaJornadas: some View {
        VStack(alignment: .leading, spacing: 0) {
            seccionHeader("RENDIMIENTO POR JORNADA")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .bottom, spacing: 6) {
                    ForEach(jornadasJugadas) { j in
                        columnaJornada(j)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 28)   // espacio para el ⚽ encima
                .padding(.bottom, 12)
            }

            // Leyenda
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.7)).frame(width: 12, height: 12)
                    Text("Titular").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 2).fill(Color.blue.opacity(0.3)).frame(width: 12, height: 12)
                    Text("Suplente").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    Text("⚽").font(.caption2)
                    Text("Gol").font(.caption2).foregroundColor(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(Color.yellow).frame(width: 7, height: 10)
                    Text("Tarjeta").font(.caption2).foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func columnaJornada(_ j: JornadaResumen) -> some View {
        let alturaMax: CGFloat = 60
        let alturaBarra = max(4, CGFloat(j.minutos) / 90.0 * alturaMax)
        let colorBarra: Color = j.esTitular ? .blue.opacity(0.75) : .blue.opacity(0.3)

        return VStack(spacing: 4) {
            // Icono gol encima de la barra
            if j.goles > 0 {
                Text(j.goles > 1 ? "⚽\(j.goles)" : "⚽")
                    .font(.system(size: 11))
                    .offset(y: 2)
            } else {
                Color.clear.frame(height: 16)
            }

            // Barra de minutos
            ZStack(alignment: .bottom) {
                // Fondo (los 90 min)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(.tertiarySystemFill))
                    .frame(width: 28, height: alturaMax)

                // Minutos reales
                RoundedRectangle(cornerRadius: 4)
                    .fill(colorBarra)
                    .frame(width: 28, height: alturaBarra)

                // Tarjeta encima de la barra (superpuesta)
                if !j.tarjetas.isEmpty {
                    let tieneRoja = j.tarjetas.contains { $0.tipo != "amarilla" }
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tieneRoja ? Color.red : Color.yellow)
                        .frame(width: 8, height: 12)
                        .offset(x: 10, y: -4)
                }
            }
            .frame(width: 28, height: alturaMax)

            // Etiqueta jornada
            Text(j.jornada > 0 ? "J\(j.jornada)" : "–")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(.secondary)

            // Badge resultado
            Text(j.resultadoLetra)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 16, height: 16)
                .background(j.resultadoColor)
                .cornerRadius(3)
        }
        .frame(width: 34)
    }

    // MARK: - Lista goles

    var listaGoles: some View {
        VStack(alignment: .leading, spacing: 0) {
            seccionHeader("⚽  GOLES")
            VStack(spacing: 0) {
                ForEach(goles) { gol in
                    if let partido = partidos[gol.partidoId] {
                        let esLocal = partido.equipoLocalId == (alineaciones.first(where: { $0.partidoId == gol.partidoId })?.equipoId)
                        let oponenteId = esLocal == true ? partido.equipoVisitanteId : partido.equipoLocalId
                        let rival = equipos[oponenteId]?.nombre ?? "—"
                        HStack(spacing: 14) {
                            Text("⚽")
                                .font(.title3)
                                .frame(width: 36, height: 36)
                                .background(Color(.tertiarySystemFill))
                                .cornerRadius(10)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("vs. \(rival)")
                                    .font(.subheadline).fontWeight(.semibold)
                                HStack(spacing: 8) {
                                    if let jornada = partido.jornada {
                                        Text("Jornada \(jornada)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Text("·").font(.caption).foregroundColor(.secondary)
                                    Text("Min. \(gol.minuto ?? 0)")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                            if let marcador = gol.marcador, !marcador.isEmpty {
                                Text(marcador)
                                    .font(.caption).fontWeight(.bold)
                                    .padding(.horizontal, 8).padding(.vertical, 4)
                                    .background(Color(.tertiarySystemFill))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        if gol.id != goles.last?.id {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: - Lista tarjetas

    var listaTarjetas: some View {
        VStack(alignment: .leading, spacing: 0) {
            seccionHeader("TARJETAS")
            VStack(spacing: 0) {
                ForEach(tarjetas) { tarjeta in
                    if let partido = partidos[tarjeta.partidoId] {
                        let esLocal = partido.equipoLocalId == (alineaciones.first(where: { $0.partidoId == tarjeta.partidoId })?.equipoId)
                        let oponenteId = esLocal == true ? partido.equipoVisitanteId : partido.equipoLocalId
                        let rival = equipos[oponenteId]?.nombre ?? "—"
                        let esRoja = tarjeta.tipo != "amarilla"
                        HStack(spacing: 14) {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(esRoja ? Color.red : Color.yellow)
                                .frame(width: 22, height: 32)
                                .padding(.horizontal, 7)
                            VStack(alignment: .leading, spacing: 3) {
                                Text("vs. \(rival)")
                                    .font(.subheadline).fontWeight(.semibold)
                                HStack(spacing: 8) {
                                    if let jornada = partido.jornada {
                                        Text("Jornada \(jornada)")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
                                    Text("·").font(.caption).foregroundColor(.secondary)
                                    Text("Min. \(tarjeta.minuto ?? 0)")
                                        .font(.caption).foregroundColor(.secondary)
                                    Text("·").font(.caption).foregroundColor(.secondary)
                                    Text(tarjeta.tipo == "amarilla" ? "Amarilla" : tarjeta.tipo == "doble_amarilla" ? "2ª amarilla" : "Roja")
                                        .font(.caption).foregroundColor(.secondary)
                                }
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        if tarjeta.id != tarjetas.last?.id {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    // MARK: - Helper views

    func seccionHeader(_ titulo: String) -> some View {
        Text(titulo)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .kerning(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
    }

    // MARK: - Carga

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let a = service.fetchAlineacionesJugador(jugadorId: jugador.id)
            async let g = service.fetchGolesJugador(jugadorId: jugador.id)
            async let t = service.fetchTarjetasJugador(jugadorId: jugador.id)
            let (as_, gs, ts) = try await (a, g, t)

            var ps: [UUID: Partido] = [:]
            let partidoIds = Set(as_.map { $0.partidoId } + gs.map { $0.partidoId } + ts.map { $0.partidoId })
            for id in partidoIds {
                ps[id] = try await service.fetchPartido(id: id)
            }

            var eqs: [UUID: Equipo] = [:]
            for (_, partido) in ps {
                if eqs[partido.equipoLocalId] == nil {
                    eqs[partido.equipoLocalId] = try await service.fetchEquipo(id: partido.equipoLocalId)
                }
                if eqs[partido.equipoVisitanteId] == nil {
                    eqs[partido.equipoVisitanteId] = try await service.fetchEquipo(id: partido.equipoVisitanteId)
                }
            }

            await MainActor.run {
                self.alineaciones = as_
                self.goles = gs
                self.tarjetas = ts
                self.partidos = ps
                self.equipos = eqs
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar el jugador"
                self.cargando = false
            }
        }
    }
}

// MARK: - StatBox

struct StatBox: View {
    let valor: String
    let etiqueta: String

    var body: some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.system(size: 17, weight: .bold)).monospacedDigit()
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(etiqueta)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14).padding(.horizontal, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(10)
    }
}
