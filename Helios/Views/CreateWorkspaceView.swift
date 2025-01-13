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
	@EnvironmentObject var viewModel: BrowserViewModel
	@Binding var isPresented: Bool
	
	var workspaceToEdit: Workspace?
	
	// Change these to use a StateObject for form state
	@StateObject private var formState = WorkspaceFormState()
	@State private var showIconPicker = false
	@State private var showCreateProfileSheet = false
	@State private var showDeleteAlert = false
	
	let availableColors = ColorTheme.allCases
	
	@Query var profiles: [Profile]
	
	var isEditing: Bool {
		workspaceToEdit != nil
	}
	
	init(isPresented: Binding<Bool>, workspaceToEdit: Workspace?) {
		self._isPresented = isPresented
		self.workspaceToEdit = workspaceToEdit
		
		// Initialize formState with values from workspaceToEdit if available
		let initialState = WorkspaceFormState(
			workspaceName: workspaceToEdit?.name ?? "",
			selectedIcon: workspaceToEdit?.icon ?? "square.stack",
			selectedColor: workspaceToEdit?.colorTheme ?? ColorTheme.defaultTheme,
			selectedProfile: workspaceToEdit?.profile
		)
		self._formState = StateObject(wrappedValue: initialState)
	}
	
	var body: some View {
		NavigationStack {
			Form {
				// Workspace Name
				Section(header: Text("Workspace Name")) {
					TextField("Name", text: $formState.workspaceName)
				}
				
				// Icon Selection
				Section(header: Text("Icon")) {
					HStack {
						Image(systemName: formState.selectedIcon)
							.foregroundColor(Color(formState.selectedColor.rawValue))
							.font(.title2)
						
						Button("Choose Icon") {
							showIconPicker.toggle()
						}
					}
				}
				.popover(isPresented: $showIconPicker) {
					IconPicker(
						selectedIcon: $formState.selectedIcon,
						selectedGroup: $formState.selectedIconGroup
					)
					.frame(width: 300, height: 400)
				}
				
				// Color Selection
				Section(header: Text("Color")) {
					LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 10) {
						ForEach(availableColors, id: \.self) { color in
							Circle()
								.fill(color.color)
								.frame(width: 30, height: 30)
								.overlay(
									Circle()
										.stroke(Color.primary, lineWidth: formState.selectedColor == color ? 2 : 0)
								)
								.onTapGesture {
									formState.selectedColor = color
								}
						}
					}
					.padding(.vertical, 8)
				}
				
				// Profile Selection
				Section(header: Text("Profile")) {
					if profiles.isEmpty {
						Button("Create Profile") {
							showCreateProfileSheet.toggle()
						}
					} else {
						Picker("Profile", selection: $formState.selectedProfile) {
							Text("None").tag(nil as Profile?)
							ForEach(profiles) { profile in
								Text(profile.name).tag(profile as Profile?)
							}
						}
						
						Button("Create New Profile") {
							showCreateProfileSheet.toggle()
						}
					}
				}
				
				if isEditing {
					Section {
						
					}
				}
			}
			.formStyle(.grouped)
			.navigationTitle(isEditing ? "Edit Workspace" : "New Workspace")
			.toolbar {
				ToolbarItem(placement: .destructiveAction) {
					Button(role: .destructive) {
						showDeleteAlert = true
					} label: {
						HStack {
							Spacer()
							Text("Delete Workspace")
							Spacer()
						}
					}
				}
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						isPresented = false
					}
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditing ? "Save" : "Create") {
						if isEditing {
							updateWorkspace()
						} else {
							createWorkspace()
						}
						isPresented = false
					}
					.disabled(formState.workspaceName.isEmpty)
				}
			}
			.alert("Delete Workspace", isPresented: $showDeleteAlert) {
				Button("Cancel", role: .cancel) { }
				Button("Delete", role: .destructive) {
					deleteWorkspace()
					isPresented = false
				}
			} message: {
				Text("Are you sure you want to delete this workspace? This action cannot be undone.")
			}
			.sheet(isPresented: $showCreateProfileSheet) {
				CreateProfileView()
			}
		}
		.frame(maxWidth: .infinity)
		.frame(height: 500)
		.onAppear {
			if let workspace = workspaceToEdit {
				formState.workspaceName = workspace.name
				formState.selectedIcon = workspace.icon
				formState.selectedColor = workspace.colorTheme
				formState.selectedProfile = workspace.profile
			}
		}
	}
	
	private func createWorkspace() {
		viewModel.addWorkspace(
			name: formState.workspaceName,
			icon: formState.selectedIcon,
			colorTheme: formState.selectedColor, // Changed from color to colorTheme
			profile: formState.selectedProfile
		)
	}

	private func updateWorkspace() {
		guard let workspace = workspaceToEdit else { return }
		viewModel.updateWorkspace(
			workspace,
			name: formState.workspaceName,
			icon: formState.selectedIcon,
			colorTheme: formState.selectedColor, // Changed from color to colorTheme
			profile: formState.selectedProfile
		)
	}
	
	private func deleteWorkspace() {
		guard let workspace = workspaceToEdit else { return }
		viewModel.deleteWorkspace(workspace)
	}
}

// Add this class just before or after CreateWorkspaceView
class WorkspaceFormState: ObservableObject {
	@Published var workspaceName: String
	@Published var selectedIcon: String
	@Published var selectedColor: ColorTheme
	@Published var selectedIconGroup = iconGroups.first!
	@Published var selectedProfile: Profile?
	
	init(workspaceName: String = "",
		 selectedIcon: String = "square.stack",
		 selectedColor: ColorTheme = ColorTheme.defaultTheme,
		 selectedProfile: Profile? = nil) {
		self.workspaceName = workspaceName
		self.selectedIcon = selectedIcon
		self.selectedColor = selectedColor
		self.selectedProfile = selectedProfile
	}
}
