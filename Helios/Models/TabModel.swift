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
	
	@Relationship(inverse: \Workspace.tabs)
	private var workspaceRelationship: Workspace?
	
	var url: URL {
		get {
			URL(string: urlString) ?? URL(string: "about:blank")!
		}
		set {
			urlString = newValue.absoluteString
			// Update security status based on URL scheme
			isSecure = newValue.scheme?.lowercased() == "https"
		}
	}
	
	var workspace: Workspace? {
		get { workspaceRelationship }
		set { workspaceRelationship = newValue }
	}
	
	init(title: String, url: URL, workspace: Workspace? = nil) {
		self.id = UUID()
		self.title = title
		self.urlString = url.absoluteString
		self.lastVisited = Date()
		self.workspaceRelationship = workspace
		self.isSecure = url.scheme?.lowercased() == "https"
	}
}

// MARK: - Tab Transfer Data
struct TabTransferID: Transferable, Codable {
	let id: UUID
	
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .tabID)
	}
}

extension UTType {
	static var tabID: UTType {
		UTType(exportedAs: "com.yourdomain.tab-id")
	}
}

// MARK: - Transferable Implementation
extension Tab: Transferable {
	static var transferRepresentation: some TransferRepresentation {
		ProxyRepresentation<Tab, TabTransferID>(
			exporting: { tab in
				TabTransferID(id: tab.id)
			}
		)
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
		workspace?.removeTab(self)
	}
	
	func createBookmark(in folder: BookmarkFolder) {
		folder.bookmarks.append(self)
	}
}

