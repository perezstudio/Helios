//
//  TabRow.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftUI
import SwiftData

struct TabRow: View {
	var tab: Tab
	var windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	@Environment(\.modelContext) var modelContext
	@State private var showWorkspaceSheet = false
	
	var isSelectedInOtherWindow: Bool {
		WindowManager.shared.isTabSelectedInOtherWindow(tab.id, currentWindow: windowId)
	}
	
	var body: some View {
		HStack {
			if let faviconData = tab.faviconData,
			   let uiImage = NSImage(data: faviconData) {
				Image(nsImage: uiImage)
					.resizable()
					.frame(width: 16, height: 16)
			} else {
				Image(systemName: "globe")
					.frame(width: 16, height: 16)
			}
			Text(tab.title)
				.lineLimit(1)
			Spacer()
			
			// Close Button
			Button(action: {
				viewModel.deleteTab(tab)
			}) {
				Image(systemName: "xmark.circle")
			}
			.buttonStyle(BorderlessButtonStyle())
			.foregroundColor(.red)
		}
		.contentShape(Rectangle())
		.opacity(isSelectedInOtherWindow ? 0.5 : 1)
		.disabled(isSelectedInOtherWindow)
		.contextMenu {
			Button {
				copyURL()
			} label: {
				Label("Copy Link", systemImage: "doc.on.doc")
			}
			
			Button {
				duplicateTab()
			} label: {
				Label("Duplicate", systemImage: "plus.square.on.square")
			}
			
			Menu {
				ForEach(viewModel.workspaces.filter { $0.id != tab.workspace?.id }, id: \.id) { workspace in
					Button {
						moveTab(to: workspace)
					} label: {
						Label(workspace.name, systemImage: workspace.icon)
					}
				}
			} label: {
				Label("Move To", systemImage: "folder")
			}
			
			Divider()
			
			Button {
				toggleBookmark()
			} label: {
				Label(tab.type == .bookmark ? "Remove Bookmark" : "Bookmark Tab",
					  systemImage: tab.type == .bookmark ? "bookmark.slash" : "bookmark")
			}
			
			Button {
				togglePin()
			} label: {
				Label(tab.type == .pinned ? "Unpin Tab" : "Pin Tab",
					  systemImage: tab.type == .pinned ? "pin.slash" : "pin")
			}
			
			Divider()
			
			Button(role: .destructive) {
				viewModel.deleteTab(tab)
			} label: {
				Label("Archive", systemImage: "archivebox")
			}
		}
		.tag(tab)
	}
	
	private func copyURL() {
		#if os(macOS)
		NSPasteboard.general.clearContents()
		NSPasteboard.general.setString(tab.url, forType: .string)
		#endif
	}
	
	private func duplicateTab() {
		guard let context = tab.workspace?.modelContext else { return }
		let newTab = Tab(title: tab.title, url: tab.url, type: .normal, workspace: tab.workspace)
		context.insert(newTab)
		viewModel.normalTabs.append(newTab)
		viewModel.currentTab = newTab
	}
	
	private func moveTab(to workspace: Workspace) {
		// Remove from current workspace
		if let currentWorkspace = tab.workspace {
			currentWorkspace.tabs.removeAll { $0.id == tab.id }
		}
		
		// Add to new workspace
		workspace.tabs.append(tab)
		tab.workspace = workspace
		
		// If this is the current tab, update the current workspace
		if viewModel.currentTab?.id == tab.id {
			viewModel.currentWorkspace = workspace
		}
	}
	
	private func toggleBookmark() {
		if tab.type == .bookmark {
			tab.type = .normal
			if let index = viewModel.bookmarkTabs.firstIndex(where: { $0.id == tab.id }) {
				viewModel.bookmarkTabs.remove(at: index)
				viewModel.normalTabs.append(tab)
			}
		} else {
			tab.type = .bookmark
			if let index = viewModel.normalTabs.firstIndex(where: { $0.id == tab.id }) {
				viewModel.normalTabs.remove(at: index)
				viewModel.bookmarkTabs.append(tab)
			}
		}
		viewModel.saveChanges()
	}
	
	private func togglePin() {
		viewModel.togglePin(tab)
	}
}
