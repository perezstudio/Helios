//
//  AddProfileSheet.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

struct AddProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.modelContext) var modelContext
    @State private var profileName = ""
    
    var body: some View {
        NavigationStack {
            Form {
                TextField("Profile Name", text: $profileName)
            }
            .formStyle(.grouped)
            .navigationTitle("New Profile")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        createProfile()
                        dismiss()
                    }
                    .disabled(profileName.isEmpty)
                }
            }
        }
        .frame(width: 300, height: 150)
    }
    
    private func createProfile() {
        let profile = Profile(name: profileName)
        modelContext.insert(profile)
        try? modelContext.save()
    }
}
