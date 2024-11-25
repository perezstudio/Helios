//
//  ProfileRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/25/24.
//
import SwiftUI
import SwiftData

struct ProfileRow: View {
	let profile: Profile
	
	var body: some View {
		HStack {
			Text(profile.name)
			Spacer()
			Text("\(profile.workspaces.count) workspaces")
				.foregroundStyle(.secondary)
		}
	}
}
