//
//  ClasificacionView.swift
//  ResulGalicia
//
//  Created by alvaro on 30/04/2026.
//


import SwiftUI

struct ClasificacionView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var partidos: [Partido] = []
    @State private var cargando = true

    struct FilaClasificacion: Identifiable {
        let id: UUID
        let nombre: String
        var pj: Int = 0
        var pg: Int = 0
        var pe: Int = 0
        var pp: Int = 0
        var gf: Int = 0
        var gc: Int = 0
        var puntos: Int { pg * 3 + pe }
        var dg: Int { gf - gc }
    }

    var clasificacion: [FilaClasificacion] {
        var filas: [UUID: FilaClasificacion] = [:]
        for e in equipos {
            filas[e.id] = FilaClasificacion(id: e.id, nombre: e.nombre)
        }
        for p in partidos {
            guard var local = filas[p.equipoLocalId],
                  var visitante = filas[p.equipoVisitanteId] else { continue }
            local.pj += 1
            visitante.pj += 1
            local.gf += p.golesLocal
            local.gc += p.golesVisitante
            visitante.gf += p.golesVisitante
            visitante.gc += p.golesLocal
            if p.golesLocal > p.golesVisitante {
                local.pg += 1
                visitante.pp += 1
            } else if p.golesLocal < p.golesVisitante {
                visitante.pg += 1
                local.pp += 1
            } else {
                local.pe += 1
                visitante.pe += 1
            }
            filas[p.equipoLocalId] = local
            filas[p.equipoVisitanteId] = visitante
        }
        return filas.values.sorted { $0.puntos != $1.puntos ? $0.puntos > $1.puntos : $0.dg > $1.dg }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else {
                    List {
                        // Cabecera
                        HStack {
                            Text("#").frame(width: 24)
                            Text("Equipo").frame(maxWidth: .infinity, alignment: .leading)
                            Text("PJ").frame(width: 28)
                            Text("PG").frame(width: 28)
                            Text("PE").frame(width: 28)
                            Text("PP").frame(width: 28)
                            Text("GD").frame(width: 32)
                            Text("Pts").frame(width: 32)
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)

                        ForEach(Array(clasificacion.enumerated()), id: \.element.id) { i, fila in
                            HStack {
                                Text("\(i + 1)").frame(width: 24).font(.caption).foregroundColor(.secondary)
                                Text(fila.nombre).frame(maxWidth: .infinity, alignment: .leading).font(.subheadline)
                                Text("\(fila.pj)").frame(width: 28).font(.caption)
                                Text("\(fila.pg)").frame(width: 28).font(.caption)
                                Text("\(fila.pe)").frame(width: 28).font(.caption)
                                Text("\(fila.pp)").frame(width: 28).font(.caption)
                                Text("\(fila.dg)").frame(width: 32).font(.caption)
                                Text("\(fila.puntos)").frame(width: 32).font(.caption).fontWeight(.bold)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Clasificación")
            .task { await cargar() }
        }
    }

    func cargar() async {
        do {
            async let e = service.fetchEquipos()
            async let p = service.fetchPartidos()
            let (es, ps) = try await (e, p)
            await MainActor.run {
                self.equipos = es
                self.partidos = ps
                self.cargando = false
            }
        } catch {
            print("Error: \(error)")
            await MainActor.run { cargando = false }
        }
    }
}