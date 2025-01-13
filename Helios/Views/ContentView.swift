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
	@EnvironmentObject var viewModel: BrowserViewModel

	var body: some View {
		NavigationSplitView {
			SidebarView()
		} detail: {
			if let currentTab = viewModel.currentTab {
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
		}
	}
}

//#Preview {
//    ContentView()
//}
