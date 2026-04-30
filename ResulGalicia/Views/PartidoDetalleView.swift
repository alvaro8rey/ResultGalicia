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

    // MARK: - Evento unificado

    struct Evento: Identifiable {
        let id = UUID()
        let minuto: Int
        let tipo: TipoEvento
        let nombrePrincipal: String
        let nombreSecundario: String?
        let esLocal: Bool
        var jugadorId: UUID?
        var jugadorSecundarioId: UUID?
    }

    enum TipoEvento {
        case gol, amarilla, roja, dobleAmarilla, sustitucion

        var icono: String {
            switch self {
            case .gol: return "⚽"
            case .amarilla: return "🟨"
            case .roja: return "🟥"
            case .dobleAmarilla: return "🟨🟥"
            case .sustitucion: return "🔄"
            }
        }
    }

    var eventos: [Evento] {
        var lista: [Evento] = []

        for g in goles {
            lista.append(Evento(
                minuto: g.minuto ?? 0,
                tipo: .gol,
                nombrePrincipal: jugadores[g.jugadorId]?.nombre ?? "—",
                nombreSecundario: nil,
                esLocal: g.equipoId == partido.equipoLocalId,
                jugadorId: g.jugadorId
            ))
        }
        for t in tarjetas {
            let tipo: TipoEvento = t.tipo == "amarilla" ? .amarilla : t.tipo == "doble_amarilla" ? .dobleAmarilla : .roja
            lista.append(Evento(
                minuto: t.minuto ?? 0,
                tipo: tipo,
                nombrePrincipal: jugadores[t.jugadorId]?.nombre ?? "—",
                nombreSecundario: nil,
                esLocal: t.equipoId == partido.equipoLocalId,
                jugadorId: t.jugadorId
            ))
        }
        for s in sustituciones {
            lista.append(Evento(
                minuto: s.minuto ?? 0,
                tipo: .sustitucion,
                nombrePrincipal: jugadores[s.jugadorEntraId]?.nombre ?? "—",
                nombreSecundario: jugadores[s.jugadorSaleId]?.nombre ?? "—",
                esLocal: s.equipoId == partido.equipoLocalId,
                jugadorId: s.jugadorEntraId,
                jugadorSecundarioId: s.jugadorSaleId
            ))
        }

        return lista.sorted { $0.minuto < $1.minuto }
    }

    // MARK: - Body

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                marcadorView

                if cargando {
                    ProgressView().padding(40)
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }.padding()
                } else {
                    VStack(spacing: 0) {
                        if !eventos.isEmpty {
                            timelineView
                        }
                        alineacionesView
                    }
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    // MARK: - Marcador

    var marcadorView: some View {
        ZStack(alignment: .bottom) {
            LinearGradient(
                colors: [Color(red: 0.08, green: 0.18, blue: 0.52), Color(red: 0.15, green: 0.35, blue: 0.75)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )

            VStack(spacing: 0) {
                // Equipos y marcador
                HStack(alignment: .center, spacing: 0) {
                    // Local
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(.white.opacity(0.15)).frame(width: 64, height: 64)
                            Text(String((equipoLocal?.nombre ?? "—").prefix(2)).uppercased())
                                .font(.title2).fontWeight(.black).foregroundColor(.white)
                        }
                        Text(equipoLocal?.nombre ?? "—")
                            .font(.footnote).fontWeight(.semibold).foregroundColor(.white)
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)

                    // Score
                    VStack(spacing: 6) {
                        Text("\(partido.golesLocal) – \(partido.golesVisitante)")
                            .font(.system(size: 46, weight: .black, design: .rounded))
                            .foregroundColor(.white).monospacedDigit()
                        Text("FINAL")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white.opacity(0.6))
                            .kerning(2)
                    }
                    .frame(minWidth: 110)

                    // Visitante
                    VStack(spacing: 10) {
                        ZStack {
                            Circle().fill(.white.opacity(0.15)).frame(width: 64, height: 64)
                            Text(String((equipoVisitante?.nombre ?? "—").prefix(2)).uppercased())
                                .font(.title2).fontWeight(.black).foregroundColor(.white)
                        }
                        Text(equipoVisitante?.nombre ?? "—")
                            .font(.footnote).fontWeight(.semibold).foregroundColor(.white)
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 28)
                .padding(.horizontal, 12)

                // Metadatos
                HStack(spacing: 20) {
                    if let fecha = partido.fecha {
                        Label(formatearFecha(fecha), systemImage: "calendar")
                    }
                    if let estadio = partido.estadio {
                        Label(estadio, systemImage: "location.fill")
                    }
                }
                .font(.caption2)
                .foregroundColor(.white.opacity(0.75))
                .padding(.top, 14)

                if let arbitro = partido.arbitro {
                    Text("Árbitro · \(arbitro)")
                        .font(.caption2).foregroundColor(.white.opacity(0.5))
                        .padding(.top, 4)
                }

                Spacer().frame(height: 24)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Timeline

    var timelineView: some View {
        VStack(spacing: 0) {
            seccionHeader("EVENTOS DEL PARTIDO")

            ForEach(eventos) { evento in
                EventoTimeline(
                    evento: evento,
                    jugadores: jugadores,
                    localId: partido.equipoLocalId
                )
                .contentShape(Rectangle())
                if evento.id != eventos.last?.id {
                    Divider().padding(.horizontal, 16)
                }
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .padding(.bottom, 12)
    }

    // MARK: - Alineaciones

    var alineacionesView: some View {
        VStack(spacing: 0) {
            seccionHeader("ALINEACIONES")

            HStack(alignment: .top, spacing: 0) {
                alineacionColumna(equipoId: partido.equipoLocalId)
                Divider()
                alineacionColumna(equipoId: partido.equipoVisitanteId)
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.secondarySystemGroupedBackground))
    }

    func alineacionColumna(equipoId: UUID) -> some View {
        let titulares = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "titular" }
        let suplentes = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "suplente" }
        let esLocal = equipoId == partido.equipoLocalId

        return VStack(alignment: esLocal ? .leading : .trailing, spacing: 0) {
            // Nombre del equipo
            Text(equipos[equipoId]?.nombre ?? "")
                .font(.caption).fontWeight(.bold).lineLimit(1)
                .frame(maxWidth: .infinity, alignment: esLocal ? .leading : .trailing)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.tertiarySystemFill))

            if !titulares.isEmpty {
                Text("Once inicial").font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: esLocal ? .leading : .trailing)
                    .padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 4)

                ForEach(titulares) { a in
                    jugadorAlineacionFila(id: a.jugadorId, esLocal: esLocal)
                }
            }

            if !suplentes.isEmpty {
                Text("Suplentes").font(.caption2).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: esLocal ? .leading : .trailing)
                    .padding(.horizontal, 14).padding(.top, 12).padding(.bottom, 4)

                ForEach(suplentes) { a in
                    jugadorAlineacionFila(id: a.jugadorId, esLocal: esLocal, atenuado: true)
                }
            }

            Spacer(minLength: 14)
        }
        .frame(maxWidth: .infinity)
    }

    func jugadorAlineacionFila(id: UUID, esLocal: Bool, atenuado: Bool = false) -> some View {
        let nombre = jugadores[id]?.nombre ?? "—"
        return Group {
            if let jugador = jugadores[id] {
                NavigationLink(destination: JugadorDetalleView(jugador: jugador)) {
                    Text(nombre)
                        .font(.caption)
                        .foregroundColor(atenuado ? .secondary : .primary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: esLocal ? .leading : .trailing)
                        .padding(.horizontal, 14).padding(.vertical, 5)
                }
            } else {
                Text(nombre)
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: esLocal ? .leading : .trailing)
                    .padding(.horizontal, 14).padding(.vertical, 5)
            }
        }
    }

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

