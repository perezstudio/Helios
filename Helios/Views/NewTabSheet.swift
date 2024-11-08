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
	@State private var urlString = ""
	@State private var showError = false
	@State private var errorMessage = ""
	
	private func validateAndCreateURL(_ input: String) -> URL? {
		// If the input already starts with a scheme, use it as is
		if input.starts(with: "http://") || input.starts(with: "https://") {
			return URL(string: input)
		}
		
		// Try with https:// prefix first
		if let httpsURL = URL(string: "https://" + input) {
			return httpsURL
		}
		
		// If https:// fails, try http://
		if let httpURL = URL(string: "http://" + input) {
			return httpURL
		}
		
		return nil
	}
	
	private func createTab() {
		// Trim whitespace and newlines
		let trimmedString = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
		
		guard !trimmedString.isEmpty else {
			errorMessage = "Please enter a URL"
			showError = true
			return
		}
		
		guard let url = validateAndCreateURL(trimmedString) else {
			errorMessage = "Invalid URL. Please enter a valid web address."
			showError = true
			return
		}
		
		let tab = Tab(title: url.host ?? "New Tab", url: url)
		workspace.tabs.append(tab)
		try? modelContext.save()
		dismiss()
	}
	
	var body: some View {
		VStack(spacing: 16) {
			Text("New Tab")
				.font(.headline)
			
			TextField("Enter URL or search term", text: $urlString)
				.textFieldStyle(.roundedBorder)
				.onSubmit {
					createTab()
				}
			
			HStack {
				Button("Cancel") {
					dismiss()
				}
				.keyboardShortcut(.escape)
				
				Button("Create Tab") {
					createTab()
				}
				.keyboardShortcut(.return)
				.buttonStyle(.borderedProminent)
			}
		}
		.frame(width: 400)
		.padding()
		.alert("Error", isPresented: $showError) {
			Button("OK") {
				showError = false
			}
		} message: {
			Text(errorMessage)
		}
	}
}
