//
//  URLBarView.swift
//  Helios
//
//  Created by Kevin Perez on 2/10/25.
//

import SwiftUI
import SwiftData

struct URLBarView: View {
	@Environment(\.dismiss) var dismiss
	@Bindable var viewModel: BrowserViewModel
	let windowId: UUID
	let currentTab: Tab? // Optional current tab
	let isSheet: Bool // Whether this is shown in a sheet or inline
	
	@State private var inputText: String = ""
	@State private var inputType: TextType = .url
	@FocusState private var isInputFocused: Bool
	
	enum TextType {
		case url
		case search
		
		var icon: String {
			switch self {
			case .url: return "globe"
			case .search: return "magnifyingglass"
			}
		}
	}
	
	init(viewModel: BrowserViewModel, windowId: UUID, currentTab: Tab? = nil, isSheet: Bool = false) {
		self.viewModel = viewModel
		self.windowId = windowId
		self.currentTab = currentTab
		self.isSheet = isSheet
		_inputText = State(initialValue: currentTab?.url ?? "")
	}
	
	var body: some View {
		VStack(spacing: isSheet ? 16 : 8) {
			HStack(spacing: 12) {
				Image(systemName: inputType.icon)
					.font(isSheet ? .title2 : .body)
					.foregroundStyle(.secondary)
				
				TextField(isSheet ? "Enter URL or search" : currentTab?.url ?? "Enter URL or search", text: $inputText)
					.textFieldStyle(.plain)
					.font(isSheet ? .title3 : .body)
					.focused($isInputFocused)
					.onChange(of: inputText) { _, newValue in
						updateInputType(text: newValue)
					}
					.onSubmit {
						Task {
							await handleSubmit()
						}
					}
				
				if !inputText.isEmpty {
					Button(action: { inputText = "" }) {
						Image(systemName: "xmark.circle.fill")
							.foregroundStyle(.secondary)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(isSheet ? 12 : 8)
			.background(Color(.textBackgroundColor))
			.cornerRadius(8)
			
			if isSheet && !inputText.isEmpty {
				VStack(alignment: .leading, spacing: 8) {
					switch inputType {
					case .url:
						Text(formatUrlString(inputText))
							.foregroundStyle(.secondary)
					case .search:
						if let searchEngine = viewModel.currentWorkspace?.profile?.defaultSearchEngine ?? SearchEngine.defaultEngines.first {
							Text("Search \(searchEngine.name): \(inputText)")
								.foregroundStyle(.secondary)
						}
					}
				}
				.padding(.horizontal)
			}
		}
		.padding(isSheet ? 16 : 8)
		.frame(maxWidth: isSheet ? 500 : .infinity)
		.onChange(of: currentTab?.url) { _, newURL in
			// Only update the input text if it's not being edited (not focused)
			if !isSheet && !isInputFocused {
				inputText = newURL ?? ""
				updateInputType(text: inputText)
			}
		}
		.onAppear {
			// Set initial URL if there's a current tab
			if !isSheet, let tabUrl = currentTab?.url {
				inputText = tabUrl
				updateInputType(text: tabUrl)
			}
			isInputFocused = isSheet
		}
	}
	
	private func updateInputType(text: String) {
		inputType = looksLikeUrl(text) ? .url : .search
	}
	
	@MainActor
	private func handleSubmit() async {
		if let currentTab = currentTab, !isSheet {
			// Update existing tab
			if inputType == .url {
				let formattedUrl = formatUrlString(inputText)
				if let url = URL(string: formattedUrl) {
					currentTab.url = formattedUrl
					viewModel.getWebView(for: currentTab).load(URLRequest(url: url))
				}
			} else {
				// Handle search in current tab
				if let searchEngine = viewModel.currentWorkspace?.profile?.defaultSearchEngine ?? SearchEngine.defaultEngines.first {
					let searchUrl = searchEngine.searchUrl.replacingOccurrences(
						of: "%s",
						with: inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
					)
					if let url = URL(string: searchUrl) {
						currentTab.url = searchUrl
						viewModel.getWebView(for: currentTab).load(URLRequest(url: url))
					}
				}
			}
		} else {
			// Create new tab
			if inputType == .url {
				let formattedUrl = formatUrlString(inputText)
				await viewModel.addNewTab(
					windowId: windowId,
					title: "New Tab",
					url: formattedUrl
				)
			} else {
				if let searchEngine = viewModel.currentWorkspace?.profile?.defaultSearchEngine ?? SearchEngine.defaultEngines.first {
					let searchUrl = searchEngine.searchUrl.replacingOccurrences(
						of: "%s",
						with: inputText.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
					)
					await viewModel.addNewTab(
						windowId: windowId,
						title: "Search: \(inputText)",
						url: searchUrl
					)
				}
			}
		}
		
		if isSheet {
			dismiss()
		}
		isInputFocused = false
	}
	
	private func looksLikeUrl(_ input: String) -> Bool {
		// Common URL prefixes
		let urlPrefixes = ["http://", "https://", "file://", "ftp://"]
		if urlPrefixes.contains(where: { input.lowercased().hasPrefix($0) }) {
			return true
		}
		
		// Ignore empty strings and about: URLs
		if input.isEmpty || input.starts(with: "about:") {
			return false
		}
		
		let strippedInput = input
			.replacingOccurrences(of: "https://", with: "")
			.replacingOccurrences(of: "http://", with: "")
			.replacingOccurrences(of: "www.", with: "")
			.trimmingCharacters(in: .whitespacesAndNewlines)
		
		// Check for IP addresses
		let ipPattern = "^\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}\\.\\d{1,3}$"
		let ipPredicate = NSPredicate(format: "SELF MATCHES %@", ipPattern)
		if ipPredicate.evaluate(with: strippedInput) {
			return true
		}
		
		// Check for domain names with more flexible pattern
		let domainPattern = "^[a-zA-Z0-9][a-zA-Z0-9-]{0,61}[a-zA-Z0-9]\\.[a-zA-Z]{2,}$"
		let domainPredicate = NSPredicate(format: "SELF MATCHES %@", domainPattern)
		
		let commonTLDs = [".com", ".org", ".net", ".edu", ".gov", ".io", ".dev"]
		let hasCommonTLD = commonTLDs.contains { strippedInput.lowercased().hasSuffix($0) }
		
		return domainPredicate.evaluate(with: strippedInput) || hasCommonTLD
	}
	
	private func formatUrlString(_ input: String) -> String {
		var urlString = input.trimmingCharacters(in: .whitespacesAndNewlines)
		
		let validProtocols = ["http://", "https://", "file://", "ftp://"]
		if validProtocols.contains(where: { urlString.lowercased().hasPrefix($0) }) {
			return urlString
		}
		
		return "https://" + urlString
	}
}

#Preview {
	URLBarView(viewModel: BrowserViewModel(), windowId: UUID())
}
