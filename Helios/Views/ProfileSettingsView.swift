//
//  ProfileSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
	@Environment(\.modelContext) var modelContext
	@Query(sort: \Profile.name) private var profiles: [Profile]
	@State private var showAddProfile = false
	@State private var selectedProfile: Profile?
	@State private var showDeleteAlert = false
	@State private var profileToDelete: Profile?
	
	var body: some View {
		VStack(alignment: .leading, spacing: 16) {
			Text("Profiles help keep your data separate across Workspaces - like history, logins, cookies, and extensions. You can use any Profile across one or many Workspaces.")
				.foregroundStyle(.secondary)
				.padding(.horizontal)
			
			HStack(alignment: .top, spacing: 20) {
				// Left side: Profile List
				VStack {
					List(selection: $selectedProfile) {
						ForEach(profiles) { profile in
							ProfileRow(profile: profile)
								.tag(profile)
								.contextMenu {
									Button(role: .destructive) {
										profileToDelete = profile
										showDeleteAlert = true
									} label: {
										Label("Delete", systemImage: "trash")
									}
								}
						}
					}
					.listStyle(.bordered)
					
					// Buttons below list
					HStack {
						Button(role: .destructive, action: {
							if let selected = selectedProfile {
								profileToDelete = selected
								showDeleteAlert = true
							}
						}) {
							Label("Delete Profile", systemImage: "trash")
						}
						.disabled(selectedProfile == nil)
						
						Spacer()
						
						Button(action: { showAddProfile = true }) {
							Label("Add Profile", systemImage: "plus")
						}
					}
					.padding(.top, 8)
				}
				
				// Right side: Profile Settings
				if let profile = selectedProfile {
					ProfileDetailView(profile: profile)
						.frame(maxWidth: .infinity)
				} else {
					ContentUnavailableView(
						"No Profile Selected",
						systemImage: "person.crop.circle.badge.questionmark",
						description: Text("Select a profile to view or edit its settings")
					)
					.frame(maxWidth: .infinity)
				}
			}
		}
		.padding()
		.navigationTitle("Profiles")
		.sheet(isPresented: $showAddProfile) {
			CreateProfileView()
		}
		.alert("Delete Profile", isPresented: $showDeleteAlert) {
			Button("Cancel", role: .cancel) { }
			Button("Delete", role: .destructive) {
				if let profile = profileToDelete {
					deleteProfile(profile)
					if selectedProfile?.id == profile.id {
						selectedProfile = nil
					}
				}
			}
		} message: {
			Text("Are you sure you want to delete this profile? This action cannot be undone.")
		}
	}
	
	private func deleteProfile(_ profile: Profile) {
		modelContext.delete(profile)
		try? modelContext.save()
	}
}
