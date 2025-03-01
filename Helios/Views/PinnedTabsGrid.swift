//
//  PinnedTabsGrid.swift
//  Helios
//
//  Created by Kevin Perez on 2/28/25.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

// Enhanced FaviconView with better scaling and fallback
struct EnhancedFaviconView: View {
	let tab: Tab
	let size: CGFloat
	
	var body: some View {
		Group {
			if let faviconData = tab.faviconData,
			   let uiImage = NSImage(data: faviconData) {
				Image(nsImage: uiImage)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: size, height: size)
			} else {
				// Fallback icon with domain initial
				ZStack {
					Circle()
						.fill(getColorForDomain(tab.url))
					
					Text(getInitialForDomain(tab.url))
						.font(.system(size: size * 0.6, weight: .bold))
						.foregroundColor(.white)
				}
				.frame(width: size, height: size)
			}
		}
	}
	
	private func getInitialForDomain(_ urlString: String) -> String {
		guard let url = URL(string: urlString),
			  let host = url.host else {
			return "?"
		}
		
		// Remove www. prefix if present
		var domain = host
		if domain.hasPrefix("www.") {
			domain = String(domain.dropFirst(4))
		}
		
		// Get first character of domain
		return domain.prefix(1).uppercased()
	}
	
	private func getColorForDomain(_ urlString: String) -> Color {
		guard let url = URL(string: urlString),
			  let host = url.host else {
			return .gray
		}
		
		// Simple hash-based color assignment
		let hash = abs(host.hashValue)
		let colors: [Color] = [.blue, .red, .green, .orange, .purple, .pink, .cyan, .indigo]
		return colors[hash % colors.count]
	}
}

struct PinnedTabsGrid: View {
	let tabs: [Tab]
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	@State private var draggedTab: Tab?
	@State private var draggedOver: UUID?
	
	// Grid configuration
	private let maxTabsPerRow = 4
	private let spacing: CGFloat = 8
	
	var body: some View {
		VStack(alignment: .leading, spacing: 8) {
			if !tabs.isEmpty {
				Text("Pinned")
					.font(.headline)
					.foregroundStyle(.secondary)
					.padding(.horizontal, 8)
				
				LazyVGrid(
					columns: gridItemsForTabCount(tabs.count),
					spacing: spacing
				) {
					ForEach(tabs) { tab in
						PinnedTabGridItem(
							tab: tab,
							windowId: windowId,
							viewModel: viewModel,
							isBeingDragged: tab.id == draggedTab?.id,
							isDraggedOver: tab.id == draggedOver
						)
						.padding(4)
						.overlay(
							RoundedRectangle(cornerRadius: 8)
								.stroke(draggedOver == tab.id ? Color.accentColor : Color.clear, lineWidth: 2)
						)
						.onDrag {
							// Set this tab as the one being dragged
							self.draggedTab = tab
							return NSItemProvider(object: tab.id.uuidString as NSString)
						}
						.onDrop(of: [.text], delegate: ReorderDropDelegate(
							item: tab,
							items: tabs,
							draggedItem: $draggedTab,
							draggedOver: $draggedOver,
							viewModel: viewModel
						))
					}
				}
				.padding(.horizontal, 4)
			}
		}
		.padding(.bottom, 8)
		.dropDestination(for: DraggableTabItem.self) { items, location in
			guard let item = items.first else { return false }
			return handleDrop(of: item)
		} isTargeted: { isTargeted in
			// Visual feedback for drop target
		}
		.background(
			RoundedRectangle(cornerRadius: 8)
				.fill(Color.accentColor.opacity(0.05))
				.padding(.horizontal, 4)
		)
	}
	
	private func handleDrop(of item: DraggableTabItem) -> Bool {
		// If the tab is already pinned, ignore the drop
		if item.type == .pinned {
			return false
		}
		
		guard let tab = findTab(for: item) else { return false }
		
		// Convert the tab to a pinned tab
		viewModel.togglePin(tab)
		
		return true
	}
	
	private func findTab(for item: DraggableTabItem) -> Tab? {
		if let workspace = viewModel.currentWorkspace {
			return workspace.tabs.first { $0.id == item.codableTab.id }
		}
		return nil
	}
	
	private func gridItemsForTabCount(_ count: Int) -> [GridItem] {
		switch count {
		case 0:
			return []
		case 1:
			// Single tab spans the full width
			return [GridItem(.flexible(), spacing: spacing)]
		case 2:
			// Two tabs per row
			return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 2)
		case 3:
			// Three tabs per row
			return Array(repeating: GridItem(.flexible(), spacing: spacing), count: 3)
		default:
			// Four tabs per row for 4 or more tabs
			return Array(repeating: GridItem(.flexible(), spacing: spacing), count: maxTabsPerRow)
		}
	}
}

