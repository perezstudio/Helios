//
//  CreateWorkspaceView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData
import Observation

struct CreateWorkspaceView: View {
	@Environment(\.modelContext) var modelContext
	@Bindable var viewModel: BrowserViewModel
	@Binding var isPresented: Bool
	
	var workspaceToEdit: Workspace?
	
	@State private var formState: WorkspaceFormState  // Changed from @StateObject to @State
	@State private var showIconPicker = false
	@State private var showCreateProfileSheet = false
	@State private var showDeleteAlert = false
	@State private var isProcessing = false
	
	let availableColors = ColorTheme.allCases
	
	@Query(sort: \Profile.name) private var profiles: [Profile]
	
	var isEditing: Bool {
		workspaceToEdit != nil
	}
	
	init(viewModel: BrowserViewModel, isPresented: Binding<Bool>, workspaceToEdit: Workspace?) {
		self.viewModel = viewModel
		self._isPresented = isPresented
		self.workspaceToEdit = workspaceToEdit
		
		// Initialize formState using @State
		self._formState = State(initialValue: WorkspaceFormState(
			workspaceName: workspaceToEdit?.name ?? "",
			selectedIcon: workspaceToEdit?.icon ?? "square.stack",
			selectedColor: workspaceToEdit?.colorTheme ?? ColorTheme.defaultTheme,
			selectedProfile: workspaceToEdit?.profile
		))
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
						Picker("Profile", selection: $formState.selectedProfile.animation()) {
							Text("None").tag(Optional<Profile>.none)
							ForEach(profiles) { profile in
								Text(profile.name).tag(Optional(profile))
							}
						}
						
						Button("Create New Profile") {
							showCreateProfileSheet.toggle()
						}
					}
				}
				
				if isEditing {
					Section {
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
				}
			}
			.formStyle(.grouped)
			.navigationTitle(isEditing ? "Edit Workspace" : "New Workspace")
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Cancel") {
						isPresented = false
					}
					.disabled(isProcessing)
				}
				ToolbarItem(placement: .confirmationAction) {
					Button(isEditing ? "Save" : "Create") {
						Task {
							isProcessing = true
							if isEditing {
								await updateWorkspace()
							} else {
								await createWorkspace()
							}
							isProcessing = false
							isPresented = false
						}
					}
					.disabled(formState.workspaceName.isEmpty || isProcessing)
				}
			}
			.disabled(isProcessing)
		}
		.frame(maxWidth: .infinity)
		.frame(height: 500)
		.popover(isPresented: $showIconPicker) {
			IconPicker(
				selectedIcon: $formState.selectedIcon,
				selectedGroup: $formState.selectedIconGroup
			)
			.frame(width: 300, height: 400)
		}
		.sheet(isPresented: $showCreateProfileSheet) {
			CreateProfileView()
		}
		.alert("Delete Workspace", isPresented: $showDeleteAlert) {
			Button("Cancel", role: .cancel) { }
			Button("Delete", role: .destructive) {
				Task {
					await deleteWorkspace()
					isPresented = false
				}
			}
		} message: {
			Text("Are you sure you want to delete this workspace? This action cannot be undone.")
		}
	}
	
	private func createWorkspace() async {
		await viewModel.addWorkspace(
			name: formState.workspaceName,
			icon: formState.selectedIcon,
			colorTheme: formState.selectedColor,
			profile: formState.selectedProfile
		)
	}
	
	private func updateWorkspace() async {
		guard let workspace = workspaceToEdit else { return }
		await viewModel.updateWorkspace(
			workspace,
			name: formState.workspaceName,
			icon: formState.selectedIcon,
			colorTheme: formState.selectedColor,
			profile: formState.selectedProfile
		)
	}
	
	private func deleteWorkspace() async {
		guard let workspace = workspaceToEdit else { return }
		await viewModel.deleteWorkspace(workspace)
	}
}

@Observable class WorkspaceFormState {
	var workspaceName: String
	var selectedIcon: String
	var selectedColor: ColorTheme
	var selectedProfile: Profile?
	var selectedIconGroup: IconGroup
	
	private var isUpdating = false
	
	init(workspaceName: String = "",
		 selectedIcon: String = "square.stack",
		 selectedColor: ColorTheme = ColorTheme.defaultTheme,
		 selectedProfile: Profile? = nil) {
		self.workspaceName = workspaceName
		self.selectedIcon = selectedIcon
		self.selectedColor = selectedColor
		self.selectedProfile = selectedProfile
		self.selectedIconGroup = iconGroups.first!
	}
	
	func update(name: String? = nil,
				icon: String? = nil,
				color: ColorTheme? = nil,
				profile: Profile? = nil) {
		guard !isUpdating else { return }
		isUpdating = true
		
		if let name = name { self.workspaceName = name }
		if let icon = icon { self.selectedIcon = icon }
		if let color = color { self.selectedColor = color }
		if let profile = profile { self.selectedProfile = profile }
		self.isUpdating = false
	}
}
