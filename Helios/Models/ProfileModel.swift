//
//  ProfileModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

@Model
final class Profile {
	var id: UUID
	var name: String
	@Relationship(deleteRule: .cascade)
	var workspaces: [Workspace]
	var pinnedTabs: [Tab]
	
	init(name: String) {
		self.id = UUID()
		self.name = name
		self.workspaces = []
		self.pinnedTabs = []
	}
}
