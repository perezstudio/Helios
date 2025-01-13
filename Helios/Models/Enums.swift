//
//  Enums.swift
//  Helios
//
//  Created by Kevin Perez on 1/12/25.
//

import SwiftData
import SwiftUI

public enum TabType: String, Codable {
	case pinned
	case bookmark
	case normal
}

import SwiftUI

enum ColorTheme: String, CaseIterable, Codable {
	case blue = "blue"
	case red = "red"
	case green = "green"
	case purple = "purple"
	case orange = "orange"
	case pink = "pink"
	case teal = "teal"
	
	var color: Color {
		switch self {
		case .blue:
			return Color.blue
		case .red:
			return Color.red
		case .green:
			return Color.green
		case .purple:
			return Color.purple
		case .orange:
			return Color.orange
		case .pink:
			return Color.pink
		case .teal:
			return Color.teal
		}
	}
	
	var name: String {
		self.rawValue.capitalized
	}
	
	static var defaultTheme: ColorTheme {
		.blue
	}
}
