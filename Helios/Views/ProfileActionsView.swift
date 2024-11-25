//
//  ProfileActionsView.swift
//  Helios
//
//  Created by Kevin Perez on 11/16/24.
//

import SwiftUI
import SwiftData

struct ProfileActionsView: View {
	let profile: Profile
	
	var body: some View {
		Button("Clear Browsing Data") {
			Task {
				await profile.clearBrowsingData()
			}
		}
	}
}
