//
//  ProfileSettingsTab.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct ProfileSettingsTab: View {
	@Query(sort: \Profile.name) private var profiles: [Profile]
	@State private var showingNewProfileSheet = false
	
	var body: some View {
		Form {
			Section("Profiles") {
				ForEach(profiles) { profile in
					ProfileRow(profile: profile)
				}
				
				Button("Add Profile") {
					showingNewProfileSheet = true
				}
			}
		}
		.sheet(isPresented: $showingNewProfileSheet) {
			NewProfileSheet()
		}
	}
}
