//
//  Competicion.swift
//  ResulGalicia
//
//  Created by alvaro on 30/04/2026.
//


import Foundation

struct Competicion: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let grupo: String?
    let temporada: String
}

struct Equipo: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let clubId: UUID?

    enum CodingKeys: String, CodingKey {
        case id, nombre
        case clubId = "club_id"
    }
}

struct Partido: Codable, Identifiable {
    let id: UUID
    let competicionId: UUID
    let jornada: Int?
    let fecha: String?
    let hora: String?
    let estadio: String?
    let ciudad: String?
    let arbitro: String?
    let equipoLocalId: UUID
    let equipoVisitanteId: UUID
    let golesLocal: Int
    let golesVisitante: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case competicionId = "competicion_id"
        case jornada, fecha, hora, estadio, ciudad, arbitro
        case equipoLocalId = "equipo_local_id"
        case equipoVisitanteId = "equipo_visitante_id"
        case golesLocal = "goles_local"
        case golesVisitante = "goles_visitante"
    }
}

struct Jugador: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let equipoId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case id, nombre
        case equipoId = "equipo_id"
    }
}

struct Alineacion: Codable, Identifiable {
    let id: UUID
    let partidoId: UUID
    let jugadorId: UUID
    let equipoId: UUID
    let rol: String
    let minutosJugados: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case partidoId = "partido_id"
        case jugadorId = "jugador_id"
        case equipoId = "equipo_id"
        case rol
        case minutosJugados = "minutos_jugados"
    }
}

struct Gol: Codable, Identifiable {
    let id: UUID
    let partidoId: UUID
    let jugadorId: UUID
    let equipoId: UUID
    let minuto: Int?
    let marcador: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case partidoId = "partido_id"
        case jugadorId = "jugador_id"
        case equipoId = "equipo_id"
        case minuto, marcador
    }
}

struct Tarjeta: Codable, Identifiable {
    let id: UUID
    let partidoId: UUID
    let jugadorId: UUID
    let equipoId: UUID
    let tipo: String
    let minuto: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case partidoId = "partido_id"
        case jugadorId = "jugador_id"
        case equipoId = "equipo_id"
        case tipo, minuto
    }
}

struct Sustitucion: Codable, Identifiable {
    let id: UUID
    let partidoId: UUID
    let jugadorSaleId: UUID
    let jugadorEntraId: UUID
    let equipoId: UUID
    let minuto: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case partidoId = "partido_id"
        case jugadorSaleId = "jugador_sale_id"
        case jugadorEntraId = "jugador_entra_id"
        case equipoId = "equipo_id"
        case minuto
    }
}
struct Club: Codable, Identifiable {
    let id: UUID
    let nombre: String
    let codigo: String?
    let delegacion: String?
    let cif: String?
    let domicilio: String?
    let localidad: String?
    let provincia: String?
    let cp: String?
    let telefono: String?
    let email: String?
    let escudoUrl: String?

    enum CodingKeys: String, CodingKey {
        case id, nombre, codigo, delegacion, cif, domicilio, localidad, provincia, cp, telefono, email
        case escudoUrl = "escudo_url"
    }
}
