//
//  WorkspaceView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct WorkspaceView: View {
	let workspace: Workspace
	
	var body: some View {
		VStack {
			HStack {
				Image(systemName: workspace.iconName)
					.font(.title2)
				Text(workspace.name)
					.font(.headline)
			}
			.padding()
			
			Spacer()
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity)
	}
}
