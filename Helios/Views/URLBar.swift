//
//  URLBar.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData
import WebKit

// MARK: - URL Bar
struct URLBar: View {
	@Binding var selectedTab: Tab?
	@Environment(\.modelContext) private var modelContext
	@State private var urlText: String = ""
	@State private var isEditing = false
	@FocusState private var isFocused: Bool
	@State private var urlError: String?
	@AppStorage("defaultSearchEngine") private var defaultSearchEngine = "Google"
	
	private func updateURLText(from url: URL) {
		if !isFocused {
			urlText = url.absoluteString
		}
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 8) {
				// SSL Indicator
				if let tab = selectedTab {
					SSLIndicator(tab: tab)
				}
				
				// URL TextField
				TextField("Enter URL or search", text: $urlText)
					.textFieldStyle(URLTextFieldStyle(isEditing: isEditing))
					.focused($isFocused)
					.onSubmit {
						validateAndSubmitURL()
					}
					.onChange(of: isFocused) { _, newValue in
						isEditing = newValue
						if !newValue {
							updateURLText(from: selectedTab?.url ?? URL(string: "about:blank")!)
						}
					}
				
				// Progress Indicator and Refresh Button
				if let tab = selectedTab {
					LoadingButton(tab: tab)
				}
			}
			
			// Error message
			if let error = urlError {
				Text(error)
					.font(.caption)
					.foregroundColor(.red)
					.padding(.horizontal, 8)
			}
		}
		.padding(.horizontal)
		.padding(.vertical, 8)
		.onChange(of: selectedTab) { _, newTab in
			if let url = newTab?.url {
				updateURLText(from: url)
			}
		}
		.onAppear {
			if let url = selectedTab?.url {
				updateURLText(from: url)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewURLChanged)) { notification in
			if let urlChange = notification.object as? WebViewURLChange,
			   urlChange.tab.id == selectedTab?.id {
				updateURLText(from: urlChange.url)
			}
		}
	}
	
	private func validateAndSubmitURL() {
		urlError = nil
		let trimmedText = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !trimmedText.isEmpty else {
			urlError = "Please enter a URL or search term"
			return
		}
		
		// If it's a valid URL, use it directly
		if let url = validateURL(trimmedText) {
			navigateToURL(url)
			return
		}
		
		// If not a URL, use search
		let searchURL = createSearchURL(for: trimmedText)
		navigateToURL(searchURL)
	}
	
	private func validateURL(_ input: String) -> URL? {
		// If the input already starts with a scheme, use it as is
		if input.starts(with: "http://") || input.starts(with: "https://") {
			if let url = URL(string: input),
			   let host = url.host,
			   !host.isEmpty {
				return url
			}
			return nil
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
	
	private func navigateToURL(_ url: URL) {
		guard let tab = selectedTab else { return }
		
		// Update tab's URL
		tab.url = url
		tab.lastVisited = Date()
		try? modelContext.save()
		
		// Trigger WebView load
		WebViewStore.shared.loadURL(url, for: tab.id)
		
		// Also post notification for other observers
		NotificationCenter.default.post(
			name: .loadURL,
			object: LoadURLRequest(tab: tab, url: url)
		)
		
		isFocused = false
	}
}

struct LoadURLRequest {
	let tab: Tab
	let url: URL
}


// MARK: - Custom URL TextField Style
struct URLTextFieldStyle: TextFieldStyle {
	let isEditing: Bool
	
	func _body(configuration: TextField<Self._Label>) -> some View {
		configuration
			.textFieldStyle(.plain)
			.font(.body.monospaced())
			.padding(8)
			.background(Color(.windowBackgroundColor).opacity(0.5))
			.cornerRadius(8)
			.overlay(
				RoundedRectangle(cornerRadius: 8)
					.stroke(Color.secondary.opacity(0.2), lineWidth: 1)
			)
	}
}

extension Notification.Name {
	static let webViewStartedLoading = Notification.Name("webViewStartedLoading")
	static let webViewFinishedLoading = Notification.Name("webViewFinishedLoading")
	static let webViewCanGoBackChanged = Notification.Name("webViewCanGoBackChanged")
	static let webViewCanGoForwardChanged = Notification.Name("webViewCanGoForwardChanged")
	static let webViewURLChanged = Notification.Name("webViewURLChanged")
	static let selectBookmarkedTab = Notification.Name("selectBookmarkedTab")
	static let selectPinnedTab = Notification.Name("selectPinnedTab")
	static let loadURL = Notification.Name("loadURL")
	static let selectNewTab = Notification.Name("selectNewTab")
	static let newTabCreated = Notification.Name("newTabCreated")
	static let registerClearDataOnQuit = Notification.Name("registerClearDataOnQuit")
}

struct WebViewURLChange {
	let tab: Tab
	let url: URL
}
