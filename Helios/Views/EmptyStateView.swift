//
//  EmptyStateView.swift
//  Helios
//
//  Created by Kevin Perez on 11/8/24.
//

import SwiftUI
import SwiftData

struct EmptyStateView: View {
	let workspace: Workspace?
	let onCreateTab: () -> Void
	
	var body: some View {
		ZStack {
			Color.black.opacity(0.05)
				.background(.ultraThinMaterial)
			
			VStack(spacing: 20) {
				ContentUnavailableView(
					"No Tab Selected",
					systemImage: "globe",
					description: Text("Select an existing tab or create a new one to start browsing")
				)
				
				if workspace != nil {
					Button(action: onCreateTab) {
						Label("New Tab", systemImage: "plus")
					}
					.buttonStyle(.borderedProminent)
				}
			}
		}
		.ignoresSafeArea()
	}
}
