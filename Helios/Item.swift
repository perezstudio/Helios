//
//  Item.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
