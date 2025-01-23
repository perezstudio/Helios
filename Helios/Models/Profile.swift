//
//  Profile.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

@Model
class Profile {
	@Attribute(.unique) var id: UUID
	var name: String
	var pinnedTabs: [Tab]  // Direct relationship for pinned tabs
	var workspaces: [Workspace]
	var history: [HistoryEntry]
	@Relationship(deleteRule: .nullify) var defaultSearchEngine: SearchEngine?
	
	init(name: String) {
		self.id = UUID()
		self.name = name
		self.pinnedTabs = []
		self.workspaces = []
		self.history = []
		self.defaultSearchEngine = nil
	}
}
