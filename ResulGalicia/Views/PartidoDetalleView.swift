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
        ZStack {
            Color(red: 0.06, green: 0.06, blue: 0.09)

            VStack(spacing: 0) {
                // Estado
                Text("FINAL")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
                    .kerning(2.5)
                    .padding(.top, 22)

                // Equipos y marcador
                HStack(alignment: .center, spacing: 0) {
                    // Local
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.white.opacity(0.07))
                                .frame(width: 62, height: 62)
                            Text(String((equipoLocal?.nombre ?? "—").prefix(2)).uppercased())
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                        }
                        Text(equipoLocal?.nombre ?? "—")
                            .font(.caption).fontWeight(.medium).foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)

                    // Score
                    HStack(alignment: .center, spacing: 6) {
                        Text("\(partido.golesLocal)")
                            .font(.system(size: 52, weight: .black))
                            .foregroundColor(.white).monospacedDigit()
                        Text("–")
                            .font(.system(size: 28, weight: .thin))
                            .foregroundColor(.white.opacity(0.35))
                        Text("\(partido.golesVisitante)")
                            .font(.system(size: 52, weight: .black))
                            .foregroundColor(.white).monospacedDigit()
                    }
                    .frame(minWidth: 120)

                    // Visitante
                    VStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 14)
                                .fill(.white.opacity(0.07))
                                .frame(width: 62, height: 62)
                            Text(String((equipoVisitante?.nombre ?? "—").prefix(2)).uppercased())
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(.white)
                        }
                        Text(equipoVisitante?.nombre ?? "—")
                            .font(.caption).fontWeight(.medium).foregroundColor(.white.opacity(0.85))
                            .multilineTextAlignment(.center).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 16)
                .padding(.horizontal, 12)

                // Separador
                Rectangle()
                    .fill(.white.opacity(0.07))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                // Metadatos
                HStack(spacing: 18) {
                    if let fecha = partido.fecha {
                        Label(formatearFecha(fecha), systemImage: "calendar")
                            .font(.caption2).foregroundColor(.white.opacity(0.45))
                    }
                    if let estadio = partido.estadio {
                        Label(estadio, systemImage: "mappin")
                            .font(.caption2).foregroundColor(.white.opacity(0.45))
                    }
                }
                .padding(.top, 12)

                if let arbitro = partido.arbitro {
                    Text("Árbitro · \(arbitro)")
                        .font(.caption2).foregroundColor(.white.opacity(0.3))
                        .padding(.top, 4)
                }

                Spacer().frame(height: 20)
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
        let nombre = nombreCorto(jugadores[id]?.nombre ?? "—")
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

// MARK: - Formato de nombre corto

func nombreCorto(_ nombre: String) -> String {
    guard !nombre.isEmpty, nombre != "—" else { return nombre }
    if nombre.contains(",") {
        let partes = nombre.components(separatedBy: ",")
        let apellido = partes[0].trimmingCharacters(in: .whitespaces)
        let prenom = partes.count > 1 ? partes[1].trimmingCharacters(in: .whitespaces) : ""
        let primerNombre = prenom.components(separatedBy: " ").first(where: { !$0.isEmpty }) ?? prenom
        let formatted = primerNombre.prefix(1).uppercased() + primerNombre.dropFirst().lowercased()
        let inicial = String(apellido.prefix(1)).uppercased()
        return inicial.isEmpty ? formatted : "\(formatted) \(inicial)."
    }
    let palabras = nombre.components(separatedBy: " ").filter { !$0.isEmpty }
    if palabras.count >= 2 {
        let first = palabras[0].prefix(1).uppercased() + palabras[0].dropFirst().lowercased()
        let initial = String(palabras[1].prefix(1)).uppercased()
        return "\(first) \(initial)."
    }
    return nombre.prefix(1).uppercased() + nombre.dropFirst().lowercased()
}

// MARK: - Fila de evento timeline

struct EventoTimeline: View {
    let evento: PartidoDetalleView.Evento
    let jugadores: [UUID: Jugador]
    let localId: UUID

    var body: some View {
        HStack(spacing: 0) {
            // Lado local (derecha)
            Group {
                if evento.esLocal {
                    contenidoEvento(trailing: true)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)

            // Centro: minuto + icono
            VStack(spacing: 5) {
                Text("\(evento.minuto)'")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                iconoEvento
            }
            .frame(width: 52)
            .padding(.vertical, 16)

            // Lado visitante (izquierda)
            Group {
                if !evento.esLocal {
                    contenidoEvento(trailing: false)
                } else {
                    Color.clear
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
    }

    @ViewBuilder
    var iconoEvento: some View {
        switch evento.tipo {
        case .gol:
            Text("⚽").font(.system(size: 15))
        case .amarilla:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.yellow)
                .frame(width: 11, height: 16)
        case .roja:
            RoundedRectangle(cornerRadius: 2)
                .fill(Color.red)
                .frame(width: 11, height: 16)
        case .dobleAmarilla:
            ZStack {
                RoundedRectangle(cornerRadius: 2).fill(Color.yellow)
                    .frame(width: 11, height: 16).offset(x: -3, y: -2)
                RoundedRectangle(cornerRadius: 2).fill(Color.red)
                    .frame(width: 11, height: 16).offset(x: 3, y: 2)
            }
            .frame(width: 20, height: 22)
        case .sustitucion:
            Image(systemName: "arrow.up.arrow.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.blue)
        }
    }

    @ViewBuilder
    func contenidoEvento(trailing: Bool) -> some View {
        VStack(alignment: trailing ? .trailing : .leading, spacing: 5) {
            if evento.tipo == .sustitucion {
                HStack(spacing: 5) {
                    if trailing {
                        Text(nombreCorto(evento.nombrePrincipal))
                            .font(.system(size: 13, weight: .medium)).lineLimit(1)
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.green)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.green)
                        Text(nombreCorto(evento.nombrePrincipal))
                            .font(.system(size: 13, weight: .medium)).lineLimit(1)
                    }
                }
                HStack(spacing: 5) {
                    if trailing {
                        Text(nombreCorto(evento.nombreSecundario ?? ""))
                            .font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.red)
                    } else {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 12)).foregroundColor(.red)
                        Text(nombreCorto(evento.nombreSecundario ?? ""))
                            .font(.system(size: 12)).foregroundColor(.secondary).lineLimit(1)
                    }
                }
            } else {
                Text(nombreCorto(evento.nombrePrincipal))
                    .font(.system(size: 14, weight: .semibold)).lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: trailing ? .trailing : .leading)
        .padding(.vertical, 16)
        .padding(.horizontal, 10)
    }
}

// MARK: - InfoCard (para otras vistas)

struct InfoCard<Content: View>: View {
    let titulo: String
    @ViewBuilder let contenido: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(titulo.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.secondary)
                .kerning(1)
                .padding(.horizontal, 16).padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGroupedBackground))
            VStack(alignment: .leading, spacing: 10) {
                contenido
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }
}
