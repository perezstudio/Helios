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
						onSelect: {
							selectedTab = tab
						},
						onClose: {
							if selectedTab?.id == tab.id {
								selectedTab = nil
							}
						}
					)
				}
			}
			.padding(8)
		}
	}
}
