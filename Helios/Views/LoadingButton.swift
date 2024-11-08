//
//  LoadingButton.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct LoadingButton: View {
	let tab: Tab
	@State private var isLoading = false
	@Environment(\.modelContext) private var modelContext
	
	var body: some View {
		Group {
			if isLoading {
				ProgressView()
					.scaleEffect(0.7)
					.frame(width: 24, height: 24)
			} else {
				Button(action: refresh) {
					Image(systemName: "arrow.clockwise")
						.foregroundColor(.secondary)
						.frame(width: 24, height: 24)
				}
				.buttonStyle(.plain)
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewStartedLoading)) { notification in
			if let loadingTab = notification.object as? Tab, loadingTab.id == tab.id {
				isLoading = true
			}
		}
		.onReceive(NotificationCenter.default.publisher(for: .webViewFinishedLoading)) { notification in
			if let loadingTab = notification.object as? Tab, loadingTab.id == tab.id {
				isLoading = false
			}
		}
	}
	
	private func refresh() {
		isLoading = true
		tab.lastVisited = Date()
		try? modelContext.save()
	}
}
