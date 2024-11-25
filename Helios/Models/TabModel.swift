//
//  TabModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// MARK: - Tab Model
@Model
final class Tab {
	var id: UUID
	var title: String
	private var urlString: String
	var favicon: Data?
	var lastVisited: Date?
	var isSecure: Bool
	var order: Int
	
	@Relationship(inverse: \Workspace.tabs)
	private var workspaceRelationship: Workspace?
	
	var url: URL {
		get {
			URL(string: urlString) ?? URL(string: "about:blank")!
		}
		set {
			// Only update URL if this tab isn't pinned
			if !isPinned {
				urlString = newValue.absoluteString
				isSecure = newValue.scheme?.lowercased() == "https"
			}
		}
	}
	
	var workspace: Workspace? {
		get { workspaceRelationship }
		set { workspaceRelationship = newValue }
	}
	
	var isPinned: Bool {
		workspace?.profile?.pinnedTabs.contains { $0.id == id } ?? false
	}
	
	init(title: String, url: URL, workspace: Workspace? = nil) {
		self.id = UUID()
		self.title = title
		self.urlString = url.absoluteString
		self.lastVisited = Date()
		self.workspaceRelationship = workspace
		self.isSecure = url.scheme?.lowercased() == "https"
		self.order = workspace?.tabs.count ?? 0
	}
	
	static func createNewTab(with url: URL, in workspace: Workspace) -> Tab {
		let newTab = Tab(title: url.host ?? "New Tab", url: url, workspace: workspace)
		workspace.tabs.append(newTab)
		newTab.order = workspace.tabs.count - 1  // Set order to end of list
		workspace.activeTabId = newTab.id
		return newTab
	}
	
	func pin() {
		if let profile = workspace?.profile {
			// Check if already pinned
			guard !isPinned else { return }
			
			// Store current state
			let currentURL = url
			let currentTitle = title
			let currentFavicon = favicon
			
			// Add to pinned tabs
			profile.pinnedTabs.append(self)
			
			// Remove from workspace tabs
			workspace?.removeTab(self)
			
			// Ensure state is preserved
			self.urlString = currentURL.absoluteString
			self.title = currentTitle
			self.favicon = currentFavicon
		}
	}
	
	func unpin() {
		if let profile = workspace?.profile,
		   let workspace = workspace {
			// Check if already unpinned
			guard isPinned else { return }
			
			// Store current state
			let currentURL = url
			let currentTitle = title
			let currentFavicon = favicon
			
			// Remove from pinned tabs
			profile.pinnedTabs.removeAll { $0.id == id }
			
			// Add back to workspace tabs
			if !workspace.tabs.contains(where: { $0.id == id }) {
				workspace.tabs.append(self)
			}
			
			// Ensure state is preserved
			self.urlString = currentURL.absoluteString
			self.title = currentTitle
			self.favicon = currentFavicon
		}
	}
}

// MARK: - Tab Transfer Data
struct TabTransferID: Transferable, Codable, Equatable {
	let id: UUID
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .tabID)
	}
}

extension UTType {
	static var tabID = UTType(exportedAs: "com.kevinperez.Helios.tab-id")
}

// MARK: - Transferable Implementation
extension Tab: Transferable {
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation<Tab, Data> { tab in
			// Encode just the ID for transfer
			try JSONEncoder().encode(tab.id)
		} importing: { data in
			// We'll never actually import, just use this as placeholder
			self.init(title: "", url: URL(string: "about:blank")!)
		}
	}
}

extension Tab: Equatable {
	static func == (lhs: Tab, rhs: Tab) -> Bool {
		lhs.id == rhs.id
	}
}

// MARK: - Tab Extension for Management
extension Tab {
	func moveTo(_ workspace: Workspace) {
		self.workspace?.removeTab(self)
		workspace.tabs.append(self)
		self.workspace = workspace
	}
	
	func close() {
		// Remove from pinned tabs if pinned
		if let profile = workspace?.profile {
			profile.pinnedTabs.removeAll { $0.id == id }
		}
		workspace?.removeTab(self)
	}
	
	func createBookmark(in folder: BookmarkFolder) {
		folder.bookmarks.append(self)
	}
}


