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
	@State private var showingSettings = false
	
	var body: some View {
		NavigationSplitView {
			SidebarView(
				selectedProfile: $selectedProfile,
				selectedWorkspace: $selectedWorkspace,
				selectedTab: $selectedTab
			)
		} detail: {
			Group {
				if let workspace = selectedWorkspace {
					TabView(
						workspace: workspace,
						selectedTab: $selectedTab
					)
				} else {
					EmptyStateView(
						workspace: nil,
						onCreateTab: {}
					)
				}
			}
			.navigationTitle(selectedWorkspace?.name ?? "Browser")
			.toolbar {
				ToolbarItem(placement: .automatic) {
					HStack(spacing: 12) {
						NavigationControls(selectedTab: $selectedTab)
						
						Button(action: { showingSettings = true }) {
							Image(systemName: "gear")
								.frame(width: 24, height: 24)
						}
						.buttonStyle(.borderless)
					}
				}
			}
		}
		.sheet(isPresented: $showingNewTabSheet) {
			if let workspace = selectedWorkspace {
				NewTabSheet(workspace: workspace)
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
		.sheet(isPresented: $showingSettings) {
			SettingsView()
		}
		.onReceive(NotificationCenter.default.publisher(for: .selectNewTab)) { notification in
			if let request = notification.object as? SelectTabRequest {
				selectedWorkspace = request.workspace
				selectedProfile = request.workspace.profile
				selectedTab = request.tab
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
	
	private func selectProfile(_ profile: Profile) {
		selectedProfile = profile
		if let firstWorkspace = profile.workspaces.first {
			selectedWorkspace = firstWorkspace
			if let activeId = firstWorkspace.activeTabId,
			   let activeTab = firstWorkspace.tabs.first(where: { $0.id == activeId }) {
				selectedTab = activeTab
			} else if let firstTab = firstWorkspace.tabs.first {
				selectedTab = firstTab
			}
		}
	}
}
