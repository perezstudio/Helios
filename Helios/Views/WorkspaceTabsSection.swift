//
//  WorkspaceTabsSection.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct WorkspaceTabsSection: View {
	let workspace: Workspace
	@Binding var selectedTab: Tab?
	@State private var showingProfileChangeSheet = false
	@State private var showingNewTabSheet = false
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		Section {
			VStack(spacing: 0) {
				// Workspace Header
				HStack {
					// Workspace icon and name
					HStack(spacing: 8) {
						Image(systemName: workspace.iconName)
							.font(.system(size: 16))
						Text(workspace.name)
							.font(.headline)
					}
					
					Spacer()
					
					// Settings Menu
					Menu {
						Button("Change Profile") {
							showingProfileChangeSheet = true
						}
					} label: {
						Image(systemName: "ellipsis")
							.frame(width: 24, height: 24)
							.contentShape(Rectangle())
					}
					.menuStyle(.borderlessButton)
				}
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// Tabs List
				ScrollView {
					LazyVStack(spacing: 2) {
						// New Tab Button
						NewTabRow(showingNewTabSheet: $showingNewTabSheet)
							.padding(.bottom, 2)
						
						// Existing Tabs
						ForEach(workspace.tabs) { tab in
							TabRow(
								tab: tab,
								isSelected: selectedTab?.id == tab.id,
								onSelect: { selectedTab = tab },
								onClose: {
									if selectedTab?.id == tab.id {
										selectedTab = nil
									}
								}
							)
						}
					}
					.padding(.vertical, 2)
				}
			}
		}
		.sheet(isPresented: $showingProfileChangeSheet) {
			ChangeProfileSheet(workspace: workspace)
		}
		.sheet(isPresented: $showingNewTabSheet) {
			NewTabSheet(workspace: workspace) { newTab in
				selectedTab = newTab
			}
		}
	}
}
