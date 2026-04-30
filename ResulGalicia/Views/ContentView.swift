import SwiftUI

struct ContentView: View {
    @StateObject private var service = SupabaseService()

    var body: some View {
        TabView {
            InicioView()
                .tabItem { Label("Inicio", systemImage: "house.fill") }
                .environmentObject(service)

            PartidosView()
                .tabItem { Label("Partidos", systemImage: "sportscourt.fill") }
                .environmentObject(service)

            ClasificacionView()
                .tabItem { Label("Clasificación", systemImage: "list.number") }
                .environmentObject(service)

            EquiposView()
                .tabItem { Label("Equipos", systemImage: "person.3.fill") }
                .environmentObject(service)
        }
    }
}
