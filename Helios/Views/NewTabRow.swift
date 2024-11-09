//
//  NewTabRow.swift
//  Helios
//
//  Created by Kevin Perez on 11/8/24.
//

import SwiftUI
import SwiftData

struct NewTabRow: View {
	@Binding var showingNewTabSheet: Bool
	
	var body: some View {
		HStack(spacing: 12) {
			Image(systemName: "plus")
				.frame(width: 16, height: 16)
			
			Text("New Tab")
				.lineLimit(1)
			
			Spacer()
		}
		.padding(.horizontal, 12)
		.padding(.vertical, 8)
		.background(
			RoundedRectangle(cornerRadius: 6)
				.fill(Color.clear)
		)
		.contentShape(Rectangle())
		.onTapGesture {
			showingNewTabSheet = true
		}
	}
}
