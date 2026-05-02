import SwiftUI

struct ContentView: View {
    @StateObject private var service = SupabaseService()

    var body: some View {
        TabView {
            MiEquipoView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .environmentObject(service)

            InicioView()
                .tabItem { Label("Ligas", systemImage: "trophy.fill") }
                .environmentObject(service)

            ClubesView()
                .tabItem { Label("Clubes", systemImage: "building.2.fill") }
                .environmentObject(service)

            EquiposView()
                .tabItem { Label("Equipos", systemImage: "person.3.fill") }
                .environmentObject(service)

            BuscadorView()
                .tabItem { Label("Buscador", systemImage: "magnifyingglass") }
                .environmentObject(service)
        }
        .task { try? await service.cargarClubesCache() }
    }
}
