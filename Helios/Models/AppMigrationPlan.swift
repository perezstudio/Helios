import SwiftUI
import SwiftData
import Foundation

enum AppMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[SchemaV1.self, SchemaV2.self, SchemaV3.self]
	}
	
	static var stages: [MigrationStage] {
		[migrateV1toV2, migrateV2toV3]
	}
	
	static let migrateV1toV2 = MigrationStage.custom(
		fromVersion: SchemaV1.self,
		toVersion: SchemaV2.self,
		willMigrate: { context in
			// Migrate Workspaces
			let workspaceRequest = FetchDescriptor<SchemaV1.WorkspaceV1>()
			if let workspaces = try? context.fetch(workspaceRequest) {
				for workspace in workspaces {
					let colorTheme = ColorTheme(rawValue: workspace.color) ?? .blue
					workspace.colorTheme = colorTheme
				}
			}
			
			// Migrate Profiles
			let profileRequest = FetchDescriptor<SchemaV1.ProfileV1>()
			if let profiles = try? context.fetch(profileRequest) {
				for profile in profiles {
					profile.version = 2
					// Ensure userAgent is set
					if profile.userAgent == nil {
						profile.userAgent = UserAgent.safari.rawValue
					}
				}
			}
			
			try? context.save()
		}, didMigrate: { context in
			try? context.save()
		}
	)
	
	static let migrateV2toV3 = MigrationStage.custom(
		fromVersion: SchemaV2.self,
		toVersion: SchemaV3.self,
		willMigrate: { context in
			// Migrate tabs to include bookmarkedUrl
			let tabRequest = FetchDescriptor<Tab>()
			if let tabs = try? context.fetch(tabRequest) {
				for tab in tabs {
					if tab.type == .bookmark {
						tab.bookmarkedUrl = tab.url
					}
				}
			}
			
			try? context.save()
		}, didMigrate: { context in
			try? context.save()
		}
	)
	
	static let migrateV3toV4 = MigrationStage.custom(
		fromVersion: SchemaV3.self,
		toVersion: SchemaV4.self,
		willMigrate: { context in
			// Move pinned tabs to workspaces
			let profileRequest = FetchDescriptor<Profile>()
			guard let profiles = try? context.fetch(profileRequest) else { return }
			
			for profile in profiles {
				// Get all pinned tabs that need to be moved
				let pinnedTabs = profile.pinnedTabs
				
				// If profile has no workspaces, create a default one
				if profile.workspaces.isEmpty {
					let defaultWorkspace = Workspace(
						name: "Default",
						icon: "square.stack",
						colorTheme: .defaultTheme
					)
					defaultWorkspace.profile = profile
					profile.workspaces.append(defaultWorkspace)
					context.insert(defaultWorkspace)
				}
				
				// Move each pinned tab to the first workspace
				if let firstWorkspace = profile.workspaces.first {
					for tab in pinnedTabs {
						tab.workspace = firstWorkspace
						firstWorkspace.tabs.append(tab)
					}
				}
			}
			
			try? context.save()
		},
		didMigrate: { context in
			try? context.save()
		}
	)
}

// Schema Versions
enum SchemaV1: VersionedSchema {
	static var versionIdentifier = Schema.Version(1, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[WorkspaceV1.self, ProfileV1.self, Tab.self, HistoryEntry.self, SearchEngine.self]
	}
	
	@Model
	final class WorkspaceV1 {
		@Attribute(.unique) var id: UUID
		var name: String
		var icon: String
		var color: String
		var colorTheme: ColorTheme = ColorTheme.blue
		var tabs: [Tab] = []
		var profile: ProfileV1?
		
		init(name: String, icon: String, color: String = "blue") {
			self.id = UUID()
			self.name = name
			self.icon = icon
			self.color = color
		}
	}
	
	@Model
	final class ProfileV1 {
		@Attribute(.unique) var id: UUID
		var name: String
		var pinnedTabs: [Tab]
		var workspaces: [WorkspaceV1]
		var history: [HistoryEntry]
		@Relationship(deleteRule: .nullify) var defaultSearchEngine: SearchEngine?
		var userAgent: String?
		var version: Int
		
		init(name: String) {
			self.id = UUID()
			self.name = name
			self.pinnedTabs = []
			self.workspaces = []
			self.history = []
			self.defaultSearchEngine = nil
			self.userAgent = UserAgent.safari.rawValue
			self.version = 1
		}
	}
}

enum SchemaV2: VersionedSchema {
	static var versionIdentifier = Schema.Version(2, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[Workspace.self, Profile.self, Tab.self, HistoryEntry.self, SearchEngine.self]
	}
}

enum SchemaV3: VersionedSchema {
	static var versionIdentifier = Schema.Version(3, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[Workspace.self, Profile.self, Tab.self, HistoryEntry.self, SearchEngine.self]
	}
}

enum SchemaV4: VersionedSchema {
	static var versionIdentifier = Schema.Version(4, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[Workspace.self, Profile.self, Tab.self, HistoryEntry.self, SearchEngine.self]
	}
}
