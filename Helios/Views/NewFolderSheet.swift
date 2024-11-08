//
//  NewFolderSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewFolderSheet: View {
	let workspace: Workspace
	let initialTab: Tab?
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@State private var folderName = ""
	
	var body: some View {
		VStack(spacing: 16) {
			Text("New Bookmark Folder")
				.font(.headline)
			
			TextField("Folder Name", text: $folderName)
				.textFieldStyle(.roundedBorder)
			
			HStack {
				Button("Cancel") {
					isPresented = false
				}
				.keyboardShortcut(.escape)
				
				Button("Create") {
					createFolder()
				}
				.keyboardShortcut(.return)
				.buttonStyle(.borderedProminent)
				.disabled(folderName.isEmpty)
			}
		}
		.frame(width: 300)
		.padding()
	}
	
	private func createFolder() {
		let newFolder = BookmarkFolder(name: folderName)
		if let tab = initialTab {
			newFolder.bookmarks.append(tab)
		}
		workspace.bookmarkFolders.append(newFolder)
		try? modelContext.save()
		isPresented = false
	}
}
