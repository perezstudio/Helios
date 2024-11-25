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
	let onCreateTab: (Tab) -> Void
	@State private var showingProfileChangeSheet = false
	@State private var showingNewTabSheet = false
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		Section {
			VStack(spacing: 0) {
				// Workspace Header
				HStack {
					HStack(spacing: 8) {
						Image(systemName: workspace.iconName)
							.font(.system(size: 16))
						Text(workspace.name)
							.font(.headline)
					}
					
					Spacer()
					
					Menu {
						Button("Change Profile") {
							showingProfileChangeSheet = true
						}
					} label: {
						Image(systemName: "ellipsis")
							.frame(width: 24, height: 24)
							.contentShape(Rectangle())
					}
					.menuStyle(.borderlessButton)
				}
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// Tabs List
				ScrollView {
					LazyVStack(spacing: 2) {
						NewTabRow(showingNewTabSheet: $showingNewTabSheet)
							.padding(.bottom, 2)
						
						ForEach(workspace.orderedTabs) { tab in
							DraggableTabRow(
								tab: tab,
								isSelected: selectedTab?.id == tab.id,
								workspace: workspace,
								onSelect: { selectTab(tab) },
								onClose: { closeTab(tab) }
							)
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
		.sheet(isPresented: $showingProfileChangeSheet) {
			ChangeProfileSheet(workspace: workspace)
		}
		.sheet(isPresented: $showingNewTabSheet) {
			NewTabSheet(workspace: workspace)
		}
		.onChange(of: workspace.tabs) { oldValue, newValue in
			if let currentTab = selectedTab,
			   !newValue.contains(where: { $0.id == currentTab.id }) {
				selectedTab = nil
			}
		}
	}
	
	private func selectTab(_ tab: Tab) {
		selectedTab = tab
		workspace.activeTabId = tab.id
		tab.lastVisited = Date()
		try? modelContext.save()
	}
	
	private func closeTab(_ tab: Tab) {
		if selectedTab?.id == tab.id {
			// Find the next tab to select
			if let index = workspace.orderedTabs.firstIndex(where: { $0.id == tab.id }) {
				if index > 0 {
					selectedTab = workspace.orderedTabs[index - 1]
				} else if workspace.orderedTabs.count > 1 {
					selectedTab = workspace.orderedTabs[1]
				} else {
					selectedTab = nil
				}
			}
		}
		
		// Close the tab
		WebViewStore.shared.remove(for: tab.id)
		workspace.removeTab(tab)
		try? modelContext.save()
	}
}

