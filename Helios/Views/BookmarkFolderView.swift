//
//  BookmarkFolderView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct BookmarkFolderView: View {
	let folder: BookmarkFolder
	let isExpanded: Bool
	let onToggleExpanded: (Bool) -> Void
	@Binding var selectedTab: Tab?
	@State private var isDroppingTab = false
	@Environment(\.modelContext) private var modelContext
	
	private func findTab(by id: UUID) -> Tab? {
		let descriptor = FetchDescriptor<Tab>(
			predicate: #Predicate<Tab> { tab in
				tab.id == id
			}
		)
		return try? modelContext.fetch(descriptor).first
	}
	
	var body: some View {
		DisclosureGroup(
			isExpanded: Binding(
				get: { isExpanded },
				set: { onToggleExpanded($0) }
			)
		) {
			ForEach(folder.bookmarks) { bookmark in
				BookmarkRow(tab: bookmark, isSelected: bookmark.id == selectedTab?.id)
					.onTapGesture {
						selectedTab = bookmark
					}
			}
		} label: {
			HStack {
				Label(folder.name, systemImage: "folder")
				Spacer()
				Text("\(folder.bookmarks.count)")
					.foregroundColor(.secondary)
					.font(.caption)
			}
		}
		.background(isDroppingTab ? Color.accentColor.opacity(0.2) : Color.clear)
		.dropDestination(for: TabTransferID.self) { items, _ in
			if let transferID = items.first,
			   let tab = findTab(by: transferID.id) {
				folder.bookmarks.append(tab)
				try? modelContext.save()
				return true
			}
			isDroppingTab = false
			return false
		} isTargeted: { isTargeted in
			isDroppingTab = isTargeted
		}
	}
}
