import SwiftUI
import SwiftData
import WebKit

@main
struct HeliosApp: App {
	@StateObject private var browserViewModel = BrowserViewModel()
	let container: ModelContainer
	
	init() {
		do {
			let schema = Schema([
				Profile.self,
				Workspace.self,
				Tab.self,
				HistoryEntry.self,
				SearchEngine.self
			])
			
			let modelConfiguration = ModelConfiguration(
				schema: schema,
				isStoredInMemoryOnly: false,
				allowsSave: true
			)
			
			// Create container with schema
			container = try ModelContainer(
				for: schema,
				migrationPlan: AppMigrationPlan.self,
				configurations: modelConfiguration
			)
			
			// Initialize default search engines if needed
			initializeDefaultSearchEngines()
			
		} catch {
			print("Error initializing container: \(error)")
			fatalError("Could not initialize ModelContainer: \(error)")
		}
	}
	
	private func initializeDefaultSearchEngines() {
		let context = container.mainContext
		
		// Check if search engines already exist
		let descriptor = FetchDescriptor<SearchEngine>()
		guard let count = try? context.fetch(descriptor).count, count == 0 else {
			return
		}
		
		// Insert default search engines
		SearchEngine.defaultEngines.forEach { engine in
			context.insert(engine)
		}
		
		try? context.save()
	}
	
	var body: some Scene {
		WindowGroup {
			ContentView()
				.modelContainer(container)
				.environmentObject(browserViewModel)
		}
		.commands {
			CommandGroup(after: .newItem) {
				Button("New Window") {
					openNewWindow()
				}
				.keyboardShortcut("n", modifiers: [.command])
				
				Button("New Tab") {
					if let focusedWindow = NSApp.keyWindow,
					   let windowId = focusedWindow.identifier?.rawValue {
						browserViewModel.addNewTab()
					}
				}
				.keyboardShortcut("t", modifiers: [.command])
			}
		}
		
		Settings {
			SettingsView()
				.modelContainer(container)
		}
		.windowStyle(.titleBar)
	}
	
	private func openNewWindow() {
		guard let currentWindow = NSApp.keyWindow else { return }
		let newWindow = NSWindow(
			contentRect: currentWindow.frame,
			styleMask: [.titled, .closable, .miniaturizable, .resizable],
			backing: .buffered,
			defer: false
		)
		
		let contentView = ContentView()
			.modelContainer(container)
			.environmentObject(browserViewModel)
		
		newWindow.contentView = NSHostingView(rootView: contentView)
		newWindow.makeKeyAndOrderFront(nil)
	}
}

extension FocusedValues {
	struct WindowIdKey: FocusedValueKey {
		typealias Value = UUID
	}
	
	var windowId: WindowIdKey.Value? {
		get { self[WindowIdKey.self] }
		set { self[WindowIdKey.self] = newValue }
	}
}
