//
//  ContentView.swift
//  Helios
//
//  Created by Kevin Perez on 12/17/24.
//

import SwiftUI
import SwiftData
import WebKit

struct ContentView: View {
	@Environment(\.modelContext) var modelContext
	@Bindable var viewModel: BrowserViewModel
	@State private var windowId = WindowIdentifier()
	
	var body: some View {
		NavigationSplitView {
			SidebarView(windowId: windowId.id, viewModel: viewModel)
		} detail: {
			if let currentTab = viewModel.getSelectedTab(for: windowId.id) {
				WebViewContainer(webView: viewModel.getWebView(for: currentTab))
					.id(currentTab.id)
					.transition(.opacity)
			} else {
				ContentUnavailableView(
					"No Tab Selected",
					systemImage: "magnifyingglass",
					description: Text("Please enter a URL or perform a search.")
				)
				.transition(.opacity)
			}
		}
		.onAppear {
			viewModel.setModelContext(modelContext)
			WindowManager.shared.registerWindow(windowId.id)
		}
		.onDisappear {
			WindowManager.shared.unregisterWindow(windowId.id)
		}
		.focusedSceneValue(\.windowId, windowId.id)
	}
}

class WindowIdentifier: ObservableObject {
	let id = UUID()
}

//#Preview {
//    ContentView()
//}
