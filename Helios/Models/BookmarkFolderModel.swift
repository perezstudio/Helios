//
//  BookmarkFolderModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

@Model
final class BookmarkFolder {
	var id: UUID
	var name: String
	var bookmarks: [Tab]
	
	init(name: String) {
		self.id = UUID()
		self.name = name
		self.bookmarks = []
	}
}

// MARK: - BookmarkFolder Equatable Extension
extension BookmarkFolder: Equatable {
	static func == (lhs: BookmarkFolder, rhs: BookmarkFolder) -> Bool {
		lhs.id == rhs.id
	}
}
