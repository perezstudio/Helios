//
//  BookmarkRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct BookmarkRow: View {
	let tab: Tab
	let isSelected: Bool
	
	var body: some View {
		HStack(spacing: 12) {
			if let favicon = tab.favicon,
			   let image = NSImage(data: favicon) {
				Image(nsImage: image)
					.resizable()
					.frame(width: 16, height: 16)
			} else {
				Image(systemName: "globe")
					.frame(width: 16, height: 16)
			}
			
			VStack(alignment: .leading, spacing: 2) {
				Text(tab.title)
					.lineLimit(1)
				Text(tab.url.host ?? "")
					.font(.caption)
					.foregroundColor(.secondary)
					.lineLimit(1)
			}
		}
		.padding(.vertical, 4)
		.padding(.horizontal, 8)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
		)
	}
}
