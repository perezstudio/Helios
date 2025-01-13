//
//  Workspace.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

@Model
class Workspace {
	var id: UUID = UUID()
	var name: String
	var icon: String
	var color: String = ""
	var colorTheme: ColorTheme = ColorTheme.blue
	var tabs: [Tab] = []
	var profile: Profile?
	
	init(name: String, icon: String, colorTheme: ColorTheme = ColorTheme.blue) {  // Added default parameter
		self.name = name
		self.icon = icon
		self.colorTheme = colorTheme
	}
}
