//
//  CreateWorkspaceView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

struct CreateWorkspaceView: View {
	
	@Environment(\.modelContext) var modelContext
	@Environment(\.dismiss) var dismiss
	@Query var profiles: [Profile]
	
	@State var workspaceName: String = ""
	@State var workspaceIcon: String = "square.stack" // Default icon
	@State var selectedProfile: Profile?
	@State var createProfileSheet: Bool = false
	@State var showIconPicker: Bool = false // Toggle for popover visibility
	@State var selectedIconGroup: IconGroup = iconGroups.first! // Default icon group
	
	// Alerts
	@State private var showAlert = false
	@State private var alertMessage = ""
	
	var body: some View {
		Form {
			// Workspace Name & Icon Picker Section
			Section(header: Text("Workspace Info")) {
				TextField("Workspace Name", text: $workspaceName)
				
				HStack {
					Text("Workspace Icon")
					Spacer()
					Button {
						showIconPicker.toggle()
					} label: {
						Image(systemName: workspaceIcon)
							.font(.system(size: 24)) // Display selected icon
							.padding()
							.background(Color.gray.opacity(0.50))
							.cornerRadius(8)
					}
					.popover(isPresented: $showIconPicker) {
						IconPicker(selectedIcon: $workspaceIcon, selectedGroup: $selectedIconGroup)
							.frame(width: 300, height: 400) // Set size for popover
					}
				}
			}
			
			// Profile Selection
			Section(header: Text("Profile")) {
				HStack {
					if !profiles.isEmpty {
						Picker("Profile", selection: Binding(
							get: { selectedProfile },
							set: { newValue in selectedProfile = newValue }
						)) {
							Text("None").tag(nil as Profile?) // Allow nil selection
							ForEach(profiles) { profile in
								Text(profile.name).tag(profile as Profile?)
							}
						}
					} else {
						Text("You need to create a profile before creating a workspace")
					}
					
					// Create Profile Button
					Button {
						createProfileSheet.toggle()
					} label: {
						Label("Create New Profile", systemImage: "person.crop.circle")
					}
				}
			}
			
			// Create Workspace Button
			Button {
				createWorkspace()
			} label: {
				Label("Create Workspace", systemImage: "square.stack")
			}
		}
		.padding()
		.sheet(isPresented: $createProfileSheet) {
			CreateProfileView()
		}
		.onAppear {
			if selectedProfile == nil && !profiles.isEmpty {
				selectedProfile = profiles.first
			}
		}
		.alert(isPresented: $showAlert) {
			Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
		}
	}
	
	// MARK: - Create Workspace Function
	func createWorkspace() {
		// Validation
		guard let profile = selectedProfile else {
			alertMessage = "Please select a profile before creating a workspace."
			showAlert = true
			return
		}
		
		guard !workspaceName.isEmpty else {
			alertMessage = "Workspace name cannot be empty."
			showAlert = true
			return
		}
		
		// Add workspace to the selected profile
		profile.addWorkspace(name: workspaceName, icon: workspaceIcon)
		
		// Save context explicitly
		do {
			try modelContext.save()
			print("Workspace '\(workspaceName)' created successfully in profile '\(profile.name)'")
			dismiss()
		} catch {
			alertMessage = "Failed to save workspace: \(error.localizedDescription)"
			showAlert = true
		}
	}
}

#Preview {
	CreateWorkspaceView()
}
