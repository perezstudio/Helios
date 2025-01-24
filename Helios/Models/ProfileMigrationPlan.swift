//
//  ProfileMigrationPlan.swift
//  Helios
//
//  Created by Kevin Perez on 1/23/25.
//


import SwiftUI
import SwiftData
import Foundation

enum ProfileMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [ProfileSchemaV1.self, ProfileSchemaV2.self]
    }
    
    static var stages: [MigrationStage] {
        [migrateV1toV2]
    }
    
    static let migrateV1toV2 = MigrationStage.custom(
        fromVersion: ProfileSchemaV1.self,
        toVersion: ProfileSchemaV2.self,
        willMigrate: { context in
            guard let profiles = try? context.fetch(FetchDescriptor<ProfileSchemaV1.ProfileV1>()) else { return }
            
            for profile in profiles {
                profile.version = 2 // Set the version to current version
            }
            
            try? context.save()
        }, didMigrate: nil
    )
}

// Old schema version
enum ProfileSchemaV1: VersionedSchema {
    static var versionIdentifier = Schema.Version(1, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [ProfileV1.self]
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
            self.version = 1  // Set initial version
        }
    }
}

// New schema version
enum ProfileSchemaV2: VersionedSchema {
    static var versionIdentifier = Schema.Version(2, 0, 0)
    
    static var models: [any PersistentModel.Type] {
        [Profile.self]
    }
}
