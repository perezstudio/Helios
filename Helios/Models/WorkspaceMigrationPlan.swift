//
//  WorkspaceMigrationPlan.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

import SwiftData
import Foundation

enum WorkspaceMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[WorkspaceSchemaV1.self, WorkspaceSchemaV2.self]
	}
	
	static var stages: [MigrationStage] {
		[migrateV1toV2]
	}
	
	static let migrateV1toV2 = MigrationStage.custom(
		fromVersion: WorkspaceSchemaV1.self,
		toVersion: WorkspaceSchemaV2.self,
		willMigrate: { context in
			guard let workspaces = try? context.fetch(FetchDescriptor<WorkspaceSchemaV1.WorkspaceV1>()) else { return }
			
			for workspace in workspaces {
				let colorTheme = ColorTheme(rawValue: workspace.color) ?? .blue
				workspace.colorTheme = colorTheme
			}
			try? context.save()
		}, didMigrate: nil
	)
}

// Old schema version
enum WorkspaceSchemaV1: VersionedSchema {
	static var versionIdentifier = Schema.Version(1, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[WorkspaceV1.self]
	}
	
	@Model
	final class WorkspaceV1 {
		@Attribute(.unique) var id: UUID
		var name: String
		var icon: String
		var color: String
		var colorTheme: ColorTheme = ColorTheme.blue  // Add this for migration
		var tabs: [Tab] = []
		var profile: Profile?
		
		init(name: String, icon: String, color: String = "blue") {
			self.id = UUID()
			self.name = name
			self.icon = icon
			self.color = color
		}
	}
}

// New schema version
enum WorkspaceSchemaV2: VersionedSchema {
	static var versionIdentifier = Schema.Version(2, 0, 0)
	
	static var models: [any PersistentModel.Type] {
		[Workspace.self]
	}
}
