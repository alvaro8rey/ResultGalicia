//
//  PartidoDetalleView.swift
//  ResulGalicia
//
//  Created by alvaro on 30/04/2026.
//


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

    var equipoLocal: Equipo? { equipos[partido.equipoLocalId] }
    var equipoVisitante: Equipo? { equipos[partido.equipoVisitanteId] }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Marcador
                marcadorView

                if cargando {
                    ProgressView()
                } else {
                    // Goles
                    if !goles.isEmpty {
                        seccionGoles
                    }
                    
                    // Tarjetas
                    if !tarjetas.isEmpty {
                        seccionTarjetas
                    }
                    
                    // Sustituciones
                    if !sustituciones.isEmpty {
                        seccionSustituciones
                    }
                    
                    // Alineaciones
                    seccionAlineaciones
                }
            }
            .padding()
        }
        .navigationTitle("Partido")
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargar() }
    }

    var marcadorView: some View {
        VStack(spacing: 8) {
            HStack {
                Text(equipoLocal?.nombre ?? "")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                    .font(.system(size: 32, weight: .bold))
                    .padding(.horizontal)
                Text(equipoVisitante?.nombre ?? "")
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }
            if let fecha = partido.fecha {
                Text(fecha)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            if let estadio = partido.estadio {
                Text(estadio)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    var seccionGoles: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Goles")
                .font(.headline)
            ForEach(goles) { gol in
                HStack {
                    if gol.equipoId == partido.equipoLocalId {
                        Text(jugadores[gol.jugadorId]?.nombre ?? "")
                        Spacer()
                        Text("\(gol.minuto ?? 0)'")
                            .foregroundColor(.secondary)
                        Text("⚽")
                    } else {
                        Text("⚽")
                        Text("\(gol.minuto ?? 0)'")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(jugadores[gol.jugadorId]?.nombre ?? "")
                    }
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    var seccionTarjetas: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tarjetas")
                .font(.headline)
            ForEach(tarjetas) { tarjeta in
                HStack {
                    Text(tarjeta.tipo == "amarilla" ? "🟨" : "🟥")
                    Text(jugadores[tarjeta.jugadorId]?.nombre ?? "")
                    Spacer()
                    Text("\(tarjeta.minuto ?? 0)'")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    var seccionSustituciones: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sustituciones")
                .font(.headline)
            ForEach(sustituciones) { s in
                HStack {
                    VStack(alignment: .leading) {
                        Text("▲ \(jugadores[s.jugadorEntraId]?.nombre ?? "")")
                            .foregroundColor(.green)
                        Text("▼ \(jugadores[s.jugadorSaleId]?.nombre ?? "")")
                            .foregroundColor(.red)
                    }
                    Spacer()
                    Text("\(s.minuto ?? 0)'")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    var seccionAlineaciones: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Alineaciones")
                .font(.headline)
            HStack(alignment: .top, spacing: 16) {
                alineacionEquipo(equipoId: partido.equipoLocalId)
                Divider()
                alineacionEquipo(equipoId: partido.equipoVisitanteId)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    func alineacionEquipo(equipoId: UUID) -> some View {
        let titulares = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "titular" }
        let suplentes = alineaciones.filter { $0.equipoId == equipoId && $0.rol == "suplente" }
        return VStack(alignment: .leading, spacing: 4) {
            Text(equipos[equipoId]?.nombre ?? "")
                .font(.caption)
                .fontWeight(.bold)
            Text("Titulares").font(.caption2).foregroundColor(.secondary)
            ForEach(titulares) { a in
                Text(jugadores[a.jugadorId]?.nombre ?? "")
                    .font(.caption)
            }
            if !suplentes.isEmpty {
                Text("Suplentes").font(.caption2).foregroundColor(.secondary).padding(.top, 4)
                ForEach(suplentes) { a in
                    Text(jugadores[a.jugadorId]?.nombre ?? "")
                        .font(.caption)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func cargar() async {
        do {
            async let g = service.fetchGoles(partidoId: partido.id)
            async let t = service.fetchTarjetas(partidoId: partido.id)
            async let s = service.fetchSustituciones(partidoId: partido.id)
            async let a = service.fetchAlineaciones(partidoId: partido.id)
            
            let (gs, ts, ss, as_) = try await (g, t, s, a)
            
            var jugs: [UUID: Jugador] = [:]
            let ids = Set(gs.map { $0.jugadorId } + ts.map { $0.jugadorId } + ss.map { $0.jugadorSaleId } + ss.map { $0.jugadorEntraId } + as_.map { $0.jugadorId })
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
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}
