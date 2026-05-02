import Foundation
import Combine
import Supabase

let supabase = SupabaseClient(
    supabaseURL: URL(string: "https://hgnbceiicezoltlcfzha.supabase.co")!,
    supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImhnbmJjZWlpY2V6b2x0bGNmemhhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NjU5MDgsImV4cCI6MjA5MzE0MTkwOH0.owoFMn9oJhPFrdppkdr2-T-h3NHnsPAJdgkYZudIIjE"
)

class SupabaseService: ObservableObject {
    @Published var clubesMap: [UUID: Club] = [:]

    func cargarClubesCache() async throws {
        let cs = try await fetchClubes()
        let map = Dictionary(uniqueKeysWithValues: cs.map { ($0.id, $0) })
        await MainActor.run { self.clubesMap = map }
    }

    func escudoUrl(equipo: Equipo) -> String? {
        guard let cid = equipo.clubId else { return nil }
        return clubesMap[cid]?.escudoUrl
    }

    func fetchPartidos(competicionId: UUID? = nil) async throws -> [Partido] {
        if let id = competicionId {
            return try await supabase
                .from("partidos")
                .select()
                .eq("competicion_id", value: id)
                .order("fecha", ascending: false)
                .execute()
                .value
        }
        return try await supabase
            .from("partidos")
            .select()
            .order("fecha", ascending: false)
            .execute()
            .value
    }
    
    func fetchEquipo(id: UUID) async throws -> Equipo {
        return try await supabase
            .from("equipos")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
    
    func fetchEquipos() async throws -> [Equipo] {
        return try await supabase
            .from("equipos")
            .select()
            .order("nombre")
            .execute()
            .value
    }
    
    func fetchAlineaciones(partidoId: UUID) async throws -> [Alineacion] {
        return try await supabase
            .from("alineaciones")
            .select()
            .eq("partido_id", value: partidoId)
            .execute()
            .value
    }
    
    func fetchGoles(partidoId: UUID) async throws -> [Gol] {
        return try await supabase
            .from("goles")
            .select()
            .eq("partido_id", value: partidoId)
            .order("minuto")
            .execute()
            .value
    }
    
    func fetchTarjetas(partidoId: UUID) async throws -> [Tarjeta] {
        return try await supabase
            .from("tarjetas")
            .select()
            .eq("partido_id", value: partidoId)
            .execute()
            .value
    }
    
    func fetchSustituciones(partidoId: UUID) async throws -> [Sustitucion] {
        return try await supabase
            .from("sustituciones")
            .select()
            .eq("partido_id", value: partidoId)
            .order("minuto")
            .execute()
            .value
    }
    
    func fetchJugador(id: UUID) async throws -> Jugador {
        return try await supabase
            .from("jugadores")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchPartido(id: UUID) async throws -> Partido {
        return try await supabase
            .from("partidos")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }
    
    func fetchJugadores(equipoId: UUID) async throws -> [Jugador] {
        return try await supabase
            .from("jugadores")
            .select()
            .eq("equipo_id", value: equipoId)
            .order("nombre")
            .execute()
            .value
    }
    
    func fetchPartidosPorEquipo(equipoId: UUID) async throws -> [Partido] {
        return try await supabase
            .from("partidos")
            .select()
            .or("equipo_local_id.eq.\(equipoId),equipo_visitante_id.eq.\(equipoId)")
            .order("fecha", ascending: false)
            .execute()
            .value
    }
    
    func fetchCompeticiones() async throws -> [Competicion] {
        return try await supabase
            .from("competiciones")
            .select()
            .order("nombre")
            .execute()
            .value
    }
    
    func fetchAlineacionesJugador(jugadorId: UUID) async throws -> [Alineacion] {
        return try await supabase
            .from("alineaciones")
            .select()
            .eq("jugador_id", value: jugadorId)
            .execute()
            .value
    }

    func fetchGolesJugador(jugadorId: UUID) async throws -> [Gol] {
        return try await supabase
            .from("goles")
            .select()
            .eq("jugador_id", value: jugadorId)
            .execute()
            .value
    }

    func fetchTarjetasJugador(jugadorId: UUID) async throws -> [Tarjeta] {
        return try await supabase
            .from("tarjetas")
            .select()
            .eq("jugador_id", value: jugadorId)
            .execute()
            .value
    }

    func fetchGolesEquipo(equipoId: UUID) async throws -> [Gol] {
        return try await supabase
            .from("goles")
            .select()
            .eq("equipo_id", value: equipoId)
            .execute()
            .value
    }

    func fetchTarjetasEquipo(equipoId: UUID) async throws -> [Tarjeta] {
        return try await supabase
            .from("tarjetas")
            .select()
            .eq("equipo_id", value: equipoId)
            .execute()
            .value
    }

    func fetchAlineacionesEquipo(equipoId: UUID) async throws -> [Alineacion] {
        return try await supabase
            .from("alineaciones")
            .select()
            .eq("equipo_id", value: equipoId)
            .execute()
            .value
    }

    func fetchTodosGoles() async throws -> [Gol] {
        return try await supabase
            .from("goles")
            .select()
            .execute()
            .value
    }

    func fetchTodosJugadores() async throws -> [Jugador] {
        return try await supabase
            .from("jugadores")
            .select()
            .order("nombre")
            .execute()
            .value
    }

    func fetchClubes() async throws -> [Club] {
        return try await supabase
            .from("clubes")
            .select()
            .order("nombre")
            .execute()
            .value
    }

    func fetchClub(id: UUID) async throws -> Club {
        return try await supabase
            .from("clubes")
            .select()
            .eq("id", value: id)
            .single()
            .execute()
            .value
    }

    func fetchEquiposPorClub(clubId: UUID) async throws -> [Equipo] {
        return try await supabase
            .from("equipos")
            .select()
            .eq("club_id", value: clubId)
            .order("nombre")
            .execute()
            .value
    }

    func fetchEquipoIdsEnCompeticion(competicionId: UUID) async throws -> Set<UUID> {
        let partidos = try await fetchPartidos(competicionId: competicionId)
        var ids = Set<UUID>()
        for p in partidos { ids.insert(p.equipoLocalId); ids.insert(p.equipoVisitanteId) }
        return ids
    }
}
