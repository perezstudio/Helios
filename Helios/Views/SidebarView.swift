//
//  SidebarView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

struct SidebarView: View {
	@Environment(\.modelContext) var modelContext
	@Binding var selectedWorkspace: Workspace?   // Selected workspace
	@Query var workspaces: [Workspace]
	@ObservedObject var webService: WebNavigationService // Shared web service

	@State private var createWorkspaceSheet: Bool = false // Controls workspace creation sheet
	@Binding var selectedTab: Tab? // Use Bindable for dynamic updates
	@State private var tempURL: String = "" // Temporary URL field for editing

	var body: some View {
		VStack {
			// Tabs Section
			List {
				// Pinned Tabs
				Section(header: Text("Pinned Tabs")) {
					ForEach(selectedWorkspace?.pinnedTabs ?? []) { tab in
						TabView(selectedTab: $selectedTab, tab: tab)
							.onTapGesture { selectTab(tab) }
					}
				}

				// Bookmarked Tabs
				Section(header: Text("Bookmarks")) {
					ForEach(selectedWorkspace?.bookmarkTabs ?? []) { tab in
						TabView(selectedTab: $selectedTab, tab: tab)
							.onTapGesture { selectTab(tab) }
					}
				}

				// Normal Tabs
				Section(header: Text("Tabs")) {
					// Button to create a new tab with default values
					Button {
						addNewTab()
					} label: {
						Label("New Tab", systemImage: "plus")
					}

					ForEach(selectedWorkspace?.normalTabs ?? []) { tab in
						TabView(selectedTab: $selectedTab, tab: tab)
							.onTapGesture {
								selectedTab = tab
								print(tab.url)
								print(tab.title)
							}
					}
				}
			}

			// Workspace Switcher
			HStack {
				Picker("", selection: $selectedWorkspace) {
					ForEach(workspaces) { workspace in
						Image(systemName: workspace.icon).tag(workspace as Workspace?)
					}
				}
				.pickerStyle(.segmented)

				// Create Workspace Button
				Button {
					createWorkspaceSheet.toggle()
				} label: {
					Label("Create Workspace", systemImage: "plus.app")
						.labelStyle(.iconOnly)
				}
			}
			.padding(.vertical)
			.padding(.trailing, 8)
		}
		.frame(minWidth: 250)
		.sheet(isPresented: $createWorkspaceSheet) {
			CreateWorkspaceView()
		}
	}

	// MARK: - Add New Tab
	private func addNewTab() {
		guard let workspace = selectedWorkspace else { return }

		// Create a new tab with default URL and title
		let newTab = Tab(title: "New Tab", url: "https://www.google.com")
		workspace.normalTabs.append(newTab)

		// Persist changes
		saveContext()

		// Select the new tab and load it
		selectTab(newTab)
	}

	// MARK: - Select Tab
	private func selectTab(_ tab: Tab) {
		print("Selecting tab with title: \(tab.title), URL: \(tab.url)")
		print("Current web view URL: \(tab.webService.url)")
		// Update selected tab and reload if necessary
		selectedTab = tab
		if tab.webService.url != tab.url {
			tab.webService.loadURL(tab.url)
		}
	}

	// MARK: - Save Context
	private func saveContext() {
		do {
			try modelContext.save()
		} catch {
			print("Failed to save context: \(error)")
		}
	}
}
