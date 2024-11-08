//
//  ChangeProfileSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/8/24.
//

import SwiftUI
import SwiftData

struct ChangeProfileSheet: View {
	let workspace: Workspace
	@Environment(\.dismiss) private var dismiss
	@Environment(\.modelContext) private var modelContext
	@Query private var profiles: [Profile]
	
	var body: some View {
		VStack(spacing: 16) {
			Text("Change Profile")
				.font(.headline)
			
			List(profiles) { profile in
				HStack {
					Text(profile.name)
					Spacer()
					if workspace.profile?.id == profile.id {
						Image(systemName: "checkmark")
							.foregroundColor(.accentColor)
					}
				}
				.contentShape(Rectangle())
				.onTapGesture {
					changeProfile(to: profile)
				}
			}
			.listStyle(.plain)
			
			Button("Cancel") {
				dismiss()
			}
			.keyboardShortcut(.escape)
		}
		.frame(width: 300, height: 400)
		.padding()
	}
	
	private func changeProfile(to newProfile: Profile) {
		// Remove from old profile
		if let oldProfile = workspace.profile {
			oldProfile.workspaces.removeAll(where: { $0.id == workspace.id })
		}
		
		// Add to new profile
		newProfile.workspaces.append(workspace)
		workspace.profile = newProfile
		
		try? modelContext.save()
		dismiss()
	}
}
