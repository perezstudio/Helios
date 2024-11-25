import SwiftUI
import SwiftData
import WebKit

@main
struct HeliosApp: App {
	let container: ModelContainer
	
	init() {
		// Clear SwiftData store during development
		#if DEBUG
		try? FileManager.default.removeItem(at: URL.applicationSupportDirectory.appending(path: "default.store"))
		#endif
		
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
		// Main Window
		WindowGroup {
			MainWindowView()
				.toolbar {
					ToolbarItem(placement: .primaryAction) {
						SettingsLink {
							SettingsView()
						}
					}
				}
		}
		.modelContainer(container)
		.commands {
			// File Menu Commands
			CommandMenu("File") {
				Button("New Profile") {
					NotificationCenter.default.post(name: .openNewProfile, object: nil)
				}
				.keyboardShortcut("n", modifiers: [.command, .shift])
				
				Button("New Tab") {
					NotificationCenter.default.post(name: .openNewTab, object: nil)
				}
				.keyboardShortcut("t", modifiers: .command)
			}
		}

		// Settings Scene
		Settings {
			SettingsView()
		}
		.modelContainer(container)
	}
}


// Add notification names
extension Notification.Name {
	static let openNewTab = Notification.Name("openNewTab")
	static let openNewProfile = Notification.Name("openNewProfile")
}
