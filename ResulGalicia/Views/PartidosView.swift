//
//  PartidosView.swift
//  ResulGalicia
//
//  Created by alvaro on 30/04/2026.
//


import SwiftUI

struct PartidosView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var partidos: [Partido] = []
    @State private var equipos: [UUID: Equipo] = [:]
    @State private var cargando = true

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else {
                    List(partidos) { partido in
                        NavigationLink(destination: PartidoDetalleView(partido: partido, equipos: equipos)) {
                            PartidoRowView(partido: partido, equipos: equipos)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Partidos")
            .task {
                await cargar()
            }
        }
    }

    func cargar() async {
        do {
            let ps = try await service.fetchPartidos()
            var eq: [UUID: Equipo] = [:]
            for p in ps {
                if eq[p.equipoLocalId] == nil {
                    eq[p.equipoLocalId] = try await service.fetchEquipo(id: p.equipoLocalId)
                }
                if eq[p.equipoVisitanteId] == nil {
                    eq[p.equipoVisitanteId] = try await service.fetchEquipo(id: p.equipoVisitanteId)
                }
            }
            await MainActor.run {
                self.partidos = ps
                self.equipos = eq
                self.cargando = false
            }
        } catch {
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}

struct PartidoRowView: View {
    let partido: Partido
    let equipos: [UUID: Equipo]

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let fecha = partido.fecha {
                Text(fecha)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            HStack {
                Text(equipos[partido.equipoLocalId]?.nombre ?? "...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                    .font(.headline)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                Text(equipos[partido.equipoVisitanteId]?.nombre ?? "...")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .padding(.vertical, 4)
    }
}