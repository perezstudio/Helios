
import SwiftUI
import SwiftData
import WebKit

@main
struct HeliosApp: App {
	@StateObject private var browserViewModel = BrowserViewModel()
	
	let container: ModelContainer
	
	init() {
		do {
			// Configure the container with schema and storage options
			let config = ModelConfiguration(
				"Helios-DB",
				schema: Schema([Profile.self, Workspace.self, Tab.self, HistoryEntry.self]),
				isStoredInMemoryOnly: false,
				allowsSave: true
			)
			container = try ModelContainer(for: Profile.self, Workspace.self, Tab.self, HistoryEntry.self, configurations: config)
		} catch {
			fatalError("Could not initialize ModelContainer: \(error)")
		}
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(container)
				.environmentObject(browserViewModel)
		}
	}
}
