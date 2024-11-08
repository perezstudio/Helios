//
//  NewFolderDropzone.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewFolderDropZone: View {
	@State var isTargeted: Bool
	let onDrop: (TabTransferID) -> Bool
	
	var body: some View {
		RoundedRectangle(cornerRadius: 6)
			.fill(isTargeted ? Color.accentColor.opacity(0.2) : Color.clear)
			.frame(height: 44)
			.overlay(
				Text("Drop here to create new folder")
					.foregroundColor(.secondary)
			)
			.dropDestination(for: TabTransferID.self) { items, _ in
				if let transferID = items.first {
					return onDrop(transferID)
				}
				return false
			} isTargeted: { isTargeted in
				self.isTargeted = isTargeted
			}
	}
}