// MARK: - Fila de evento timeline (estilo Sofascore)

struct EventoTimeline: View {
    let evento: PartidoDetalleView.Evento
    let jugadores: [UUID: Jugador]
    let localId: UUID

    var body: some View {
        HStack(spacing: 0) {
            // Lado local (derecha)
            Group {
                if evento.esLocal {
                    contenidoEvento(alineacion: .trailing)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)

            // Minuto centro
            VStack(spacing: 2) {
                Text("\(evento.minuto)'")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.secondary).monospacedDigit()
                Text(evento.tipo.icono)
                    .font(.system(size: 13))
            }
            .frame(width: 48)
            .padding(.vertical, 12)

            // Lado visitante (izquierda)
            Group {
                if !evento.esLocal {
                    contenidoEvento(alineacion: .leading)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 12)
    }

    @ViewBuilder
    func contenidoEvento(alineacion: HorizontalAlignment) -> some View {
        let trailing = alineacion == .trailing

        VStack(alignment: alineacion, spacing: 3) {
            if evento.tipo == .sustitucion {
                HStack(spacing: 4) {
                    if trailing {
                        Text(evento.nombrePrincipal)
                            .font(.subheadline).lineLimit(1)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption).foregroundColor(.green)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption).foregroundColor(.green)
                        Text(evento.nombrePrincipal)
                            .font(.subheadline).lineLimit(1)
                    }
                }
                HStack(spacing: 4) {
                    if trailing {
                        Text(evento.nombreSecundario ?? "")
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption).foregroundColor(.red)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption).foregroundColor(.red)
                        Text(evento.nombreSecundario ?? "")
                            .font(.caption).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            } else {
                Text(evento.nombrePrincipal)
                    .font(.subheadline).fontWeight(.medium).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 6)
    }
}

// MARK: - InfoCard (para otras vistas)

struct InfoCard<Content: View>: View {
    let titulo: String
    @ViewBuilder let contenido: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(titulo).font(.headline).fontWeight(.semibold)
            contenido
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
