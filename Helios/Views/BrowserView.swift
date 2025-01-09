//
//  BrowserView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import WebKit

struct BrowserView: View {
	@Binding var selectedTab: Tab?

	var body: some View {
		if (selectedTab != nil) {
			WebView(webView: selectedTab!.webService.webView)
				.id(selectedTab?.id) // Ensures SwiftUI recognizes the WebView as unique
				.onAppear {
					if let tab = selectedTab {
						loadSelectedTabURL(tab)
					}
				}
				.onChange(of: selectedTab, initial: true) { oldTab, newTab in
					guard let newTab = newTab else { return }
					loadSelectedTabURL(newTab)
				}
				.onChange(of: selectedTab?.webService.url, initial: true) { oldURL, newURL in
					if let tab = selectedTab, tab.url != newURL {
						tab.url = newURL ?? ""
						saveContext()
					}
				}
				.toolbar {
					ToolbarItem(placement: .principal) {
						URLBarView(selectedTab: $selectedTab)
							.frame(minWidth: 400, maxWidth: .infinity)
					}
				}
		} else {
			Text("No Tab Selected")
		}
	}

	private func loadSelectedTabURL(_ tab: Tab) {
		let urlToLoad = tab.url.isEmpty ? "https://www.google.com" : tab.url
		tab.webService.loadURL(urlToLoad)
		print("Loading URL for tab: \(urlToLoad)")
	}

	private func saveContext() {
		do {
			try selectedTab?.modelContext?.save()
		} catch {
			print("Failed to save context: \(error)")
		}
	}
}
