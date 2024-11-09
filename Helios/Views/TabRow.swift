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
		// Just remove the WebView from store - it will handle cleanup
		WebViewStore.shared.remove(for: tab.id)
		
		// Close the tab
		tab.close()
		try? modelContext.save()
		
		// Call the onClose callback if provided
		onClose?()
	}
	
	private func bookmarkTab(in folder: BookmarkFolder) {
		tab.createBookmark(in: folder)
		try? modelContext.save()
	}
	
	private func pinTab() {
		if let workspace = tab.workspace,
		   let profile = workspace.profile {
			// Remove from workspace tabs
			workspace.removeTab(tab)
			// Add to pinned tabs
			profile.pinnedTabs.append(tab)
			try? modelContext.save()
		}
	}
	
	var body: some View {
		Button(action: onSelect) {
			HStack(spacing: 12) {
				// Favicon
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
				
				// Title
				Text(tab.title)
					.lineLimit(1)
					.truncationMode(.middle)
				
				Spacer()
				
				// Close Button
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
		.draggable(tab)
	}
}
