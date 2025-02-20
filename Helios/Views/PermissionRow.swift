//
//  PermissionRow.swift
//  Helios
//
//  Created by Kevin Perez on 2/12/25.
//

import SwiftUI
import SwiftData

struct PermissionRow: View {
	let title: String
	let selection: PermissionState?
	let defaultValue: PermissionState
	
	var body: some View {
		HStack {
			Text(title)
			Spacer()
			if let selection = selection {
				Text(selection.description)
					.foregroundStyle(.secondary)
			} else {
				Text("\(defaultValue.description) (default)")
					.foregroundStyle(.secondary)
			}
		}
	}
}
