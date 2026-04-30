import SwiftUI

struct PartidoDetalleView: View {
    let partido: Partido
    let equipos: [UUID: Equipo]

    @EnvironmentObject var service: SupabaseService
    @State private var goles: [Gol] = []
    @State private var tarjetas: [Tarjeta] = []
    @State private var sustituciones: [Sustitucion] = []
    @State private var alineaciones: [Alineacion] = []
    @State private var jugadores: [UUID: Jugador] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    var equipoLocal: Equipo? { equipos[partido.equipoLocalId] }
    var equipoVisitante: Equipo? { equipos[partido.equipoVisitanteId] }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                marcadorView

                if cargando {
                    ProgressView().padding(.top, 32)
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    if !goles.isEmpty { seccionGoles }
                    if !tarjetas.isEmpty { seccionTarjetas }
                    if !sustituciones.isEmpty { seccionSustituciones }
                    seccionAlineaciones
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Partido")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    // MARK: - Marcador

    var marcadorView: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.75), Color.blue.opacity(0.45)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .cornerRadius(16)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    Text(equipoLocal?.nombre ?? "—")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)

                    Text("\(partido.golesLocal) – \(partido.golesVisitante)")
                        .font(.system(size: 38, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                        .monospacedDigit()
                        .padding(.horizontal, 14)

                    Text(equipoVisitante?.nombre ?? "—")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                HStack(spacing: 16) {
                    if let fecha = partido.fecha {
                        Label(fecha, systemImage: "calendar")
                    }
                    if let estadio = partido.estadio {
                        Label(estadio, systemImage: "mappin")
                    }
                }
                .font(.caption)
                .foregroundColor(.white.opacity(0.85))

                if let arbitro = partido.arbitro {
                    Text("Árbitro: \(arbitro)")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
        }
        .padding(.top, 8)
    }

    // MARK: - Goles

    var seccionGoles: some View {
        InfoCard(titulo: "⚽ Goles") {
            VStack(spacing: 10) {
                ForEach(goles) { gol in
                    HStack {
                        if gol.equipoId == partido.equipoLocalId {
                            jugadorLink(id: gol.jugadorId, alineacion: .leading)
                            Spacer()
                            Text("\(gol.minuto ?? 0)'")
                                .font(.caption).foregroundColor(.secondary)
                                .monospacedDigit()
                        } else {
                            Text("\(gol.minuto ?? 0)'")
                                .font(.caption).foregroundColor(.secondary)
                                .monospacedDigit()
                            Spacer()
                            jugadorLink(id: gol.jugadorId, alineacion: .trailing)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tarjetas

    var seccionTarjetas: some View {
        InfoCard(titulo: "Tarjetas") {
            VStack(spacing: 10) {
                ForEach(tarjetas) { tarjeta in
                    HStack(spacing: 10) {
                        tarjetaIcon(tipo: tarjeta.tipo)
                        jugadorLink(id: tarjeta.jugadorId, alineacion: .leading)
                        Spacer()
                        Text(tarjeta.tipo == "amarilla" ? "Amarilla" : tarjeta.tipo == "doble_amarilla" ? "2ª amarilla" : "Roja")
                            .font(.caption).foregroundColor(.secondary)
                        Text("\(tarjeta.minuto ?? 0)'")
                            .font(.caption).foregroundColor(.secondary).monospacedDigit()
                    }
                }
            }
        }
    }

    func tarjetaIcon(tipo: String) -> some View {
        let color: Color = tipo == "amarilla" ? .yellow : .red
        return RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 10, height: 14)
    }

    // MARK: - Sustituciones

    var seccionSustituciones: some View {
        InfoCard(titulo: "Sustituciones") {
            VStack(spacing: 10) {
                ForEach(sustituciones) { s in
                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.up.circle.fill")
                                    .foregroundColor(.green).font(.caption)
                                jugadorLink(id: s.jugadorEntraId, alineacion: .leading)
                            }
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .foregroundColor(.red).font(.caption)
                                jugadorLink(id: s.jugadorSaleId, alineacion: .leading)
                            }
                        }
                        Spacer()
                        Text("\(s.minuto ?? 0)'")
                            .font(.caption).foregroundColor(.secondary)
                            .monospacedDigit().padding(.top, 2)
                    }
                }
            }
        }
    }

    // MARK: - Alineaciones

    var seccionAlineaciones: some View {
        InfoCard(titulo: "Alineaciones") {
            HStack(alignment: .top, spacing: 16) {
                alineacionColumna(equipoId: partido.equipoLocalId)
                Divider()
                alineacionColumna(equipoId: partido.equipoVisitanteId)
            }
        }
    }

    func alineacionColumna(equipoId: UUID) -> some View {
        let titulares = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "titular" }
        let suplentes = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "suplente" }
        return VStack(alignment: .leading, spacing: 6) {
            Text(equipos[equipoId]?.nombre ?? "")
                .font(.caption).fontWeight(.bold).lineLimit(1)

            if !titulares.isEmpty {
                Text("Titulares")
                    .font(.caption2).foregroundColor(.secondary)
                    .padding(.top, 2)
                ForEach(titulares) { a in
                    jugadorLink(id: a.jugadorId, alineacion: .leading)
                        .font(.caption)
                }
            }
            if !suplentes.isEmpty {
                Text("Suplentes")
                    .font(.caption2).foregroundColor(.secondary)
                    .padding(.top, 6)
                ForEach(suplentes) { a in
                    jugadorLink(id: a.jugadorId, alineacion: .leading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    func jugadorLink(id: UUID, alineacion: HorizontalAlignment) -> some View {
        if let jugador = jugadores[id] {
            NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                Text(jugador.nombre)
                    .multilineTextAlignment(alineacion == .leading ? .leading : .trailing)
            }
        } else {
            Text("—").foregroundColor(.secondary)
        }
    }

    // MARK: - Carga

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let g = service.fetchGoles(partidoId: partido.id)
            async let t = service.fetchTarjetas(partidoId: partido.id)
            async let s = service.fetchSustituciones(partidoId: partido.id)
            async let a = service.fetchAlineaciones(partidoId: partido.id)

            let (gs, ts, ss, as_) = try await (g, t, s, a)

            var jugs: [UUID: Jugador] = [:]
            let ids = Set(
                gs.map { $0.jugadorId } +
                ts.map { $0.jugadorId } +
                ss.map { $0.jugadorSaleId } + ss.map { $0.jugadorEntraId } +
                as_.map { $0.jugadorId }
            )
            for id in ids {
                jugs[id] = try await service.fetchJugador(id: id)
            }

            await MainActor.run {
                self.goles = gs
                self.tarjetas = ts
                self.sustituciones = ss
                self.alineaciones = as_
                self.jugadores = jugs
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar el partido"
                self.cargando = false
            }
        }
    }
}

// MARK: - InfoCard

struct InfoCard<Content: View>: View {
    let titulo: String
    @ViewBuilder let contenido: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo)
                .font(.headline)
                .fontWeight(.semibold)
            contenido
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
