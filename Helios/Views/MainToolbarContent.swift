//
//  MainToolbarContent.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct MainToolbarContent: View {
	@Binding var selectedTab: Tab?
	@State private var showingSettings = false
	
	var body: some View {
		HStack(spacing: 12) {
			NavigationControls(selectedTab: $selectedTab)
			
			Button {
				showingSettings = true
			} label: {
				Image(systemName: "gear")
					.frame(width: 24, height: 24)
			}
			.buttonStyle(.borderless)
			.popover(isPresented: $showingSettings) {
				SettingsView()
					.frame(width: 600, height: 400)
			}
		}
	}
}
