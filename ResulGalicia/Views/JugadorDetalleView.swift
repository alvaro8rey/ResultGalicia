//
//  JugadorDetalleView.swift
//  ResulGalicia
//
//  Created by alvaro on 30/04/2026.
//


import SwiftUI

struct JugadorDetalleView: View {
    let jugador: Jugador
    @EnvironmentObject var service: SupabaseService
    @State private var alineaciones: [Alineacion] = []
    @State private var goles: [Gol] = []
    @State private var tarjetas: [Tarjeta] = []
    @State private var cargando = true

    var minutosJugados: Int { alineaciones.reduce(0) { $0 + $1.minutosJugados } }
    var minutosPosibles: Int { alineaciones.count * 90 }
    var totalGoles: Int { goles.count }
    var amarillas: Int { tarjetas.filter { $0.tipo == "amarilla" }.count }
    var rojas: Int { tarjetas.filter { $0.tipo != "amarilla" }.count }
    var partidos: Int { alineaciones.count }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Cabecera
                VStack(spacing: 4) {
                    Text(jugador.nombre)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color(.systemGray6))
                .cornerRadius(12)

                if cargando {
                    ProgressView()
                } else {
                    // Stats generales
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatBox(valor: "\(partidos)", etiqueta: "Partidos")
                        StatBox(valor: "\(totalGoles)", etiqueta: "Goles")
                        StatBox(valor: "\(minutosJugados)'", etiqueta: "Minutos")
                        StatBox(valor: minutosPosibles > 0 ? "\(Int(Double(minutosJugados) / Double(minutosPosibles) * 100))%" : "0%", etiqueta: "% Jugado")
                        StatBox(valor: "\(amarillas)🟨", etiqueta: "Amarillas")
                        StatBox(valor: "\(rojas)🟥", etiqueta: "Rojas")
                    }

                    // Goles detalle
                    if !goles.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Goles")
                                .font(.headline)
                            ForEach(goles) { gol in
                                HStack {
                                    Text("⚽")
                                    Text("Min. \(gol.minuto ?? 0)")
                                        .font(.subheadline)
                                    Spacer()
                                    Text(gol.marcador ?? "")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }

                    // Tarjetas detalle
                    if !tarjetas.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Tarjetas")
                                .font(.headline)
                            ForEach(tarjetas) { tarjeta in
                                HStack {
                                    Text(tarjeta.tipo == "amarilla" ? "🟨" : "🟥")
                                    Text(tarjeta.tipo)
                                        .font(.subheadline)
                                    Spacer()
                                    Text("Min. \(tarjeta.minuto ?? 0)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Jugador")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    func cargar() async {
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
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}

struct StatBox: View {
    let valor: String
    let etiqueta: String

    var body: some View {
        VStack(spacing: 4) {
            Text(valor)
                .font(.title3)
                .fontWeight(.bold)
            Text(etiqueta)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}