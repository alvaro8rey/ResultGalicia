import SwiftUI

// MARK: - Vista principal con filtros

struct ClubesView: View {
    @EnvironmentObject var service: SupabaseService
    @State private var todos: [Club] = []
    @State private var cargando = true
    @State private var errorMsg: String? = nil

    // Filtros
    @State private var filtroNombre    = ""
    @State private var filtroCodigo    = ""
    @State private var filtroProvincia = ""
    @State private var filtroDelegacion = ""
    @State private var filtroLocalidad = ""
    @State private var filtroCP        = ""

    var provincias: [String] {
        Array(Set(todos.compactMap { $0.provincia })).sorted()
    }
    var delegaciones: [String] {
        Array(Set(todos.compactMap { $0.delegacion })).sorted()
    }

    var filtrados: [Club] {
        todos.filter { club in
            (filtroNombre.isEmpty    || club.nombre.localizedCaseInsensitiveContains(filtroNombre)) &&
            (filtroCodigo.isEmpty    || (club.codigo ?? "").localizedCaseInsensitiveContains(filtroCodigo)) &&
            (filtroProvincia.isEmpty || club.provincia == filtroProvincia) &&
            (filtroDelegacion.isEmpty || club.delegacion == filtroDelegacion) &&
            (filtroLocalidad.isEmpty  || (club.localidad ?? "").localizedCaseInsensitiveContains(filtroLocalidad)) &&
            (filtroCP.isEmpty         || (club.cp ?? "").hasPrefix(filtroCP))
        }
    }

    var hayFiltros: Bool {
        !filtroNombre.isEmpty || !filtroCodigo.isEmpty || !filtroProvincia.isEmpty ||
        !filtroDelegacion.isEmpty || !filtroLocalidad.isEmpty || !filtroCP.isEmpty
    }

    var body: some View {
        NavigationStack {
            Group {
                if cargando {
                    ProgressView()
                } else if let msg = errorMsg {
                    ErrorStateView(mensaje: msg) { Task { await cargar() } }
                } else {
                    contenido
                }
            }
            .navigationTitle("Clubes")
            .task { await cargar() }
        }
    }

    var contenido: some View {
        ScrollView {
            VStack(spacing: 0) {
                filtrosCard
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                resultadosSection
                    .padding(.top, 14)
            }
            .padding(.bottom, 20)
        }
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Filtros

    var filtrosCard: some View {
        VStack(spacing: 0) {
            // Nombre
            campoTexto(label: "Nombre", placeholder: "Nombre del club", texto: $filtroNombre)
            Divider().padding(.leading, 16)

            // Código
            campoTexto(label: "Código", placeholder: "Ej. 4266", texto: $filtroCodigo)
                .keyboardType(.numberPad)
            Divider().padding(.leading, 16)

            // Provincia
            campoPicker(
                label: "Provincia",
                valor: filtroProvincia.isEmpty ? "Todas" : filtroProvincia,
                opciones: provincias,
                seleccionado: $filtroProvincia
            )
            Divider().padding(.leading, 16)

            // Delegación
            campoPicker(
                label: "Delegación",
                valor: filtroDelegacion.isEmpty ? "Todas" : filtroDelegacion,
                opciones: delegaciones,
                seleccionado: $filtroDelegacion
            )
            Divider().padding(.leading, 16)

            // Localidad + CP en la misma fila
            HStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Localidad")
                        .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
                    TextField("Localidad", text: $filtroLocalidad)
                        .font(.subheadline)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)

                Divider().frame(height: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text("C.P.")
                        .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
                    TextField("00000", text: $filtroCP)
                        .font(.subheadline)
                        .keyboardType(.numberPad)
                        .frame(width: 70)
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
            }

            // Footer: contador + limpiar
            Divider()
            HStack {
                HStack(spacing: 6) {
                    Text("\(filtrados.count)")
                        .font(.subheadline).fontWeight(.bold).monospacedDigit()
                        .foregroundColor(.brand)
                    Text(filtrados.count == 1 ? "club encontrado" : "clubes encontrados")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                Spacer()
                if hayFiltros {
                    Button {
                        limpiar()
                    } label: {
                        Label("Limpiar", systemImage: "xmark.circle.fill")
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(14)
    }

    func campoTexto(label: String, placeholder: String, texto: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
            TextField(placeholder, text: texto)
                .font(.subheadline)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    func campoPicker(label: String, valor: String, opciones: [String], seleccionado: Binding<String>) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption).foregroundColor(.secondary).fontWeight(.medium)
                Menu {
                    Button("Todas") { seleccionado.wrappedValue = "" }
                    Divider()
                    ForEach(opciones, id: \.self) { opcion in
                        Button(opcion) { seleccionado.wrappedValue = opcion }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(valor)
                            .font(.subheadline)
                            .foregroundColor(seleccionado.wrappedValue.isEmpty ? .secondary : .primary)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }
            Spacer()
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
    }

    // MARK: - Resultados

    var resultadosSection: some View {
        VStack(spacing: 0) {
            if filtrados.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "building.2")
                        .font(.system(size: 38)).foregroundColor(.secondary.opacity(0.3))
                    Text("Sin clubes con esos filtros")
                        .font(.subheadline).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                VStack(spacing: 0) {
                    ForEach(filtrados) { club in
                        NavigationLink(destination: ClubDetalleView(club: club)) {
                            ClubRowView(club: club)
                        }
                        if club.id != filtrados.last?.id {
                            Divider().padding(.leading, 70)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground))
                .cornerRadius(14)
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Helpers

    func limpiar() {
        filtroNombre = ""
        filtroCodigo = ""
        filtroProvincia = ""
        filtroDelegacion = ""
        filtroLocalidad = ""
        filtroCP = ""
    }

    func cargar() async {
        await MainActor.run { errorMsg = nil }
        do {
            let cs = try await service.fetchClubes()
            await MainActor.run { self.todos = cs; self.cargando = false }
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
        VStack(spacing: 0) {
            VStack(spacing: 14) {
                EscudoView(url: club.escudoUrl, size: 90)
                VStack(spacing: 5) {
                    Text(club.nombre)
                        .font(.title2).fontWeight(.bold).foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                    if let loc = club.localidad {
                        Text([loc, club.provincia].compactMap { $0 }.joined(separator: " · "))
                            .font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28).padding(.horizontal, 20)
            .background(Color(.systemBackground))

            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5)
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
