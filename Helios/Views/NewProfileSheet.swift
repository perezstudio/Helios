//
//  NewProfileSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewProfileSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@State private var profileName = ""
	
	var body: some View {
		VStack(spacing: 16) {
			Text("Create New Profile")
				.font(.headline)
			
			TextField("Profile Name", text: $profileName)
				.textFieldStyle(.roundedBorder)
				.onSubmit {
					createProfile()
				}
			
			HStack {
				Button("Cancel") {
					dismiss()
				}
				.keyboardShortcut(.escape)
				
				Button("Create") {
					createProfile()
				}
				.keyboardShortcut(.return)
				.buttonStyle(.borderedProminent)
				.disabled(profileName.isEmpty)
			}
		}
		.frame(width: 300)
		.padding()
	}
	
	private func createProfile() {
		guard !profileName.isEmpty else { return }
		
		let profile = Profile(name: profileName)
		// Create a default workspace
		let defaultWorkspace = Workspace(name: "General", iconName: "globe")
		profile.workspaces.append(defaultWorkspace)
		
		modelContext.insert(profile)
		try? modelContext.save()
		dismiss()
	}
}
