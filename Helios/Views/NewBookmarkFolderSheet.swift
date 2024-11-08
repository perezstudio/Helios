//
//  NewBookmarkFolderSheet.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct NewBookmarkFolderSheet: View {
	let workspace: Workspace
	let pendingTabID: UUID?
	@Binding var isPresented: Bool
	@Environment(\.modelContext) private var modelContext
	@State private var folderName = ""
	
	private func findTab(by id: UUID) -> Tab? {
		let descriptor = FetchDescriptor<Tab>(
			predicate: #Predicate<Tab> { tab in
				tab.id == id
			}
		)
		return try? modelContext.fetch(descriptor).first
	}
	
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
		
		if let tabID = pendingTabID,
		   let tab = findTab(by: tabID) {
			newFolder.bookmarks.append(tab)
		}
		
		workspace.bookmarkFolders.append(newFolder)
		try? modelContext.save()
		isPresented = false
	}
}
