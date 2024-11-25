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
				List {
					NewTabRow(showingNewTabSheet: $showingNewTabSheet)
						.listRowInsets(EdgeInsets())
						.listRowBackground(Color.clear)
					
					ForEach(workspace.orderedTabs) { tab in
						TabRow(
							tab: tab,
							isSelected: selectedTab?.id == tab.id,
							onSelect: { selectTab(tab) },
							onClose: { closeTab(tab) }
						)
						.listRowInsets(EdgeInsets())
						.listRowBackground(Color.clear)
						.contentShape(Rectangle())  // Make entire row draggable
					}
					.onMove { from, to in
						guard let fromIndex = from.first else { return }
						workspace.moveTab(workspace.orderedTabs[fromIndex], to: to)
						try? modelContext.save()
					}
				}
				.listStyle(.plain)
				.environment(\.defaultMinListRowHeight, 0)
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
		
		WebViewStore.shared.remove(for: tab.id)
		workspace.removeTab(tab)
		try? modelContext.save()
	}
}

