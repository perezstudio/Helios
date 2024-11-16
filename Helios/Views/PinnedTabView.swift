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
			// Store current state
			let currentURL = tab.url
			let currentTitle = tab.title
			let currentFavicon = tab.favicon
			
			// Clean up old WebView
			WebViewStore.shared.remove(for: tab.id)
			
			// Remove from pinned tabs
			profile.pinnedTabs.removeAll { $0.id == tab.id }
			
			// Add back to workspace tabs
			workspace.tabs.append(tab)
			tab.workspace = workspace
			
			// Restore state
			tab.url = currentURL
			tab.title = currentTitle
			tab.favicon = currentFavicon
			
			try? modelContext.save()
			
			// Create new WebView for the unpinned tab
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
				NotificationCenter.default.post(name: .selectUnpinnedTab, object: tab)
			}
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
			
			Divider()
			
			Button("Close Tab", role: .destructive) {
				onClose()
			}
		}
	}
}

extension Notification.Name {
	static let selectUnpinnedTab = Notification.Name("selectUnpinnedTab")
}
