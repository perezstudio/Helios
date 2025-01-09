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
    var pinnedTabs: [Tab] = []
    var bookmarkTabs: [Tab] = []
    var normalTabs: [Tab] = []
	var history: [HistoryItem] = []
    
	init(name: String, icon: String) {
        self.name = name
		self.icon = icon
    }
	
	func addTab(title: String, url: String, pinned: Bool = false, bookmark: Bool = false) {
		let tab = Tab(title: title, url: url, isPinned: pinned, isBookmark: bookmark)
		if pinned {
			pinnedTabs.append(tab)
		} else if bookmark {
			bookmarkTabs.append(tab)
		} else {
			normalTabs.append(tab)
		}
	}

	// Add to history
	func addHistoryItem(title: String, url: String) {
		let historyItem = HistoryItem(title: title, url: url)
		history.append(historyItem)
	}

	// Clear history
	func clearHistory() {
		history.removeAll()
	}
}
