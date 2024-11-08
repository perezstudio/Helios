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
			if let tab = selectedTab {
				WebViewContainer(tab: tab)
			} else {
				ContentUnavailableView("Select a tab",
					systemImage: "globe")
			}
		}
	}
}
