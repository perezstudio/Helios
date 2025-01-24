import SwiftUI
import SwiftData

struct ProfileDetailView: View {
	@Environment(\.modelContext) private var modelContext
	@Query(sort: \SearchEngine.name) private var searchEngines: [SearchEngine]
	@Bindable var profile: Profile
	
	var body: some View {
		Form {
			Section("Profile Information") {
				TextField("Profile Name", text: .init(
					get: { profile.name },
					set: { newValue in
						profile.name = newValue
						try? modelContext.save()
					}
				))
				LabeledContent("Workspaces", value: "\(profile.workspaces.count)")
				LabeledContent("History Entries", value: "\(profile.history.count)")
				
				Picker("Default Search Engine", selection: .init(
					get: { profile.defaultSearchEngine },
					set: { newEngine in
						updateDefaultSearchEngine(newEngine)
					}
				)) {
					Text("None").tag(Optional<SearchEngine>.none)
					ForEach(searchEngines) { engine in
						Text(engine.name).tag(Optional(engine))
					}
				}
				
				Picker("User Agent", selection: .init(
					get: { profile.userAgentType },
					set: { newValue in
						profile.userAgentType = newValue
						try? modelContext.save()
						// Refresh WebViews to apply new user agent
						NotificationCenter.default.post(
							name: NSNotification.Name("RefreshWebViews"),
							object: nil,
							userInfo: ["profileId": profile.id]
						)
					}
				)) {
					ForEach(UserAgent.allCases, id: \.self) { agent in
						Text(agent.name).tag(agent)
					}
				}
			}
			
			Section("Data Management") {
				Button("Clear Browsing Data...") {
					// TODO: Implement clear data functionality
				}
				
				Button("Export Profile Data...") {
					// TODO: Implement export functionality
				}
			}
			
			Section("Privacy") {
				Toggle("Block Third-Party Cookies", isOn: .constant(true))
				Toggle("Prevent Cross-Site Tracking", isOn: .constant(true))
			}
		}
		.formStyle(.grouped)
	}
	
	private func updateDefaultSearchEngine(_ engine: SearchEngine?) {
		// Remove profile from old engine's profiles array if it exists
		if let oldEngine = profile.defaultSearchEngine {
			oldEngine.profiles?.removeAll(where: { $0.id == profile.id })
		}
		
		// Set the new engine
		profile.defaultSearchEngine = engine
		
		// Add profile to new engine's profiles array if it exists
		if let newEngine = engine {
			if newEngine.profiles == nil {
				newEngine.profiles = []
			}
			newEngine.profiles?.append(profile)
		}
		
		// Save changes
		try? modelContext.save()
	}
}
