//
//  ProfilePickerView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct ProfilePicker: View {
	@Binding var selectedProfile: Profile?
	@Query private var profiles: [Profile]
	@State private var showingNewProfileSheet = false
	
	var body: some View {
		HStack {
			Picker("Profile", selection: $selectedProfile) {
				Text("Select Profile").tag(nil as Profile?)
				ForEach(profiles) { profile in
					Text(profile.name).tag(profile as Profile?)
				}
			}
			.pickerStyle(.menu)
			.frame(maxWidth: .infinity)
			
			Button(action: { showingNewProfileSheet = true }) {
				Image(systemName: "plus")
			}
		}
		.padding()
		.sheet(isPresented: $showingNewProfileSheet) {
			NewProfileSheet()
		}
		.onChange(of: profiles) { oldValue, newValue in
			// If there's no selected profile and we have profiles, select the first one
			if selectedProfile == nil && !newValue.isEmpty {
				selectedProfile = newValue[0]
			}
		}
		.onAppear {
			// Set initial profile if none is selected
			if selectedProfile == nil && !profiles.isEmpty {
				selectedProfile = profiles[0]
			}
		}
	}
}
