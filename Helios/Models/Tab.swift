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
	
	init(title: String, url: String, type: TabType, workspace: Workspace? = nil) {
		self.id = UUID()
		self.title = title
		self.url = url
		self.type = type
		self.workspace = workspace
	}
}


