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

            BuscadorView()
                .tabItem { Label("Buscador", systemImage: "magnifyingglass") }
                .environmentObject(service)
        }
        .task { try? await service.cargarClubesCache() }
    }
}
