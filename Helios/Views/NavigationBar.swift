//
//  NavigationBar.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

struct NavigationBar: View {
	let tab: Tab
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
					.frame(width: 28, height: 28)
			}
			.buttonStyle(.bordered)
			.disabled(!canGoBack)
			.keyboardShortcut("[", modifiers: [.command])
			.help("Go Back")
			
			// Forward Button
			Button(action: goForward) {
				Image(systemName: "chevron.right")
					.foregroundColor(canGoForward ? .primary : .secondary)
					.frame(width: 28, height: 28)
			}
			.buttonStyle(.bordered)
			.disabled(!canGoForward)
			.keyboardShortcut("]", modifiers: [.command])
			.help("Go Forward")
			
			// Refresh/Stop Button
			Button(action: refreshOrStop) {
				if isLoading {
					Image(systemName: "xmark")
						.frame(width: 28, height: 28)
				} else {
					Image(systemName: "arrow.clockwise")
						.frame(width: 28, height: 28)
				}
			}
			.buttonStyle(.bordered)
			.keyboardShortcut("r", modifiers: [.command])
			.help(isLoading ? "Stop Loading" : "Refresh Page")
		}
		.padding(.horizontal)
		.onReceive(NotificationCenter.default.publisher(for: .webViewStartedLoading)) { notification in
			if let loadingTab = notification.object as? Tab, loadingTab.id == tab.id {
				isLoading = true
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewFinishedLoading)) { notification in
			if let loadingTab = notification.object as? Tab, loadingTab.id == tab.id {
				isLoading = false
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewCanGoBackChanged)) { notification in
			if let (tabID, canGo) = notification.object as? (UUID, Bool),
			   tabID == tab.id {
				canGoBack = canGo
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewCanGoForwardChanged)) { notification in
			if let (tabID, canGo) = notification.object as? (UUID, Bool),
			   tabID == tab.id {
				canGoForward = canGo
			}
		}
	}
	
	private func goBack() {
		webViewStore.goBack(for: tab.id)
	}
	
	private func goForward() {
		webViewStore.goForward(for: tab.id)
	}
	
	private func refreshOrStop() {
		if isLoading {
			webViewStore.stopLoading(for: tab.id)
			isLoading = false
		} else {
			tab.lastVisited = Date()
			try? modelContext.save()
		}
	}
}
