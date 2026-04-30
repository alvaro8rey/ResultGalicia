import SwiftUI

struct ContentView: View {
    @StateObject private var service = SupabaseService()
    
    var body: some View {
        TabView {
            PartidosView()
                .tabItem {
                    Label("Partidos", systemImage: "sportscourt")
                }
                .environmentObject(service)
            
            ClasificacionView()
                .tabItem {
                    Label("Clasificación", systemImage: "list.number")
                }
                .environmentObject(service)
            
            EquiposView()
                .tabItem {
                    Label("Equipos", systemImage: "person.3")
                }
                .environmentObject(service)
        }
    }
}
