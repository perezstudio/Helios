//
//  WorkspacesTabView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct WorkspacesTabView: View {
	let profile: Profile
	@Binding var selectedWorkspace: Workspace?
	@State private var dragOffset: CGFloat = 0
	
	private var currentWorkspaceIndex: Int {
		profile.workspaces.firstIndex(where: { $0.id == selectedWorkspace?.id }) ?? 0
	}
	
	var body: some View {
		GeometryReader { geometry in
			HStack(spacing: 0) {
				ForEach(profile.workspaces) { workspace in
					WorkspaceView(workspace: workspace)
						.frame(width: geometry.size.width)
				}
			}
			.offset(x: -CGFloat(currentWorkspaceIndex) * geometry.size.width + dragOffset)
			.gesture(
				DragGesture()
					.onChanged { value in
						dragOffset = value.translation.width
					}
					.onEnded { value in
						let threshold = geometry.size.width / 3
						var newIndex = currentWorkspaceIndex
						
						if abs(value.translation.width) > threshold {
							if value.translation.width > 0 && currentWorkspaceIndex > 0 {
								newIndex -= 1
							} else if value.translation.width < 0 && currentWorkspaceIndex < profile.workspaces.count - 1 {
								newIndex += 1
							}
						}
						
						withAnimation(.easeOut) {
							dragOffset = 0
							selectedWorkspace = profile.workspaces[newIndex]
						}
					}
			)
			.animation(.easeOut, value: dragOffset)
			.clipped()
			.onAppear {
				// Set initial workspace if none is selected
				if selectedWorkspace == nil && !profile.workspaces.isEmpty {
					selectedWorkspace = profile.workspaces[0]
				}
			}
			.onChange(of: profile.workspaces) { oldValue, newValue in
				// Ensure workspace selection remains valid when workspaces change
				if selectedWorkspace == nil && !newValue.isEmpty {
					selectedWorkspace = newValue[0]
				}
			}
		}
	}
}
