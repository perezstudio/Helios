import SwiftUI
import SwiftData
import WebKit

@main
struct HeliosApp: App {
	
	// Create and configure the model container for SwiftData
	var sharedModelContainer: ModelContainer = {
		// List all the models you want to persist
		let schema = Schema([
			Profile.self,
			Workspace.self,
			Tab.self,
			HistoryItem.self
		])
		
		// Define model configuration (with options for storage location)
		let config = ModelConfiguration(schema: schema)
		
		// Create and return the container
		return try! ModelContainer(for: schema, configurations: [config])
	}()
	
	var body: some Scene {
		WindowGroup {
			ContentView()
		}
		.modelContainer(sharedModelContainer)
	}
}
