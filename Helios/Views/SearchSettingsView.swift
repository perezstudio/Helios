//
//  SearchSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct SearchSettingsView: View {
	@AppStorage("defaultSearchEngine") private var defaultSearchEngine = "Google"
	@AppStorage("showSearchSuggestions") private var showSearchSuggestions = true
	
	var body: some View {
		Form {
			Section("Search Engine") {
				Picker("Search with:", selection: $defaultSearchEngine) {
					Text("Google").tag("Google")
					Text("DuckDuckGo").tag("DuckDuckGo")
					Text("Bing").tag("Bing")
				}
				.pickerStyle(.inline)
				
				Toggle("Show search suggestions", isOn: $showSearchSuggestions)
			}
		}
	}
}
