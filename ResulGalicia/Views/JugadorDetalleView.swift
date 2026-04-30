import SwiftUI

struct JugadorDetalleView: View {
    let jugador: Jugador
    @EnvironmentObject var service: SupabaseService
    @State private var alineaciones: [Alineacion] = []
    @State private var goles: [Gol] = []
    @State private var tarjetas: [Tarjeta] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    var minutosJugados: Int { alineaciones.reduce(0) { $0 + $1.minutosJugados } }
    var minutosPosibles: Int { alineaciones.count * 90 }
    var totalGoles: Int { goles.count }
    var amarillas: Int { tarjetas.filter { $0.tipo == "amarilla" }.count }
    var rojas: Int { tarjetas.filter { $0.tipo != "amarilla" }.count }
    var partidos: Int { alineaciones.count }
    var porcentajeJugado: Int {
        guard minutosPosibles > 0 else { return 0 }
        return Int(Double(minutosJugados) / Double(minutosPosibles) * 100)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                // Cabecera jugador
                VStack(spacing: 10) {
                    InicialCircle(nombre: jugador.nombre, color: .blue, size: 72)
                    Text(jugador.nombre)
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
                    // Stats
                    InfoCard(titulo: "Estadísticas") {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                            StatBox(valor: "\(partidos)", etiqueta: "Partidos")
                            StatBox(valor: "\(totalGoles)", etiqueta: "Goles")
                            StatBox(valor: "\(minutosJugados)'", etiqueta: "Minutos")
                            StatBox(valor: "\(porcentajeJugado)%", etiqueta: "% Jugado")
                            StatBox(valor: "\(amarillas)", etiqueta: "🟨 Amarillas")
                            StatBox(valor: "\(rojas)", etiqueta: "🟥 Rojas")
                        }
                    }

                    // Goles
                    if !goles.isEmpty {
                        InfoCard(titulo: "⚽ Goles") {
                            VStack(spacing: 8) {
                                ForEach(goles) { gol in
                                    HStack {
                                        Label("Min. \(gol.minuto ?? 0)", systemImage: "clock")
                                            .font(.subheadline)
                                        Spacer()
                                        if let marcador = gol.marcador, !marcador.isEmpty {
                                            Text(marcador)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal, 8).padding(.vertical, 3)
                                                .background(Color(.tertiarySystemFill))
                                                .cornerRadius(6)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Tarjetas
                    if !tarjetas.isEmpty {
                        InfoCard(titulo: "Tarjetas") {
                            VStack(spacing: 8) {
                                ForEach(tarjetas) { tarjeta in
                                    HStack {
                                        RoundedRectangle(cornerRadius: 3)
                                            .fill(tarjeta.tipo == "amarilla" ? Color.yellow : Color.red)
                                            .frame(width: 10, height: 14)
                                        Text(tarjeta.tipo == "amarilla" ? "Amarilla"
                                             : tarjeta.tipo == "doble_amarilla" ? "2ª Amarilla"
                                             : "Roja directa")
                                            .font(.subheadline)
                                        Spacer()
                                        Label("Min. \(tarjeta.minuto ?? 0)", systemImage: "clock")
                                            .font(.caption).foregroundColor(.secondary)
                                    }
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
        .navigationTitle("Jugador")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let a = service.fetchAlineacionesJugador(jugadorId: jugador.id)
            async let g = service.fetchGolesJugador(jugadorId: jugador.id)
            async let t = service.fetchTarjetasJugador(jugadorId: jugador.id)
            let (as_, gs, ts) = try await (a, g, t)
            await MainActor.run {
                self.alineaciones = as_
                self.goles = gs
                self.tarjetas = ts
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
        VStack(spacing: 5) {
            Text(valor)
                .font(.title3).fontWeight(.bold)
                .minimumScaleFactor(0.7).lineLimit(1)
            Text(etiqueta)
                .font(.caption2).foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 8)
        .background(Color(.tertiarySystemFill))
        .cornerRadius(10)
    }
}
