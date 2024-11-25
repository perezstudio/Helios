//
//  TabRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

struct TabRow: View {
	let tab: Tab
	let isSelected: Bool
	let onSelect: () -> Void
	let onClose: (() -> Void)?
	@Environment(\.modelContext) private var modelContext
	
	private func closeTab() {
		// Clean up the WebView
		WebViewStore.shared.remove(for: tab.id)
		
		// Close the tab
		tab.close()
		try? modelContext.save()
		
		// Call the onClose callback if provided
		onClose?()
	}
	
	private func bookmarkTab(in folder: BookmarkFolder) {
		// Create the bookmark
		tab.createBookmark(in: folder)
		
		// Clean up the original tab
		WebViewStore.shared.remove(for: tab.id)
		tab.workspace?.removeTab(tab)
		
		// Save changes
		try? modelContext.save()
		
		// Switch to the bookmarked version
		NotificationCenter.default.post(
			name: .selectBookmarkedTab,
			object: tab
		)
	}
	
	private func pinTab() {
		if let workspace = tab.workspace,
		   let profile = workspace.profile {
			// Remove from workspace tabs
			workspace.removeTab(tab)
			
			// Add to pinned tabs
			profile.pinnedTabs.append(tab)
			
			try? modelContext.save()
			
			// Switch to the pinned version
			NotificationCenter.default.post(
				name: .selectPinnedTab,
				object: tab
			)
		}
	}
	
	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 12) {
				Group {
					if let favicon = tab.favicon,
					   let image = NSImage(data: favicon) {
						Image(nsImage: image)
							.resizable()
							.frame(width: 16, height: 16)
					} else {
						Image(systemName: "globe")
							.frame(width: 16, height: 16)
					}
				}
				
				Text(tab.title)
					.lineLimit(1)
					.truncationMode(.middle)
				
				Spacer()
				
				if isSelected {
					Button(action: closeTab) {
						Image(systemName: "xmark")
							.foregroundColor(.secondary)
					}
					.buttonStyle(.plain)
					.frame(width: 16, height: 16)
				}
			}
		}
		.buttonStyle(.plain)
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
		)
		.contentShape(Rectangle())  // Make entire row interactive for drag and tap
		.contextMenu {
			if let workspace = tab.workspace {
				Button("Pin Tab") {
					pinTab()
				}
				
				Divider()
				
				ForEach(workspace.bookmarkFolders) { folder in
					Button("Save to \(folder.name)") {
						bookmarkTab(in: folder)
					}
				}
				
				if !workspace.bookmarkFolders.isEmpty {
					Divider()
				}
				
				Button("Create New Folder & Save") {
					let newFolder = BookmarkFolder(name: "New Folder")
					workspace.bookmarkFolders.append(newFolder)
					bookmarkTab(in: newFolder)
				}
			}
		}
		.draggable(TabTransferID(id: tab.id)) {
			// Preview
			HStack(spacing: 12) {
				Group {
					if let favicon = tab.favicon,
					   let image = NSImage(data: favicon) {
						Image(nsImage: image)
							.resizable()
							.frame(width: 16, height: 16)
					} else {
						Image(systemName: "globe")
							.frame(width: 16, height: 16)
					}
				}
				
				Text(tab.title)
					.lineLimit(1)
					.truncationMode(.middle)
			}
			.padding(.horizontal, 12)
			.padding(.vertical, 8)
			.background(
				RoundedRectangle(cornerRadius: 6)
					.fill(Color.accentColor.opacity(0.2))
			)
			.opacity(0.8)
		}
	}
}
