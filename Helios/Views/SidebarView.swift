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
	@State private var showingNewTabSheet = false
	@Query private var profiles: [Profile]
	
	var body: some View {
		VStack(spacing: 0) {
			// URL Bar
			URLBar(selectedTab: $selectedTab)
			
			Divider()
			
			if let workspace = selectedWorkspace {
				// Add new tab button
				Button(action: { showingNewTabSheet = true }) {
					Label("New Tab", systemImage: "plus.rectangle")
				}
				.buttonStyle(.bordered)
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// Pinned tabs section
				if let profile = workspace.profile {
					PinnedTabsSection(
						profile: profile,
						selectedTab: $selectedTab
					)
				}
				
				// Bookmark folders section
				BookmarkFoldersSection(
					workspace: workspace,
					selectedTab: $selectedTab
				)
				
				// Workspace tabs section
				WorkspaceTabsSection(
					workspace: workspace,
					selectedTab: $selectedTab
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
		.sheet(isPresented: $showingNewTabSheet) {
			if let workspace = selectedWorkspace {
				NewTabSheet(workspace: workspace)
			}
		}
	}
}

