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
	var activeTabId: UUID?
	
	@Relationship(deleteRule: .cascade)
	var tabs: [Tab]
	
	@Relationship(inverse: \Profile.workspaces)
	var profile: Profile?
	
	var context: ModelContext? {
		modelContext
	}
	
	init(name: String, iconName: String, profile: Profile? = nil) {
		self.id = UUID()
		self.name = name
		self.iconName = iconName
		self.bookmarkFolders = []
		self.tabs = []
		self.profile = profile
		self.activeTabId = nil
	}
	
	var activeTab: Tab? {
		guard let activeId = activeTabId else { return nil }
		return tabs.first { $0.id == activeId }
	}
}

// MARK: - Workspace Extension for Tab Management
extension Workspace {
	func createTab(title: String, url: URL) -> Tab {
		let tab = Tab(title: title, url: url, workspace: self)
		tabs.append(tab)
		// Set as active tab when created
		activeTabId = tab.id
		return tab
	}
	
	func removeTab(_ tab: Tab) {
		tabs.removeAll(where: { $0.id == tab.id })
		// Clear active tab if removed
		if activeTabId == tab.id {
			activeTabId = tabs.first?.id
		}
	}
	
	var orderedTabs: [Tab] {
		tabs.sorted { $0.order < $1.order }
	}
	
	func moveTab(_ tab: Tab, to newIndex: Int) {
		// Get current ordered tabs
		let currentTabs = orderedTabs
		let oldIndex = currentTabs.firstIndex(of: tab) ?? 0
		
		// Only proceed if the indices are different
		guard oldIndex != newIndex else { return }
		
		// If moving forward, decrement orders of tabs in between
		if newIndex > oldIndex {
			for i in (oldIndex + 1)...newIndex {
				currentTabs[i].order -= 1
			}
		}
		// If moving backward, increment orders of tabs in between
		else {
			for i in newIndex..<oldIndex {
				currentTabs[i].order += 1
			}
		}
		
		// Set new order for moved tab
		tab.order = newIndex
		
		try? context?.save()
	}
	
	func reorderTabs() {
		// Reset all tab orders to match current array order
		for (index, tab) in orderedTabs.enumerated() {
			tab.order = index
		}
		try? context?.save()
	}
	
	func openLinkInNewTab(_ url: URL) {
		let newTab = Tab.createNewTab(with: url, in: self)
		self.activeTabId = newTab.id
		try? context?.save()
		
		// Post notification to select the new tab
		NotificationCenter.default.post(
			name: .selectNewTab,
			object: SelectTabRequest(workspace: self, tab: newTab)
		)
	}
}

// MARK: - Workspace Equatable Extension
extension Workspace: Equatable {
	static func == (lhs: Workspace, rhs: Workspace) -> Bool {
		lhs.id == rhs.id
	}
}
