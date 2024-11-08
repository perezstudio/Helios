//
//  AddTabButtonStyle.swift
//  Helios
//
//  Created by Kevin Perez on 11/7/24.
//

import SwiftUI
import SwiftData

struct AddTabButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.padding(.horizontal, 12)
			.padding(.vertical, 6)
			.background(Color.accentColor.opacity(0.1))
			.cornerRadius(8)
			.contentShape(Rectangle())
			.opacity(configuration.isPressed ? 0.7 : 1.0)
	}
}
