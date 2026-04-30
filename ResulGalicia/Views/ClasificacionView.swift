import SwiftUI

struct ClasificacionView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var partidos: [Partido] = []
    @State private var goles: [Gol] = []
    @State private var jugadores: [UUID: Jugador] = [:]
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var vistaActual: String = "clasificacion"

    var clasificacion: [FilaClasificacion] {
        calcularClasificacion(equipos: equipos, partidos: partidos)
    }

    var topGoleadores: [FilaGoleador] {
        calcularGoleadores(goles: goles, jugadores: jugadores, equipos: equipos)
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    VStack(spacing: 0) {
                        Picker("", selection: $vistaActual) {
                            Text("Clasificación").tag("clasificacion")
                            Text("Goleadores").tag("goleadores")
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemBackground))

                        Divider()

                        if vistaActual == "clasificacion" {
                            tablaClasificacion
                        } else {
                            GoleadoresList(lista: topGoleadores)
                                .refreshable { await cargar() }
                        }
                    }
                }
            }
            .navigationTitle("Clasificación")
            .task { await cargar() }
        }
    }

    var tablaClasificacion: some View {
        let tabla = clasificacion
        let total = tabla.count
        return List {
            Section {
                ClasificacionCabecera()
                ForEach(Array(tabla.enumerated()), id: \.element.id) { i, fila in
                    ClasificacionRow(posicion: i + 1, fila: fila, total: total)
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await cargar() }
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            async let e = service.fetchEquipos()
            async let p = service.fetchPartidos()
            async let g = service.fetchTodosGoles()
            async let j = service.fetchTodosJugadores()
            let (es, ps, gs, js) = try await (e, p, g, j)
            await MainActor.run {
                self.equipos = es
                self.partidos = ps
                self.goles = gs
                self.jugadores = Dictionary(uniqueKeysWithValues: js.map { ($0.id, $0) })
                self.cargando = false
            }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudo cargar la clasificación"
                self.cargando = false
            }
        }
    }
}
