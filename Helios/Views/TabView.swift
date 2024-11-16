//
//  TabView.swift
//  Helios
//
//  Created by Kevin Perez on 11/14/24.
//
import SwiftUI
import SwiftData

struct TabView: View {
	let workspace: Workspace
	@Binding var selectedTab: Tab?
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		ZStack {
			// Empty state when no tab is selected
			if selectedTab == nil {
				EmptyStateView(
					workspace: workspace,
					onCreateTab: {
						if let firstTab = workspace.tabs.first {
							selectTab(firstTab)
						}
					}
				)
			}
			
			// WebViews for regular tabs
			ForEach(workspace.tabs) { tab in
				WebViewContainer(
					tab: tab,
					modelContext: modelContext,
					isVisible: Binding(
						get: { selectedTab?.id == tab.id },
						set: { isVisible in
							if isVisible {
								selectTab(tab)
							}
						}
					)
				)
				.zIndex(selectedTab?.id == tab.id ? 1 : 0)
				.opacity(selectedTab?.id == tab.id ? 1 : 0)
			}
			
			// WebViews for pinned tabs
			if let profile = workspace.profile {
				ForEach(profile.pinnedTabs) { tab in
					WebViewContainer(
						tab: tab,
						modelContext: modelContext,
						isVisible: Binding(
							get: { selectedTab?.id == tab.id },
							set: { isVisible in
								if isVisible {
									selectTab(tab)
								}
							}
						)
					)
					.zIndex(selectedTab?.id == tab.id ? 2 : 0)  // Higher zIndex for pinned tabs
					.opacity(selectedTab?.id == tab.id ? 1 : 0)
				}
			}
		}
		.onChange(of: selectedTab) { oldValue, newValue in
			if let tab = newValue {
				tab.lastVisited = Date()
				WebViewStore.shared.setActiveTab(tab.id)
				try? modelContext.save()
			}
		}
		.onAppear {
			// Set initial tab if needed
			if selectedTab == nil {
				if let activeId = workspace.activeTabId,
				   let activeTab = workspace.tabs.first(where: { $0.id == activeId }) {
					selectTab(activeTab)
				} else if let firstTab = workspace.tabs.first {
					selectTab(firstTab)
				}
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .pinnedTabSelected)) { notification in
			if let tab = notification.object as? Tab {
				selectTab(tab)
			}
		}
	}
	
	private func selectTab(_ tab: Tab) {
		selectedTab = tab
		WebViewStore.shared.setActiveTab(tab.id)
		tab.lastVisited = Date()
		try? modelContext.save()
	}
}
