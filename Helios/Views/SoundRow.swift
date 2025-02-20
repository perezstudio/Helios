//
//  SoundRow.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct SoundRow: View {
	let title: String
	let selection: SoundState?
	let defaultValue: SoundState
	
	var body: some View {
		HStack {
			Text(title)
			Spacer()
			if let selection = selection {
				Text(selection.rawValue)
					.foregroundStyle(.secondary)
			} else {
				Text("\(defaultValue.rawValue) (default)")
					.foregroundStyle(.secondary)
			}
		}
	}
}
