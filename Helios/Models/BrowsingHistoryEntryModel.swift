//
//  BrowsingHistoryEntryModel.swift
//  Helios
//
//  Created by Kevin Perez on 11/16/24.
//

import SwiftUI
import SwiftData

@Model
final class BrowsingHistoryEntry {
	var id: UUID
	var url: URL
	var title: String
	var visitDate: Date
	
	init(url: URL, title: String, visitDate: Date) {
		self.id = UUID()
		self.url = url
		self.title = title
		self.visitDate = visitDate
	}
}
