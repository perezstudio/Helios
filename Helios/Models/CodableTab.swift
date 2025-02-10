//
//  CodableTab.swift
//  Helios
//
//  Created by Kevin Perez on 2/10/25.
//


import Foundation
import SwiftData
import CoreTransferable

// Codable wrapper for Tab
struct CodableTab: Codable {
    let id: UUID
    let title: String
    let url: String
    let type: TabType
    let bookmarkedUrl: String?
    
    init(from tab: Tab) {
        self.id = tab.id
        self.title = tab.title
        self.url = tab.url
        self.type = tab.type
        self.bookmarkedUrl = tab.bookmarkedUrl
    }
}

