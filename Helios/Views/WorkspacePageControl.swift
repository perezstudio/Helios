//
//  WorkspacePageControl.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct WorkspacePageControl: View {
	let profile: Profile
	@Binding var selectedWorkspace: Workspace?
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(profile.workspaces) { workspace in
					Button(action: {
						withAnimation(.easeOut) {
							selectedWorkspace = workspace
						}
					}) {
						VStack(spacing: 4) {
							Image(systemName: workspace.iconName)
								.font(.system(size: 16))
								.foregroundColor(selectedWorkspace?.id == workspace.id ? .accentColor : .secondary)
							
							Text(workspace.name)
								.font(.caption2)
								.lineLimit(1)
								.foregroundColor(selectedWorkspace?.id == workspace.id ? .accentColor : .secondary)
						}
						.frame(width: 44)
					}
					.buttonStyle(.plain)
				}
			}
			.padding(.horizontal)
		}
	}
}
