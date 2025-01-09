//
//  URLBarView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI

struct URLBarView: View {
	@Binding var selectedTab: Tab? // Selected tab binding
	@Environment(\.modelContext) var modelContext // SwiftData context

	@State private var tempURL: String = "" // Local state for text input

	var body: some View {
		TextField("Enter URL", text: $tempURL, onCommit: {
			// Update the tab’s URL and load it when the user presses Enter
			if (selectedTab != nil) && selectedTab?.url != tempURL {
				selectedTab?.url = tempURL
				selectedTab?.webService.loadURL(tempURL) // Load new URL in web view
				saveContext()
			}
		})
		.textFieldStyle(.roundedBorder)
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding()
		.onChange(of: selectedTab, initial: true) { oldTab, newTab in
			tempURL = newTab?.url ?? ""
		}
		.onChange(of: selectedTab?.webService.url, initial: true) { oldURL, newURL in
			if let tab = selectedTab, tab.url != newURL {
				tab.url = newURL ?? ""
				tempURL = newURL ?? ""
				saveContext()
			}
		}
	}

	// MARK: - Save Context
	private func saveContext() {
		do {
			try modelContext.save()
		} catch {
			print("Failed to save context: \(error)")
		}
	}
}

#Preview {
	@Previewable @State var mockTab: Tab? = Tab(title: "Example", url: "https://www.example.com")
	URLBarView(selectedTab: $mockTab)
}
