import SwiftUI

// MARK: - Lista de clubes

struct ClubesView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var clubes: [Club] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil
    @State private var busqueda = ""

    var clubesFiltrados: [Club] {
        guard !busqueda.isEmpty else { return clubes }
        let q = busqueda.lowercased()
        return clubes.filter {
            $0.nombre.lowercased().contains(q) ||
            ($0.localidad?.lowercased().contains(q) ?? false) ||
            ($0.provincia?.lowercased().contains(q) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    lista
                }
            }
            .navigationTitle("Clubes")
            .searchable(text: $busqueda, prompt: "Buscar club...")
            .task { await cargar() }
            .refreshable { await cargar() }
        }
    }

    var lista: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                if clubesFiltrados.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "shield").font(.largeTitle).foregroundColor(.secondary)
                        Text("Sin resultados").foregroundColor(.secondary).font(.subheadline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(clubesFiltrados) { club in
                            NavigationLink(destination: ClubDetalleView(club: club)) {
                                ClubRowView(club: club)
                            }
                            if club.id != clubesFiltrados.last?.id {
                                Divider().padding(.leading, 70)
                            }
                        }
                    }
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(14)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
        }
        .background(Color(.systemGroupedBackground))
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            let cs = try await service.fetchClubes()
            await MainActor.run { self.clubes = cs; self.cargando = false }
        } catch {
            await MainActor.run {
                self.errorMsg = "No se pudieron cargar los clubes"
                self.cargando = false
            }
        }
    }
}

// MARK: - Fila de club

struct ClubRowView: View {
    let club: Club

    var body: some View {
        HStack(spacing: 14) {
            EscudoView(url: club.escudoUrl, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(club.nombre)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundColor(.primary).lineLimit(1)
                if let loc = club.localidad {
                    Text([loc, club.provincia].compactMap { $0 }.joined(separator: " · "))
                        .font(.caption).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary.opacity(0.5))
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }
}

// MARK: - Detalle de club

struct ClubDetalleView: View {
    let club: Club
    @EnvironmentObject var service: SupabaseService
    @State private var equipos: [Equipo] = []
    @State private var cargandoEquipos = true

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                cabeceraView

                VStack(spacing: 14) {
                    if hasDatos { infoCard }
                    equiposSection
                }
                .padding(.horizontal, 16).padding(.vertical, 14)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(club.nombre)
        .navigationBarTitleDisplayMode(.inline)
        .task { await cargarEquipos() }
    }

    // MARK: Cabecera

    var cabeceraView: some View {
        ZStack {
            Color.brandDark
            VStack(spacing: 14) {
                EscudoView(url: club.escudoUrl, size: 84)
                VStack(spacing: 6) {
                    Text(club.nombre)
                        .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        .multilineTextAlignment(.center)
                    if let loc = club.localidad {
                        Text([loc, club.provincia].compactMap { $0 }.joined(separator: " · "))
                            .font(.caption).foregroundColor(.white.opacity(0.5))
                    }
                }
            }
            .padding(.vertical, 28).padding(.horizontal, 20)
        }
    }

    // MARK: Info

    var hasDatos: Bool {
        [club.codigo, club.delegacion, club.cif, club.domicilio, club.telefono, club.email].contains { $0 != nil }
    }

    var infoCard: some View {
        VStack(spacing: 0) {
            seccionHeader("INFORMACIÓN")

            VStack(spacing: 0) {
                if let v = club.codigo     { infoFila("Código",      valor: v); Divider().padding(.leading, 16) }
                if let v = club.delegacion { infoFila("Delegación",  valor: v); Divider().padding(.leading, 16) }
                if let v = club.cif        { infoFila("CIF",          valor: v); Divider().padding(.leading, 16) }
                if let v = club.domicilio  {
                    let dir = [v, club.cp, club.localidad].compactMap { $0 }.joined(separator: ", ")
                    infoFila("Domicilio", valor: dir)
                    if club.telefono != nil || club.email != nil { Divider().padding(.leading, 16) }
                }
                if let tel = club.telefono {
                    Button {
                        if let url = URL(string: "tel://\(tel.filter { !$0.isWhitespace })") {
                            UIApplication.shared.open(url)
                        }
                    } label: { infoFilaLink("Teléfono", valor: tel, icono: "phone.fill") }
                    if club.email != nil { Divider().padding(.leading, 16) }
                }
                if let mail = club.email {
                    Button {
                        if let url = URL(string: "mailto:\(mail)") {
                            UIApplication.shared.open(url)
                        }
                    } label: { infoFilaLink("Email", valor: mail, icono: "envelope.fill") }
                }
            }
            .background(Color(.secondarySystemGroupedBackground))
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func infoFila(_ titulo: String, valor: String) -> some View {
        HStack {
            Text(titulo).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            Text(valor)
                .font(.subheadline).fontWeight(.medium)
                .multilineTextAlignment(.trailing)
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    func infoFilaLink(_ titulo: String, valor: String, icono: String) -> some View {
        HStack {
            Text(titulo).font(.subheadline).foregroundColor(.secondary)
            Spacer()
            HStack(spacing: 6) {
                Text(valor)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundColor(.brand)
                    .lineLimit(1)
                Image(systemName: icono).font(.caption).foregroundColor(.brand)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
    }

    // MARK: Equipos

    var equiposSection: some View {
        VStack(spacing: 0) {
            seccionHeader("EQUIPOS")

            if cargandoEquipos {
                ProgressView().padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
            } else if equipos.isEmpty {
                Text("Sin equipos registrados")
                    .font(.subheadline).foregroundColor(.secondary)
                    .padding(20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemGroupedBackground))
            } else {
                VStack(spacing: 0) {
                    ForEach(equipos) { equipo in
                        NavigationLink(destination: EquipoDetalleView(equipo: equipo)) {
                            HStack(spacing: 12) {
                                EscudoView(url: club.escudoUrl, size: 36)
                                Text(equipo.nombre)
                                    .font(.subheadline).foregroundColor(.primary).lineLimit(1)
                                Spacer()
                                Image(systemName: "chevron.right").font(.caption2).foregroundColor(.secondary.opacity(0.5))
                            }
                            .padding(.horizontal, 16).padding(.vertical, 11)
                        }
                        if equipo.id != equipos.last?.id {
                            Divider().padding(.leading, 64)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
            }
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func seccionHeader(_ titulo: String) -> some View {
        Text(titulo)
            .font(.system(size: 11, weight: .bold))
            .foregroundColor(.secondary)
            .kerning(1)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color(.systemGroupedBackground))
    }

    func cargarEquipos() async {
        do {
            let es = try await service.fetchEquiposPorClub(clubId: club.id)
            await MainActor.run { self.equipos = es; self.cargandoEquipos = false }
        } catch {
            await MainActor.run { self.cargandoEquipos = false }
        }
    }
}

// MARK: - Escudo async image

struct EscudoView: View {
    let url: String?
    let size: CGFloat

    var body: some View {
        Group {
            if let urlStr = url, !urlStr.isEmpty, let imageUrl = URL(string: urlStr) {
                AsyncImage(url: imageUrl) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFit()
                            .frame(width: size, height: size)
                    case .failure:
                        placeholder
                    case .empty:
                        ProgressView().frame(width: size, height: size)
                    @unknown default:
                        placeholder
                    }
                }
            } else {
                placeholder
            }
        }
    }

    var placeholder: some View {
        ZStack {
            Circle()
                .fill(Color(.systemGray5))
                .frame(width: size, height: size)
            Image(systemName: "shield.fill")
                .font(.system(size: size * 0.44))
                .foregroundColor(Color(.systemGray3))
        }
    }
}
