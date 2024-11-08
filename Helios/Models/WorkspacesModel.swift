//
//  WorkspacesModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

@Model
final class Workspace {
	var id: UUID
	var name: String
	var iconName: String
	var bookmarkFolders: [BookmarkFolder]
	
	@Relationship(deleteRule: .cascade)
	var tabs: [Tab]
	
	@Relationship(inverse: \Profile.workspaces)
	var profile: Profile?
	
	init(name: String, iconName: String, profile: Profile? = nil) {
		self.id = UUID()
		self.name = name
		self.iconName = iconName
		self.bookmarkFolders = []
		self.tabs = []
		self.profile = profile
	}
}

// MARK: - Workspace Extension for Tab Management
extension Workspace {
	func createTab(title: String, url: URL) -> Tab {
		let tab = Tab(title: title, url: url, workspace: self)
		tabs.append(tab)
		return tab
	}
	
	func removeTab(_ tab: Tab) {
		tabs.removeAll(where: { $0.id == tab.id })
	}
	
	func moveTab(_ tab: Tab, to index: Int) {
		if let currentIndex = tabs.firstIndex(where: { $0.id == tab.id }) {
			let tab = tabs.remove(at: currentIndex)
			tabs.insert(tab, at: min(index, tabs.count))
		}
	}
}

// MARK: - Workspace Equatable Extension
extension Workspace: Equatable {
	static func == (lhs: Workspace, rhs: Workspace) -> Bool {
		lhs.id == rhs.id
	}
}
