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
	
	private func updateURLText(from url: URL) {
		// Show the complete URL path
		urlText = url.absoluteString
	}
	
	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(spacing: 8) {
				// SSL Indicator
				if let tab = selectedTab {
					SSLIndicator(tab: tab)
				}
				
				// URL TextField
				TextField("Enter URL", text: $urlText)
					.textFieldStyle(URLTextFieldStyle(isEditing: isEditing))
					.focused($isFocused)
					.onSubmit {
						validateAndSubmitURL()
					}
					.onChange(of: isFocused) { _, newValue in
						isEditing = newValue
						if !newValue {
							// Reset to current URL if unfocused without submitting
							urlText = selectedTab?.url.absoluteString ?? ""
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
			// Update URL text when selected tab changes
			if let url = newTab?.url {
				updateURLText(from: url)
			}
		}
		.onAppear {
			// Initialize URL text
			if let url = selectedTab?.url {
				updateURLText(from: url)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewURLChanged)) { notification in
			if let urlChange = notification.object as? WebViewURLChange,
			   urlChange.tab.id == selectedTab?.id,
			   !isFocused {  // Only update if not being edited
				updateURLText(from: urlChange.url)
			}
		}
	}
	
	private func validateAndSubmitURL() {
		// Clear previous error
		urlError = nil
		
		// Basic URL validation
		var urlString = urlText.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Check if URL is empty
		guard !urlString.isEmpty else {
			urlError = "Please enter a URL"
			return
		}
		
		// Add https:// if no scheme is specified
		if !urlString.contains("://") {
			urlString = "https://" + urlString
		}
		
		// Validate URL format
		guard let url = URL(string: urlString) else {
			urlError = "Invalid URL format"
			return
		}
		
		// Check for valid scheme
		guard url.scheme?.lowercased() == "http" || url.scheme?.lowercased() == "https" else {
			urlError = "Only HTTP and HTTPS URLs are supported"
			return
		}
		
		// Check for valid host
		guard let host = url.host, !host.isEmpty else {
			urlError = "Invalid domain"
			return
		}
		
		// Update the tab's URL
		if let tab = selectedTab {
			tab.url = url
			tab.lastVisited = Date()
			try? modelContext.save()
			
			// Unfocus the text field
			isFocused = false
		}
	}
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
}

struct WebViewURLChange {
	let tab: Tab
	let url: URL
}
