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
	
	var allWorkspaces: [Workspace] {
		profiles.flatMap { $0.workspaces }
	}
	
	var body: some View {
		ScrollView(.horizontal, showsIndicators: false) {
			HStack(spacing: 12) {
				ForEach(allWorkspaces) { workspace in
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
