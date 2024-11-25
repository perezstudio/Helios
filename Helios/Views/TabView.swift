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
	
	private func isTabVisible(_ tab: Tab) -> Bool {
		selectedTab?.id == tab.id
	}
	
	private func visibilityBinding(for tab: Tab) -> Binding<Bool> {
		Binding(
			get: { isTabVisible(tab) },
			set: { _ in selectTab(tab) }
		)
	}
	
	private var emptyStateView: some View {
		EmptyStateView(
			workspace: workspace,
			onCreateTab: {
				if let firstTab = workspace.tabs.first {
					selectTab(firstTab)
				}
			}
		)
	}
	
	private var regularTabsView: some View {
		ForEach(workspace.tabs) { tab in
			WebViewContainer(
				tab: tab,
				modelContext: modelContext,
				isVisible: visibilityBinding(for: tab)
			)
			.opacity(isTabVisible(tab) ? 1 : 0)
		}
	}
	
	private var pinnedTabsView: some View {
		Group {
			if let profile = workspace.profile {
				ForEach(profile.pinnedTabs) { tab in
					WebViewContainer(
						tab: tab,
						modelContext: modelContext,
						isVisible: visibilityBinding(for: tab)
					)
					.opacity(isTabVisible(tab) ? 1 : 0)
				}
			}
		}
	}
	
	var body: some View {
		ZStack {
			if selectedTab == nil {
				emptyStateView
			}
			regularTabsView
			pinnedTabsView
		}
		.onChange(of: selectedTab) { oldValue, newValue in
			if let tab = newValue {
				workspace.activeTabId = tab.id
				tab.lastVisited = Date()
				WebViewStore.shared.setActiveTab(tab.id)
				try? modelContext.save()
			}
		}
		.onAppear {
			if selectedTab == nil {
				if let activeId = workspace.activeTabId,
				   let activeTab = workspace.tabs.first(where: { $0.id == activeId }) {
					selectTab(activeTab)
				} else if let firstTab = workspace.tabs.first {
					selectTab(firstTab)
				}
			}
		}
	}
	
	private func selectTab(_ tab: Tab) {
		selectedTab = tab
		workspace.activeTabId = tab.id
		tab.lastVisited = Date()
		WebViewStore.shared.setActiveTab(tab.id)
		try? modelContext.save()
	}
}
