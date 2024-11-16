//
//  MainWindowView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct MainWindowView: View {
	@Environment(\.modelContext) private var modelContext
	@Query private var profiles: [Profile]
	@State private var selectedProfile: Profile?
	@State private var selectedWorkspace: Workspace?
	@State private var selectedTab: Tab?
	@State private var showingNewTabSheet = false
	@State private var showingNewProfileSheet = false
	
	var body: some View {
		NavigationSplitView {
			SidebarView(
				selectedProfile: $selectedProfile,
				selectedWorkspace: $selectedWorkspace,
				selectedTab: $selectedTab
			)
		} detail: {
			if let workspace = selectedWorkspace {
				TabView(
					workspace: workspace,
					selectedTab: $selectedTab
				)
				.navigationTitle(workspace.name)
				.toolbar {
					ToolbarItemGroup(placement: .automatic) {
						NavigationControls(selectedTab: $selectedTab)
					}
				}
			} else {
				EmptyStateView(
					workspace: nil,
					onCreateTab: {}
				)
				.navigationTitle("Browser")
			}
		}
		.sheet(isPresented: $showingNewTabSheet) {
			if let workspace = selectedWorkspace {
				NewTabSheet(workspace: workspace) { newTab in
					selectTab(newTab)
				}
			}
		}
		.sheet(isPresented: $showingNewProfileSheet) {
			NewProfileSheet()
				.onDisappear {
					if selectedProfile == nil, let lastProfile = profiles.last {
						selectProfile(lastProfile)
					}
				}
		}
		.onReceive(NotificationCenter.default.publisher(for: .newTabCreated)) { notification in
			if let newTab = notification.object as? Tab {
				selectTab(newTab)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .selectBookmarkedTab)) { notification in
			if let tab = notification.object as? Tab {
				selectTab(tab)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .selectPinnedTab)) { notification in
			if let tab = notification.object as? Tab {
				selectTab(tab)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .openNewTab)) { _ in
			if selectedWorkspace != nil {
				showingNewTabSheet = true
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .openNewProfile)) { _ in
			showingNewProfileSheet = true
		}
	}
	
	private func selectTab(_ tab: Tab) {
		if let workspace = tab.workspace {
			selectedWorkspace = workspace
			selectedProfile = workspace.profile
		}
		selectedTab = tab
		tab.lastVisited = Date()
		try? modelContext.save()
	}
	
	private func selectProfile(_ profile: Profile) {
		selectedProfile = profile
		selectedWorkspace = profile.workspaces.first
		if let workspace = selectedWorkspace {
			if let activeId = workspace.activeTabId,
			   let activeTab = workspace.tabs.first(where: { $0.id == activeId }) {
				selectedTab = activeTab
			} else {
				selectedTab = workspace.tabs.first
			}
		}
	}
}
