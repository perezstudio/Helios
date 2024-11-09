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
	
	var body: some View {
		VStack(spacing: 0) {
			// URL Bar
			URLBar(selectedTab: $selectedTab)
			
			Divider()
			
			if let workspace = selectedWorkspace,
			   let profile = workspace.profile {
				// Pinned tabs section
				PinnedTabsSection(
					profile: profile,
					workspace: workspace,
					selectedTab: $selectedTab
				)
				
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
	}
}
