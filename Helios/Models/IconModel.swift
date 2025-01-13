//
//  IconModel.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI

// Define the icon group structure
struct IconGroup: Identifiable {
	let id = UUID()
	let name: String
	let symbols: [String]
}

let iconGroups: [IconGroup] = [
	IconGroup(name: "Defaults", symbols: ["square.stack", "square.stack.fill"]),
	IconGroup(name: "Communication", symbols: ["microphone", "microphone.fill", "microphone.circle", "microphone.circle.fill", "microphone.square", "microphone.square.fill", "microphone.slash", "microphone.slash.fill", "microphone.slash.circle", "microphone.slash.circle.fill", "microphone.badge.plus", "microphone.badge.plus.fill", "microphone.badge.xmark", "microphone.badge.xmark.fill"]),
	
	IconGroup(name: "Transport", symbols: ["car", "bus", "airplane"]),
	IconGroup(name: "Weather", symbols: ["cloud", "sun.max", "wind"]),
	IconGroup(name: "Nature", symbols: ["leaf", "flame", "tree"])
]
// Sample Data
//let iconGroups: [IconGroup] = [
//	IconGroup(name: "Communication", symbols: ["message", "phone", "envelope", "microphone", "square.stack.fill"]),
//	IconGroup(name: "Transport", symbols: ["car", "bus", "airplane"]),
//	IconGroup(name: "Weather", symbols: ["cloud", "sun.max", "wind"]),
//	IconGroup(name: "Nature", symbols: ["leaf", "flame", "tree"])
//]
