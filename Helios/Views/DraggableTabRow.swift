//
//  DraggableTabRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct DraggableTabRow: View {
	let tab: Tab
	let isSelected: Bool
	let workspace: Workspace
	@State private var isTargeted = false
	let onSelect: () -> Void
	let onClose: () -> Void
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		TabRow(
			tab: tab,
			isSelected: isSelected,
			onSelect: onSelect,
			onClose: onClose
		)
		.opacity(isTargeted ? 0.5 : 1.0)
		.background(isTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
		.draggable(TabTransferID(id: tab.id)) {
			// Drag preview
			TabRow(
				tab: tab,
				isSelected: isSelected,
				onSelect: {},
				onClose: {}
			)
			.opacity(0.8)
		}
		.dropDestination(for: TabTransferID.self) { items, location in
			guard let droppedTabId = items.first?.id,
				  let droppedTab = workspace.tabs.first(where: { $0.id == droppedTabId }) else {
				return false
			}
			
			// Get indices
			let orderedTabs = workspace.orderedTabs
			guard let currentIndex = orderedTabs.firstIndex(where: { $0.id == tab.id }),
				  let draggedIndex = orderedTabs.firstIndex(where: { $0.id == droppedTab.id }) else {
				return false
			}
			
			// Don't reorder if same position
			guard currentIndex != draggedIndex else { return false }
			
			// Update the order
			workspace.moveTab(droppedTab, to: currentIndex)
			try? modelContext.save()
			
			return true
		} isTargeted: { isTargeted in
			self.isTargeted = isTargeted
		}
	}
}


