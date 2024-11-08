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
	@Binding var selectedTab: Tab?
	
	var body: some View {
		Section("Pinned") {
			ScrollView(.horizontal, showsIndicators: false) {
				LazyHStack(spacing: 8) {
					ForEach(profile.pinnedTabs) { tab in
						PinnedTabView(
							tab: tab,
							isSelected: tab.id == selectedTab?.id
						)
						.onTapGesture {
							selectedTab = tab
						}
					}
				}
				.padding(.horizontal, 12)
				.padding(.vertical, 4)
			}
			.frame(height: 56)
		}
	}
}
