//
//  PinnedTabView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct PinnedTabView: View {
	let tab: Tab
	let isSelected: Bool
	let onSelect: () -> Void
	@Environment(\.modelContext) private var modelContext
	
	private func unpin() {
		if let workspace = tab.workspace,
		   let profile = workspace.profile {
			// Remove from pinned tabs
			profile.pinnedTabs.removeAll { $0.id == tab.id }
			
			// Add to workspace tabs
			workspace.tabs.append(tab)
			
			try? modelContext.save()
		}
	}
	
	var body: some View {
		Button(action: onSelect) {
			VStack {
				if let favicon = tab.favicon,
				   let image = NSImage(data: favicon) {
					Image(nsImage: image)
						.resizable()
						.frame(width: 20, height: 20)
				} else {
					Image(systemName: "globe")
						.font(.system(size: 16))
				}
			}
		}
		.buttonStyle(.plain)
		.frame(width: 40, height: 40)
		.background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
		.clipShape(RoundedRectangle(cornerRadius: 6))
		.contentShape(Rectangle())
		.help(tab.title)
		.contextMenu {
			Button("Unpin Tab") {
				unpin()
			}
		}
	}
}
