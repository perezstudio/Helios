//
//  NewWorkspaceSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewWorkspaceSheet: View {
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@Query private var profiles: [Profile]
	@State private var workspaceName = ""
	@State private var iconName = "globe"
	@State private var selectedProfile: Profile?
	
	var body: some View {
		VStack(spacing: 16) {
			Text("Create New Workspace")
				.font(.headline)
			
			TextField("Workspace Name", text: $workspaceName)
				.textFieldStyle(.roundedBorder)
			
			Picker("Profile", selection: $selectedProfile) {
				ForEach(profiles) { profile in
					Text(profile.name).tag(profile as Profile?)
				}
			}
			.pickerStyle(.menu)
			
			SFSymbolsPicker(selectedSymbol: $iconName)
			
			HStack {
				Button("Cancel") {
					dismiss()
				}
				.keyboardShortcut(.escape)
				
				Button("Create") {
					createWorkspace()
				}
				.keyboardShortcut(.return)
				.buttonStyle(.borderedProminent)
				.disabled(workspaceName.isEmpty || selectedProfile == nil)
			}
		}
		.frame(width: 400)
		.padding()
		.onAppear {
			if selectedProfile == nil && !profiles.isEmpty {
				selectedProfile = profiles[0]
			}
		}
	}
	
	private func createWorkspace() {
		guard !workspaceName.isEmpty, let profile = selectedProfile else { return }
		
		let workspace = Workspace(name: workspaceName, iconName: iconName, profile: profile)
		profile.workspaces.append(workspace)
		try? modelContext.save()
		dismiss()
	}
}
