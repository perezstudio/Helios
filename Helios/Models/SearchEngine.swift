//
//  SearchEngine.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//


import SwiftUI
import SwiftData

@Model
class SearchEngine {
	var id: UUID
	var name: String
	var shortcut: String
	var searchUrl: String
	var isBuiltIn: Bool
	@Relationship(inverse: \Profile.defaultSearchEngine) var profiles: [Profile]?
	
	init(name: String, shortcut: String, searchUrl: String, isBuiltIn: Bool = false) {
		self.id = UUID()
		self.name = name
		self.shortcut = shortcut
		self.searchUrl = searchUrl
		self.isBuiltIn = isBuiltIn
		self.profiles = []
	}
	
	static var defaultEngines: [SearchEngine] = [
		SearchEngine(
			name: "Google",
			shortcut: "google.com",
			searchUrl: "https://www.google.com/search?q=%s",
			isBuiltIn: true
		),
		SearchEngine(
			name: "Bing",
			shortcut: "bing.com",
			searchUrl: "https://www.bing.com/search?q=%s",
			isBuiltIn: true
		),
		SearchEngine(
			name: "Yahoo",
			shortcut: "yahoo.com",
			searchUrl: "https://search.yahoo.com/search?p=%s",
			isBuiltIn: true
		)
	]
}
