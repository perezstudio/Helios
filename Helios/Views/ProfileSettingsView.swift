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
        VStack {
            // Profile List with Toolbar
            List(selection: $selectedProfile) {
                ForEach(profiles) { profile in
                    ProfileRow(profile: profile)
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
            .listStyle(.inset)
            .toolbar {
				ToolbarItem(placement: .navigation) {
                    Button(action: { showAddProfile = true }) {
                        Label("Add Profile", systemImage: "plus")
                    }
                }
            }
        }
        .navigationTitle("Profiles")
        .sheet(isPresented: $showAddProfile) {
			CreateProfileView()
        }
        .alert("Delete Profile", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                if let profile = profileToDelete {
                    deleteProfile(profile)
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
