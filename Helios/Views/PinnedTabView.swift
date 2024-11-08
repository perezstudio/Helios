//
//  PinnedTabView.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct PinnedTabView: View {
	let tab: Tab
	let isSelected: Bool
	
	var body: some View {
		VStack(spacing: 4) {
			if let favicon = tab.favicon,
			   let image = NSImage(data: favicon) {
				Image(nsImage: image)
					.resizable()
					.frame(width: 16, height: 16)
			} else {
				Image(systemName: "globe")
					.frame(width: 16, height: 16)
			}
			
			Text(tab.title)
				.font(.caption)
				.lineLimit(1)
				.frame(width: 60)
		}
		.padding(.vertical, 4)
		.padding(.horizontal, 8)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
		)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(Color.secondary.opacity(0.0001)) // nearly transparent interactive area
		)
		.overlay(
			RoundedRectangle(cornerRadius: 6)
				.stroke(Color.accentColor.opacity(isSelected ? 0.5 : 0), lineWidth: 1)
		)
	}
}
