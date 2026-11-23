import SwiftUI
import SwiftData

@main
struct SpendSenseApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: Expense.self)
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            DashboardView()
                .tabItem { Label("Home", systemImage: "chart.pie.fill") }
            ExpenseListView()
                .tabItem { Label("Expenses", systemImage: "list.bullet.rectangle.fill") }
            InsightsView()
                .tabItem { Label("Insights", systemImage: "lightbulb.fill") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: Expense.self, inMemory: true)
}
