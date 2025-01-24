//
//  AppMigrationPlan.swift
//  Helios
//
//  Created by Kevin Perez on 1/23/25.
//


import SwiftUI
import SwiftData
import Foundation

enum AppMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: SchemaV1.self,
        toVersion: SchemaV2.self,
        willMigrate: { context in
            // Migrate Workspaces
            if let workspaces = try? context.fetch(FetchDescriptor<SchemaV1.WorkspaceV1>()) {
                for workspace in workspaces {
                    let colorTheme = ColorTheme(rawValue: workspace.color) ?? .blue
                    workspace.colorTheme = colorTheme
                }
            }
            
            // Migrate Profiles
            if let profiles = try? context.fetch(FetchDescriptor<SchemaV1.ProfileV1>()) {
                for profile in profiles {
                    profile.version = 2
                }
            }
            
            try? context.save()
        }, didMigrate: nil
    )
}

// Old schema version
enum SchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [WorkspaceV1.self, ProfileV1.self]
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
    
    @Model
    final class ProfileV1 {
        @Attribute(.unique) var id: UUID
        var name: String
        var pinnedTabs: [Tab]
        var workspaces: [Workspace]
        var history: [HistoryEntry]
        @Relationship(deleteRule: .nullify) var defaultSearchEngine: SearchEngine?
        var userAgent: String?
        var version: Int  // Add this for migration
        
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

// New schema version
enum SchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Workspace.self, Profile.self]
    }
}
