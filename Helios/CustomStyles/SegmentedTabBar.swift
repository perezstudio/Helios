//
//  SegmentedTabBar.swift
//  Helios
//
//  Created by Kevin Perez on 2/19/25.
//

import SwiftUI
import Observation

struct SegmentedTabBar<T: Hashable>: View {
	@Binding var selection: T
	let tabs: [TabItem<T>]
	@State private var hoveredId: UUID?
	
	init(selection: Binding<T>, tabs: [TabItem<T>]) {
		self._selection = selection
		self.tabs = tabs
	}
	
	private func makeTabButton(for tab: TabItem<T>) -> some View {
		let isSelected = selection == tab.tag
		let isHovered = hoveredId == tab.id
		
		return Button {
			selection = tab.tag
		} label: {
			HStack {
				if let icon = tab.icon {
					Image(systemName: icon)
						.imageScale(.medium)
				}
			}
			.frame(maxWidth: .infinity)
//			.frame(height: 28)
			.padding(.horizontal, 8)
			.padding(.vertical, 2)
			.background(
				RoundedRectangle(cornerRadius: 4)
					.fill(Color.primary)
					.opacity(
						isSelected ? 0.1 :
						isHovered ? 0.05 : 0
					)
			)
			.foregroundStyle(Color.primary)
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { hovering in
			withAnimation(.easeOut(duration: 0.15)) {
				hoveredId = hovering ? tab.id : nil
			}
		}
	}
	
	var body: some View {
		HStack(spacing: 1) {
			ForEach(tabs) { tab in
				makeTabButton(for: tab)
			}
		}
		.padding(4)
		.background {
			RoundedRectangle(cornerRadius: 6)
				.fill(.background)
				.opacity(0.3)
		}
	}
}

struct TabItem<T: Hashable>: Identifiable {
	let id = UUID()
	let title: String
	let icon: String?
	let tag: T
	
	init(_ title: String, icon: String? = nil, tag: T) {
		self.title = title
		self.icon = icon
		self.tag = tag
	}
}

#Preview {
	let state = PreviewState()
	
	return VStack(spacing: 20) {
		// Static example
		SegmentedTabBar(
			selection: .constant(PreviewTab.all),
			tabs: [
				TabItem("All", icon: "list.bullet", tag: PreviewTab.all),
				TabItem("Pinned", icon: "pin", tag: PreviewTab.pinned),
				TabItem("Bookmarks", icon: "bookmark", tag: PreviewTab.bookmarks)
			]
		)
		.frame(width: 300)
		
		// Interactive example
		SegmentedTabBar(
			selection: Binding(
				get: { state.selectedTab },
				set: { state.selectedTab = $0 }
			),
			tabs: [
				TabItem("First", icon: "1.circle", tag: PreviewTab.all),
				TabItem("Second", icon: "2.circle", tag: PreviewTab.pinned),
				TabItem("Third", icon: "3.circle", tag: PreviewTab.bookmarks)
			]
		)
		.frame(width: 300)
	}
	.padding()
	.frame(height: 200)
	.background(Color(.windowBackgroundColor))
}

// Preview helper types
private enum PreviewTab {
	case all, pinned, bookmarks
}

@Observable
private class PreviewState {
	var selectedTab: PreviewTab = .all
}
