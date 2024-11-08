//
//  WorkspaceTabsSection.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct WorkspaceTabsSection: View {
	let workspace: Workspace
	@Binding var selectedTab: Tab?
	
	var body: some View {
		Section("Tabs") {
			ScrollView {
				LazyVStack(spacing: 2) {
					ForEach(workspace.tabs) { tab in
						TabRow(
							tab: tab,
							isSelected: selectedTab?.id == tab.id
						)
						.onTapGesture {
							selectedTab = tab
						}
					}
				}
				.padding(.vertical, 2)
			}
		}
	}
}
