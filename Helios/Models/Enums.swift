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

enum UserAgent: String, CaseIterable, Codable {
	case safari = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2.1 Safari/605.1.15"
	case chrome = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
	case firefox = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:121.0) Gecko/20100101 Firefox/121.0"
	case edge = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36 Edg/120.0.0.0"

	var name: String {
		switch self {
		case .safari: return "Safari"
		case .chrome: return "Chrome"
		case .firefox: return "Firefox"
		case .edge: return "Edge"
		}
	}

	static var `default`: UserAgent {
		.safari
	}
}
