//
//  BookmarkFoldersSection.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct BookmarkFoldersSection: View {
	let workspace: Workspace
	@Binding var selectedTab: Tab?
	@State private var expandedFolders: Set<UUID> = []
	@State private var showingNewFolderSheet = false
	@Environment(\.modelContext) private var modelContext
	@State private var pendingTabID: UUID?
	
	var body: some View {
		Section {
			VStack(spacing: 0) {
				// Section header with add button
				HStack {
					Text("Bookmarks")
					Spacer()
					Button(action: { showingNewFolderSheet = true }) {
						Image(systemName: "plus")
					}
					.buttonStyle(.plain)
				}
				.padding(.horizontal)
				.padding(.vertical, 8)
				
				// Existing folders
				List {
					ForEach(workspace.bookmarkFolders) { folder in
						BookmarkFolderView(
							folder: folder,
							isExpanded: expandedFolders.contains(folder.id),
							onToggleExpanded: { isExpanded in
								if isExpanded {
									expandedFolders.insert(folder.id)
								} else {
									expandedFolders.remove(folder.id)
								}
							},
							selectedTab: $selectedTab
						)
					}
				}
				
				// Create New Folder Drop Zone
				NewFolderDropZone(
					isTargeted: false,
					onDrop: { tabID in
						pendingTabID = tabID.id
						showingNewFolderSheet = true
						return true
					}
				)
			}
		}
		.sheet(isPresented: $showingNewFolderSheet) {
			NewBookmarkFolderSheet(
				workspace: workspace,
				pendingTabID: pendingTabID,
				isPresented: $showingNewFolderSheet
			)
		}
		// Handle selection of bookmarked tabs
		.onReceive(NotificationCenter.default.publisher(for: .selectBookmarkedTab)) { notification in
			if let tab = notification.object as? Tab {
				selectedTab = tab
			}
		}
	}
}
