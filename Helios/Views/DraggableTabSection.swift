//
//  DraggableTabSection.swift
//  Helios
//
//  Created by Kevin Perez on 2/10/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Model to represent a draggable tab item
struct DraggableTabItem: Identifiable, Equatable, Codable, Transferable {
	let id: UUID
	let codableTab: CodableTab
	let type: TabType
	
	init(id: UUID, tab: Tab, type: TabType) {
		self.id = id
		self.codableTab = CodableTab(from: tab)
		self.type = type
	}
	
	static func == (lhs: DraggableTabItem, rhs: DraggableTabItem) -> Bool {
		lhs.id == rhs.id
	}
	
	// Transferable conformance
	static var transferRepresentation: some TransferRepresentation {
		CodableRepresentation(contentType: .draggedTab)
	}
}

// Custom UTType for our dragged tab
extension UTType {
	static var draggedTab: UTType {
		UTType(exportedAs: "com.helios.dragged-tab")
	}
}

// Drag and drop tab section
struct DraggableTabSection: View {
	let title: String
	let tabs: [Tab]
	let tabType: TabType
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	
	var body: some View {
		// Use the PinnedTabsGrid for pinned tabs, regular list for other tab types
		if tabType == .pinned {
			PinnedTabsGrid(tabs: tabs, windowId: windowId, viewModel: viewModel)
		} else {
			Section(header: Text(title)) {
				ForEach(tabs) { tab in
					TabRow(tab: tab, windowId: windowId, viewModel: viewModel)
						.draggable(DraggableTabItem(id: tab.id, tab: tab, type: tab.type)) {
							// Preview while dragging
							HStack {
								FaviconView(tab: tab, size: 16)
								Text(tab.title)
									.lineLimit(1)
							}
							.padding(.horizontal, 8)
							.padding(.vertical, 4)
							.background(Color(.textBackgroundColor))
							.cornerRadius(4)
						}
				}
				.onMove { source, destination in
					if let workspace = viewModel.currentWorkspace {
						viewModel.reorderPinnedTabs(in: workspace, from: source, to: destination)
					}
				}
			}
			.dropDestination(for: DraggableTabItem.self) { items, location in
				guard let item = items.first else { return false }
				return handleDrop(of: item)
			} isTargeted: { isTargeted in
				// Optional visual feedback when drag is over the section
			}
		}
	}
	
	private func findTab(for item: DraggableTabItem) -> Tab? {
		if let workspace = viewModel.currentWorkspace {
			return workspace.tabs.first { $0.id == item.codableTab.id }
		}
		return nil
	}
	
	private func handleDrop(of item: DraggableTabItem) -> Bool {
		// If the tab is already of this type, ignore the drop
		if item.type == tabType {
			return false
		}
		
		guard let tab = findTab(for: item) else { return false }
		
		// Handle conversion between tab types
		switch tabType {
		case .normal:
			if item.type == .pinned {
				viewModel.togglePin(tab)
			} else if item.type == .bookmark {
				convertToNormalTab(tab)
			}
			
		case .bookmark:
			toggleBookmark(tab)
			
		case .pinned:
			viewModel.togglePin(tab)
		}
		
		return true
	}
	
	private func toggleBookmark(_ tab: Tab) {
		if tab.type == .bookmark {
			convertToNormalTab(tab)
		} else {
			// Convert to bookmark
			tab.type = .bookmark
			tab.bookmarkedUrl = tab.url
			
			if let index = viewModel.normalTabs.firstIndex(where: { $0.id == tab.id }) {
				viewModel.normalTabs.remove(at: index)
				viewModel.bookmarkTabs.append(tab)
			}
		}
		viewModel.saveChanges()
	}
	
	private func convertToNormalTab(_ tab: Tab) {
		tab.type = .normal
		tab.bookmarkedUrl = nil
		
		if let index = viewModel.bookmarkTabs.firstIndex(where: { $0.id == tab.id }) {
			viewModel.bookmarkTabs.remove(at: index)
			viewModel.normalTabs.append(tab)
		}
		
		viewModel.saveChanges()
	}
}
