//
//  WebsiteSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct WebsiteSettingsView: View {
	@AppStorage("autoPlayVideos") private var autoPlayVideos = false
	@AppStorage("allowPopups") private var allowPopups = false
	
	var body: some View {
		Form {
			Section("Website Behavior") {
				Toggle("Auto-play videos", isOn: $autoPlayVideos)
				Toggle("Allow pop-up windows", isOn: $allowPopups)
			}
		}
	}
}
