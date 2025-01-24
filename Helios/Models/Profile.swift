//
//  Profile.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

@Model
final class Profile {
	@Attribute(.unique) var id: UUID
	var name: String
	var pinnedTabs: [Tab]
	var workspaces: [Workspace]
	var history: [HistoryEntry]
	@Relationship(deleteRule: .nullify) var defaultSearchEngine: SearchEngine?
	var userAgent: String?  // Make this optional
	var version: Int  // Add version tracking
	
	init(name: String) {
		self.id = UUID()
		self.name = name
		self.pinnedTabs = []
		self.workspaces = []
		self.history = []
		self.defaultSearchEngine = nil
		self.userAgent = UserAgent.safari.rawValue
		self.version = 2  // Current version
	}
	
	// Computed property for UserAgent
	var userAgentType: UserAgent {
		get {
			if let userAgent = userAgent {
				return UserAgent(rawValue: userAgent) ?? .safari
			}
			return .safari
		}
		set {
			userAgent = newValue.rawValue
		}
	}
}
