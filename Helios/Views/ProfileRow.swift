//
//  ProfileRow.swift
//  Helios
//
//  Created by Kevin Perez on 1/13/25.
//

import SwiftUI
import SwiftData

struct ProfileRow: View {
    let profile: Profile
    
    var body: some View {
        HStack {
            Image(systemName: "person.circle.fill")
                .foregroundStyle(.blue)
            
            VStack(alignment: .leading) {
                Text(profile.name)
                    .font(.headline)
                Text("\(profile.workspaces.count) workspaces")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
