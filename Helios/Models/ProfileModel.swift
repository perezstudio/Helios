//
//  ProfileModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

@Model
final class Profile {
	var id: UUID
	var name: String
	@Relationship(deleteRule: .cascade)
	var workspaces: [Workspace]
	var pinnedTabs: [Tab]
	var browsingHistory: [BrowsingHistoryEntry]
	
	init(name: String) {
		self.id = UUID()
		self.name = name
		self.workspaces = []
		self.pinnedTabs = []
		self.browsingHistory = []
	}
	
	func addToHistory(url: URL, title: String) {
		let entry = BrowsingHistoryEntry(url: url, title: title, visitDate: Date())
		browsingHistory.append(entry)
		
		// Keep history at a reasonable size
		if browsingHistory.count > 1000 {
			browsingHistory.removeFirst(browsingHistory.count - 1000)
		}
	}
	
	func clearBrowsingData() {
		// Clear history
		browsingHistory.removeAll()
		
		// Clear website data for this profile
		Task {
			await clearWebsiteData()
		}
	}
	
	private func clearWebsiteData() async {
		let dataTypes = Set([WKWebsiteDataTypeDiskCache,
						   WKWebsiteDataTypeMemoryCache,
						   WKWebsiteDataTypeCookies])
		
		let dataStore = WKWebsiteDataStore.default()
		let records = await dataStore.dataRecords(ofTypes: dataTypes)
		
		// Clear all website data
		await dataStore.removeData(ofTypes: dataTypes, for: records)
	}
}
