
import SwiftUI
import SwiftData
import WebKit

@main
struct HeliosApp: App {
	let container: ModelContainer
	
	init() {
		do {
			container = try ModelContainer(
				for: Profile.self,
				Workspace.self,
				BookmarkFolder.self,
				Tab.self
			)
		} catch {
			fatalError("Failed to create ModelContainer: \(error)")
		}
	}
	
	var body: some Scene {
		WindowGroup {
			MainWindowView()
		}
		.modelContainer(container)
	}
}
