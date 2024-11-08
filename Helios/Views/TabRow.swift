//
//  TabRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct TabRow: View {
	let tab: Tab
	let isSelected: Bool
	@Environment(\.modelContext) private var modelContext
	
	private func closeTab() {
		tab.close()
		try? modelContext.save()
	}
	
	private func bookmarkTab(in folder: BookmarkFolder) {
		tab.createBookmark(in: folder)
		try? modelContext.save()
	}
	
	var body: some View {
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
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
		)
		.contentShape(Rectangle())
		.contextMenu {
			if let workspace = tab.workspace {
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


