//
//  Tab.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData
import WebKit

@Model
class Tab {
	var id: UUID = UUID()
	var title: String
	var url: String
	var type: TabType
	var workspace: Workspace?
	var faviconData: Data?
	var webViewId: UUID?
	var bookmarkedUrl: String?
	
	// Add an explicit order field to maintain proper tab ordering
	var displayOrder: Int = 0
	
	var profile: Profile? {
		workspace?.profile
	}
	
	init(title: String, url: String, type: TabType, workspace: Workspace? = nil, displayOrder: Int = 0) {
		self.id = UUID()
		self.title = title
		self.url = url
		self.type = type
		self.workspace = workspace
		self.faviconData = nil
		self.webViewId = UUID()
		self.displayOrder = displayOrder
		if type == .bookmark {
			self.bookmarkedUrl = url
		}
	}
	
	var originalUrl: String {
		if type == .bookmark {
			return bookmarkedUrl ?? url
		}
		return url
	}
}
