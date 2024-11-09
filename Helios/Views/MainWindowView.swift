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
			.navigationTitle(selectedWorkspace?.name ?? "Browser")
			.toolbar {
				ToolbarItem(placement: .automatic) {
					NavigationControls(selectedTab: $selectedTab)
				}
			}
		} detail: {
			ZStack {
				if let tab = selectedTab {
					WebViewContainer(tab: tab, modelContext: modelContext)
				} else {
					EmptyStateView(
						workspace: selectedWorkspace,
						onCreateTab: { showingNewTabSheet = true }
					)
				}
			}
			.sheet(isPresented: $showingNewTabSheet) {
				if let workspace = selectedWorkspace {
					NewTabSheet(workspace: workspace) { newTab in
						selectedTab = newTab
					}
				}
			}
		}
		.sheet(isPresented: $showingNewProfileSheet) {
			NewProfileSheet()
				.onDisappear {
					// Select the newly created profile if no profile is selected
					if selectedProfile == nil, let lastProfile = profiles.last {
						selectedProfile = lastProfile
						if let firstWorkspace = lastProfile.workspaces.first {
							selectedWorkspace = firstWorkspace
						}
					}
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
}
