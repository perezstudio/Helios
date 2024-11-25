//
//  GeneralSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct GeneralSettingsView: View {
	@AppStorage("newTabBehavior") private var newTabBehavior = "homepage"
	@AppStorage("homepage") private var homepage = "https://www.google.com"
	@AppStorage("downloadLocation") private var downloadLocation = "Downloads"
	
	var body: some View {
		Form {
			Section("New Tab") {
				Picker("New tabs open with:", selection: $newTabBehavior) {
					Text("Homepage").tag("homepage")
					Text("Empty Page").tag("empty")
					Text("Favorites").tag("favorites")
				}
				.pickerStyle(.inline)
				
				TextField("Homepage:", text: $homepage)
			}
			
			Section("Downloads") {
				TextField("Save downloads to:", text: $downloadLocation)
			}
		}
	}
}
