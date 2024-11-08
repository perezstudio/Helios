//
//  AllWorkspacesPageControl.swift
//  Helios
//
//  Created by Kevin Perez on 11/8/24.
//

import SwiftUI
import SwiftData

struct AllWorkspacesPageControl: View {
	@Binding var selectedWorkspace: Workspace?
	@Query private var profiles: [Profile]
	@State private var showingProfileChangeSheet = false
	@State private var workspaceToChange: Workspace?
	
	var allWorkspaces: [Workspace] {
		profiles.flatMap { $0.workspaces }
	}
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(allWorkspaces) { workspace in
					WorkspaceButton(
						workspace: workspace,
						isSelected: selectedWorkspace?.id == workspace.id,
						onSelect: {
							withAnimation(.easeOut) {
								selectedWorkspace = workspace
							}
						},
						onChangeProfile: {
							workspaceToChange = workspace
							showingProfileChangeSheet = true
						}
					)
				}
			}
			.padding(.horizontal)
		}
		.sheet(isPresented: $showingProfileChangeSheet) {
			if let workspace = workspaceToChange {
				ChangeProfileSheet(workspace: workspace)
			}
		}
	}
}

struct WorkspaceButton: View {
	let workspace: Workspace
	let isSelected: Bool
	let onSelect: () -> Void
	let onChangeProfile: () -> Void
	@State private var showingMenu = false
	
	var body: some View {
		HStack(spacing: 4) {
			Button(action: onSelect) {
				VStack(spacing: 4) {
					Image(systemName: workspace.iconName)
						.font(.system(size: 16))
						.foregroundColor(isSelected ? .accentColor : .secondary)
					
					Text(workspace.name)
						.font(.caption2)
						.lineLimit(1)
						.foregroundColor(isSelected ? .accentColor : .secondary)
				}
				.frame(width: 44)
			}
			.buttonStyle(.plain)
			
			Menu {
				Button("Change Profile") {
					onChangeProfile()
				}
			} label: {
				Image(systemName: "ellipsis")
					.font(.caption)
					.foregroundColor(.secondary)
			}
			.menuStyle(.borderlessButton)
		}
	}
}
