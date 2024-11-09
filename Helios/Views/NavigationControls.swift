//
//  NavigationControls.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NavigationControls: View {
	@Binding var selectedTab: Tab?
	@State private var canGoBack = false
	@State private var canGoForward = false
	@State private var isLoading = false
	@Environment(\.modelContext) private var modelContext
	private let webViewStore = WebViewStore.shared
	
	var body: some View {
		HStack(spacing: 12) {
			// Back Button
			Button(action: goBack) {
				Image(systemName: "chevron.left")
					.foregroundColor(canGoBack ? .primary : .secondary)
			}
			.disabled(!canGoBack)
			.keyboardShortcut("[", modifiers: [.command])
			.help("Go Back")
			
			// Forward Button
			Button(action: goForward) {
				Image(systemName: "chevron.right")
					.foregroundColor(canGoForward ? .primary : .secondary)
			}
			.disabled(!canGoForward)
			.keyboardShortcut("]", modifiers: [.command])
			.help("Go Forward")
			
			// Refresh/Stop Button
			Button(action: refreshOrStop) {
				Image(systemName: isLoading ? "xmark" : "arrow.clockwise")
			}
			.keyboardShortcut("r", modifiers: [.command])
			.help(isLoading ? "Stop Loading" : "Refresh Page")
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewStartedLoading)) { notification in
			if let loadingTab = notification.object as? Tab,
			   loadingTab.id == selectedTab?.id {
				isLoading = true
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewFinishedLoading)) { notification in
			if let loadingTab = notification.object as? Tab,
			   loadingTab.id == selectedTab?.id {
				isLoading = false
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewCanGoBackChanged)) { notification in
			if let (tabID, canGo) = notification.object as? (UUID, Bool),
			   tabID == selectedTab?.id {
				canGoBack = canGo
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewCanGoForwardChanged)) { notification in
			if let (tabID, canGo) = notification.object as? (UUID, Bool),
			   tabID == selectedTab?.id {
				canGoForward = canGo
			}
		}
	}
	
	private func goBack() {
		guard let tab = selectedTab else { return }
		webViewStore.goBack(for: tab.id)
	}
	
	private func goForward() {
		guard let tab = selectedTab else { return }
		webViewStore.goForward(for: tab.id)
	}
	
	private func refreshOrStop() {
		guard let tab = selectedTab else { return }
		if isLoading {
			webViewStore.stopLoading(for: tab.id)
			isLoading = false
		} else {
			webViewStore.reload(for: tab.id)
			tab.lastVisited = Date()
			try? modelContext.save()
		}
	}
}