// In PinnedTabsGrid.swift, update the ReorderDropDelegate
struct ReorderDropDelegate: DropDelegate {
	let item: Tab
	let items: [Tab]
	@Binding var draggedItem: Tab?
	@Binding var draggedOver: UUID?
	let viewModel: BrowserViewModel
	
	func dropEntered(info: DropInfo) {
		guard let draggedItem = draggedItem,
			  draggedItem.id != item.id else {
			return
		}
		
		// Visual indicator that we're dragging over this item
		draggedOver = item.id
	}
	
	func dropExited(info: DropInfo) {
		// Clear the visual indicator
		if draggedOver == item.id {
			draggedOver = nil
		}
	}
	
	func performDrop(info: DropInfo) -> Bool {
		draggedOver = nil
		
		guard let draggedItem = draggedItem,
			  let workspace = viewModel.currentWorkspace,
			  let fromIndex = items.firstIndex(where: { $0.id == draggedItem.id }),
			  let toIndex = items.firstIndex(where: { $0.id == item.id }) else {
			return false
		}
		
		// Only rearrange if the indices are different
		if fromIndex != toIndex {
			// Get the tabs sorted by display order
			let pinnedTabs = workspace.tabs
				.filter { $0.type == .pinned }
				.sorted { $0.displayOrder < $1.displayOrder }
			
			// Create a mutable copy of the tabs array
			var movedTabs = pinnedTabs.map { $0 } // Copy the array
			
			// Perform the move operation
			let movedTab = movedTabs.remove(at: fromIndex)
			movedTabs.insert(movedTab, at: toIndex < fromIndex ? toIndex : toIndex)
			
			// Update all orders
			for (index, tab) in movedTabs.enumerated() {
				tab.displayOrder = index
			}
			
			// Save changes
			viewModel.saveChanges()
		}
		
		// Reset dragged item
		self.draggedItem = nil
		return true
	}
	
	func validateDrop(info: DropInfo) -> Bool {
		// Only accept drops from the same section
		guard draggedItem != nil else { return false }
		return true
	}
	
	func dropUpdated(info: DropInfo) -> DropProposal? {
		return DropProposal(operation: .move)
	}
}

struct PinnedTabGridItem: View {
	let tab: Tab
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	let isBeingDragged: Bool
	let isDraggedOver: Bool
	@State private var isHovered = false
	
	var isSelected: Bool {
		viewModel.getSelectedTab(for: windowId)?.id == tab.id
	}
	
	var isSelectedInOtherWindow: Bool {
		WindowManager.shared.isTabSelectedInOtherWindow(tab.id, currentWindow: windowId)
	}
	
	var body: some View {
		Button {
			viewModel.selectTab(tab, for: windowId)
		} label: {
			ZStack(alignment: .topTrailing) {
				EnhancedFaviconView(tab: tab, size: 24)
					.frame(width: 40, height: 40)
					.contentShape(Rectangle())
					.background(
						RoundedRectangle(cornerRadius: 6)
							.fill(backgroundColor)
					)
					.overlay(
						RoundedRectangle(cornerRadius: 6)
							.stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1)
					)
					.scaleEffect(isBeingDragged ? 1.05 : 1.0)
					.opacity(isBeingDragged ? 0.8 : 1.0)
					.animation(.spring(response: 0.3), value: isBeingDragged)
					.animation(.spring(response: 0.3), value: isDraggedOver)
					.help(tab.title)
				
				if isHovered && !isBeingDragged {
					Button(action: { viewModel.deleteTab(tab) }) {
						Image(systemName: "xmark.circle.fill")
							.font(.system(size: 14))
							.foregroundStyle(.secondary)
							.background(Material.regular)
							.clipShape(Circle())
					}
					.buttonStyle(.plain)
					.offset(x: 8, y: -4)
					.transition(.opacity)
				}
			}
		}
		.buttonStyle(.plain)
		.opacity(isSelectedInOtherWindow ? 0.5 : 1.0)
		.disabled(isSelectedInOtherWindow)
		.contextMenu {
			TabContextMenu(tab: tab, viewModel: viewModel)
		}
		.onHover { hovering in
			withAnimation(.easeInOut(duration: 0.15)) {
				isHovered = hovering
			}
		}
		.draggable(DraggableTabItem(id: tab.id, tab: tab, type: tab.type)) {
			EnhancedFaviconView(tab: tab, size: 16)
				.padding(8)
				.background(Color(.textBackgroundColor))
				.cornerRadius(4)
		}
	}
	
	private var backgroundColor: Color {
		if isDraggedOver {
			return Color.accentColor.opacity(0.2)
		} else if isSelected {
			return Color.accentColor.opacity(0.15)
		} else if isHovered {
			return Color.secondary.opacity(0.1)
		} else {
			return Color.clear
		}
	}
}
