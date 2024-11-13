//
//  SidebarView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
	@Binding var selectedProfile: Profile?
	@Binding var selectedWorkspace: Workspace?
	@Binding var selectedTab: Tab?
	@State private var showingNewWorkspaceSheet = false
	@Query private var profiles: [Profile]
	
	private func selectTab(_ tab: Tab) {
		// Ensure proper state update order
		if tab.workspace !== selectedWorkspace {
			selectedWorkspace = tab.workspace
		}
		selectedTab = tab
		
		// Update last visited time
		tab.lastVisited = Date()
		try? tab.modelContext?.save()
	}
	
	var body: some View {
		VStack(spacing: 0) {
			// URL Bar
			URLBar(
				selectedTab: Binding(
					get: { selectedTab },
					set: { newTab in
						if let tab = newTab {
							selectTab(tab)
						} else {
							selectedTab = nil
						}
					}
				)
			)
			
			Divider()
			
			if let workspace = selectedWorkspace,
			   let profile = workspace.profile {
				// Pinned tabs section
				PinnedTabsSection(
					profile: profile,
					workspace: workspace,
					selectedTab: Binding(
						get: { selectedTab },
						set: { newTab in
							if let tab = newTab {
								selectTab(tab)
							} else {
								selectedTab = nil
							}
						}
					)
				)
				
				// Bookmark folders section
				BookmarkFoldersSection(
					workspace: workspace,
					selectedTab: Binding(
						get: { selectedTab },
						set: { newTab in
							if let tab = newTab {
								selectTab(tab)
							} else {
								selectedTab = nil
							}
						}
					)
				)
				
				// Workspace tabs section
				WorkspaceTabsSection(
					workspace: workspace,
					selectedTab: Binding(
						get: { selectedTab },
						set: { newTab in
							if let tab = newTab {
								selectTab(tab)
							} else {
								selectedTab = nil
							}
						}
					),
					onCreateTab: { newTab in
						selectTab(newTab)
					}
				)
			}
			
			Spacer()
			
			// Workspace indicator and new workspace button
			HStack {
				AllWorkspacesPageControl(
					selectedWorkspace: $selectedWorkspace
				)
				
				Button(action: { showingNewWorkspaceSheet = true }) {
					Image(systemName: "plus")
				}
			}
			.padding()
		}
		.sheet(isPresented: $showingNewWorkspaceSheet) {
			NewWorkspaceSheet()
		}
		// Handle workspace changes
		.onChange(of: selectedWorkspace) { oldValue, newValue in
			// If workspace changed and current tab isn't in new workspace, clear selection
			if let currentTab = selectedTab,
			   currentTab.workspace !== newValue {
				selectedTab = nil
			}
		}
		// Handle profile changes
		.onChange(of: selectedProfile) { oldValue, newValue in
			// If profile changed and current workspace isn't in new profile, clear selection
			if let currentWorkspace = selectedWorkspace,
			   currentWorkspace.profile !== newValue {
				selectedWorkspace = newValue?.workspaces.first
				selectedTab = nil
			}
		}
	}
}
