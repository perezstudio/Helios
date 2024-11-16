//
//  PinnedTabsSection.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct PinnedTabsSection: View {
	let profile: Profile
	let workspace: Workspace
	@Binding var selectedTab: Tab?
	@Environment(\.modelContext) private var modelContext
	
	private let columns = [
		GridItem(.adaptive(minimum: 40, maximum: 40), spacing: 4)
	]
	
	var body: some View {
		Section {
			LazyVGrid(columns: columns, spacing: 4) {
				ForEach(profile.pinnedTabs) { tab in
					PinnedTabView(
						tab: tab,
						workspace: workspace,
						isSelected: selectedTab?.id == tab.id,
						onSelect: { selectTab(tab) },
						onClose: {
							if selectedTab?.id == tab.id {
								selectedTab = nil
							}
							
							// Clean up WebView
							WebViewStore.shared.remove(for: tab.id)
							profile.pinnedTabs.removeAll(where: { $0.id == tab.id })
							try? modelContext.save()
						}
					)
				}
			}
			.padding(8)
		}
	}
	
	private func selectTab(_ tab: Tab) {
		selectedTab = tab
		tab.lastVisited = Date()
		WebViewStore.shared.setActiveTab(tab.id)
		try? modelContext.save()
		
		// Post notification for tab selection
		NotificationCenter.default.post(
			name: .pinnedTabSelected,
			object: tab
		)
	}
}

extension Notification.Name {
	static let pinnedTabSelected = Notification.Name("pinnedTabSelected")
}
