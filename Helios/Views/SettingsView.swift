//
//  SettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//


import SwiftUI
import SwiftData

// Main Settings Window
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @Query private var profiles: [Profile]
    
    var body: some View {
		NavigationStack {
			TabView {
				ProfileSettingsView()
					.tabItem {
						Label("Profiles", systemImage: "person.circle")
					}
				SearchEngineSettingsView()
					.tabItem {
						Label("Search", systemImage: "magnifyingglass")
					}
				WebsitesSettingsView()
					.tabItem {
						Label("Websites", systemImage: "globe")
					}
			}
		}
		.navigationTitle("Settings")
		.frame(width: 700, height: 400)
//        NavigationSplitView {
//            List {
//                NavigationLink(destination: ProfileSettingsView()) {
//                    Label("Profiles", systemImage: "person.circle")
//                }
//            }
//            .listStyle(SidebarListStyle())
//        } detail: {
//            Text("Select a setting to customize")
//                .foregroundStyle(.secondary)
//        }
        
    }
}
