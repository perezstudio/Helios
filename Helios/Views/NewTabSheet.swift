//
//  NewTabSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewTabSheet: View {
	let workspace: Workspace
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@State private var urlOrSearchText = ""
	@FocusState private var isTextFieldFocused: Bool
	@AppStorage("defaultSearchEngine") private var defaultSearchEngine = "Google"
	
	var body: some View {
		TextField("Enter URL or search term", text: $urlOrSearchText)
			.textFieldStyle(.roundedBorder)
			.frame(width: 400)
			.focused($isTextFieldFocused)
			.onSubmit(createTab)
			.submitLabel(.return)
			.interactiveDismissDisabled(false)
			.onAppear {
				isTextFieldFocused = true
			}
			.padding()
	}
	
	private func createTab() {
		let trimmedText = urlOrSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedText.isEmpty else {
			dismiss()
			return
		}
		
		// If it's a valid URL, use it directly
		if let url = validateAndCreateURL(trimmedText) {
			createNewTab(with: url)
			dismiss()
			return
		}
		
		// If not a URL, create a search URL
		let searchURL = createSearchURL(for: trimmedText)
		createNewTab(with: searchURL)
		dismiss()
	}
	
	private func validateAndCreateURL(_ input: String) -> URL? {
		// If the input already starts with a scheme, use it as is
		if input.starts(with: "http://") || input.starts(with: "https://") {
			return URL(string: input)
		}
		
		// Try with https:// prefix first
		if let httpsURL = URL(string: "https://" + input),
		   let host = httpsURL.host,
		   host.contains(".") { // Basic check for domain-like structure
			return httpsURL
		}
		
		// If https:// fails, try http://
		if let httpURL = URL(string: "http://" + input),
		   let host = httpURL.host,
		   host.contains(".") { // Basic check for domain-like structure
			return httpURL
		}
		
		return nil
	}
	
	private func createSearchURL(for searchTerm: String) -> URL {
		let encodedSearch = searchTerm.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? searchTerm
		
		switch defaultSearchEngine {
		case "DuckDuckGo":
			return URL(string: "https://duckduckgo.com/?q=\(encodedSearch)")!
		case "Bing":
			return URL(string: "https://www.bing.com/search?q=\(encodedSearch)")!
		case "Google":
			fallthrough
		default:
			return URL(string: "https://www.google.com/search?q=\(encodedSearch)")!
		}
	}
	
	private func createNewTab(with url: URL) {
		let newTab = Tab.createNewTab(with: url, in: workspace)
		try? modelContext.save()
		
		// Post notification to select the new tab
		NotificationCenter.default.post(
			name: .selectNewTab,
			object: SelectTabRequest(workspace: workspace, tab: newTab)
		)
	}
}
