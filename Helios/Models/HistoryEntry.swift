//
//  HistoryEntry.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftUI
import SwiftData

@Model
class HistoryEntry {
    @Attribute(.unique) var id: UUID
    var url: String
    var dateAccessed: Date
    var profile: Profile?
    
    init(url: String, dateAccessed: Date = Date(), profile: Profile? = nil) {
        self.id = UUID()
        self.url = url
        self.dateAccessed = dateAccessed
        self.profile = profile
    }
}
