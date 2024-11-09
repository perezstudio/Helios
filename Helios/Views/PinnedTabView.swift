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
	let workspace: Workspace
	let isSelected: Bool
	let onSelect: () -> Void
	let onClose: () -> Void
	@Environment(\.modelContext) private var modelContext
	
	private func unpin() {
		if let profile = workspace.profile {
			// Remove from pinned tabs
			profile.pinnedTabs.removeAll { $0.id == tab.id }
			
			// Add back to workspace tabs
			workspace.tabs.append(tab)
			tab.workspace = workspace
			
			try? modelContext.save()
		}
	}
	
	private func closeTab() {
		// Clean up the WebView
		WebViewStore.shared.remove(for: tab.id)
		
		// Remove from pinned tabs
		if let profile = workspace.profile {
			profile.pinnedTabs.removeAll { $0.id == tab.id }
			try? modelContext.save()
		}
		
		onClose()
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
			
			Divider()
			
			Button("Close Tab", role: .destructive) {
				closeTab()
			}
		}
	}
}
