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
		Group {
			switch tab.type {
			case .pinned:
				PinnedTabView(tab: tab, windowId: windowId, viewModel: viewModel)
			case .bookmark:
				BookmarkedTabView(tab: tab, windowId: windowId, viewModel: viewModel)
			case .normal:
				NormalTabView(tab: tab, windowId: windowId, viewModel: viewModel)
			}
		}
		.contentShape(Rectangle())
		.opacity(isSelectedInOtherWindow ? 0.5 : 1)
		.disabled(isSelectedInOtherWindow)
		.contextMenu {
			TabContextMenu(tab: tab, viewModel: viewModel)
		}
		.tag(tab)
	}
}

struct PinnedTabView: View {
	let tab: Tab
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	@State private var isHovered = false
	
	var body: some View {
		HStack(spacing: 8) {
			FaviconView(tab: tab, size: 14)
				.overlay(
					Image(systemName: "pin.fill")
						.font(.system(size: 8))
						.foregroundStyle(.secondary)
						.offset(x: 6, y: -6)
				)
			
			Text(tab.title)
				.lineLimit(1)
				.font(.callout)
			
			Spacer()
			
			if isHovered {
				Button(action: { viewModel.deleteTab(tab) }) {
					Image(systemName: "xmark.circle.fill")
						.font(.system(size: 12))
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
				.transition(.opacity)
			}
		}
		.padding(.vertical, 2)
		.onHover { hovering in
			withAnimation(.easeInOut(duration: 0.15)) {
				isHovered = hovering
			}
		}
	}
}

struct BookmarkedTabView: View {
	let tab: Tab
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	@State private var isHovered = false
	
	var body: some View {
		HStack(spacing: 8) {
			Button {
				returnToBookmark()
			} label: {
				FaviconView(tab: tab, size: 16)
					.overlay(
						Image(systemName: "bookmark.fill")
							.font(.system(size: 8))
							.foregroundStyle(.orange)
							.offset(x: 6, y: 6)
					)
			}
			.buttonStyle(.plain)
			.help("Return to bookmarked URL")
			
			Text(tab.title)
				.lineLimit(1)
			
			Spacer()
			
			if isHovered {
				Button(action: { viewModel.deleteTab(tab) }) {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
				.transition(.opacity)
			}
		}
		.padding(.vertical, 2)
		.onHover { hovering in
			withAnimation(.easeInOut(duration: 0.15)) {
				isHovered = hovering
			}
		}
	}
	
	private func returnToBookmark() {
		if let bookmarkedUrl = tab.bookmarkedUrl,
		   let url = URL(string: bookmarkedUrl) {
			viewModel.getWebView(for: tab).load(URLRequest(url: url))
		}
	}
}

struct NormalTabView: View {
	let tab: Tab
	let windowId: UUID
	@Bindable var viewModel: BrowserViewModel
	@State private var isHovered = false
	
	var body: some View {
		HStack(spacing: 8) {
			FaviconView(tab: tab, size: 16)
			
			Text(tab.title)
				.lineLimit(1)
			
			Spacer()
			
			if isHovered {
				Button(action: { viewModel.deleteTab(tab) }) {
					Image(systemName: "xmark.circle.fill")
						.foregroundStyle(.secondary)
				}
				.buttonStyle(.plain)
				.transition(.opacity)
			}
		}
		.padding(.vertical, 2)
		.onHover { hovering in
			withAnimation(.easeInOut(duration: 0.15)) {
				isHovered = hovering
			}
		}
	}
}

struct FaviconView: View {
	let tab: Tab
	let size: CGFloat
	
	var body: some View {
		Group {
			if let faviconData = tab.faviconData,
			   let uiImage = NSImage(data: faviconData) {
				Image(nsImage: uiImage)
					.resizable()
					.frame(width: size, height: size)
			} else {
				Image(systemName: "globe")
					.frame(width: size, height: size)
			}
		}
	}
}

struct TabContextMenu: View {
	let tab: Tab
	@Bindable var viewModel: BrowserViewModel
	
	var body: some View {
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
		if let currentWorkspace = tab.workspace {
			currentWorkspace.tabs.removeAll { $0.id == tab.id }
		}
		
		workspace.tabs.append(tab)
		tab.workspace = workspace
		
		if viewModel.currentTab?.id == tab.id {
			viewModel.currentWorkspace = workspace
		}
	}
	
	private func toggleBookmark() {
		if tab.type == .bookmark {
			// Remove bookmark
			tab.type = .normal
			tab.bookmarkedUrl = nil
			if let index = viewModel.bookmarkTabs.firstIndex(where: { $0.id == tab.id }) {
				viewModel.bookmarkTabs.remove(at: index)
				viewModel.normalTabs.append(tab)
			}
		} else {
			// Add bookmark
			tab.type = .bookmark
			tab.bookmarkedUrl = tab.url // Store current URL as bookmarked URL
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
