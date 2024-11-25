//
//  ProfileDetailView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct ProfileDetailView: View {
    let profile: Profile
    
    var body: some View {
        Form {
            Section("Profile Details") {
                LabeledContent("Name:", value: profile.name)
                LabeledContent("Workspaces:", value: "\(profile.workspaces.count)")
                LabeledContent("Pinned Tabs:", value: "\(profile.pinnedTabs.count)")
            }
        }
        .formStyle(.grouped)
    }
}
