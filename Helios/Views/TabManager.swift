//
//  TabManager.swift
//  Helios
//
//  Created by Kevin Perez on 11/12/24.
//

import SwiftUI
import SwiftData

class TabManager: ObservableObject {
	// Your properties remain the same

	@Published var selectedWorkspace: Workspace?
	@Published var selectedTab: Tab?

	func selectTab(_ tab: Tab) {
		// Your existing code remains the same

		self.selectedTab = tab

		// Add this code to maintain the selected workspace
		if let workspace = workspaces.first(where: { $0.tabs.contains(tab) }) {
			self.selectedWorkspace = workspace
		}

		// Your existing code for updating the UI remains the same
	}

	// The rest of your TabManager implementation remains the same
}

// End of file. No additional code.
