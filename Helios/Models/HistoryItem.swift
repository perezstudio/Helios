//
//  HistoryItem.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//
import SwiftUI
import SwiftData

@Model
class HistoryItem {
    var id: UUID = UUID()
    var title: String
    var url: String
    var timestamp: Date
    
    init(title: String, url: String, timestamp: Date = Date()) {
        self.title = title
        self.url = url
        self.timestamp = timestamp
    }
}
