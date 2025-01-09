//
//  CreateProfileView.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//

import SwiftUI
import SwiftData

struct CreateProfileView: View {
	
	@Environment(\.modelContext) var modelContext
	@State var profileName: String = ""
	
    var body: some View {
		Form {
			TextField("Name", text: $profileName)
			Button {
				createProfile()
			} label: {
				Label("Create Profile", systemImage: "person.crop.circle")
			}
		}
		.padding()
    }
	
	func createProfile() {
		let newProfile = Profile(name: profileName)
		modelContext.insert(newProfile)
	}
}

#Preview {
	CreateProfileView(profileName: "Test Name")
}
