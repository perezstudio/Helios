//
//  ProfileSettingsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct ProfileSettingsView: View {
    let profiles: [Profile]
    @State private var showingNewProfileSheet = false
    
    var body: some View {
        List {
            ForEach(profiles) { profile in
                NavigationLink(destination: ProfileDetailView(profile: profile)) {
                    Label(profile.name, systemImage: "person")
                }
            }
        }
        .toolbar {
            ToolbarItem {
                Button(action: { showingNewProfileSheet = true }) {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingNewProfileSheet) {
            NewProfileSheet()
        }
    }
}
