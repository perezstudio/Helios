//
//  Profile.swift
//  Helios
//
//  Created by Kevin Perez on 1/6/25.
//
import SwiftUI
import SwiftData

@Model
class Profile {
    var id: UUID = UUID()
    var name: String
    var workspaces: [Workspace] = []
    
    init(name: String) {
        self.name = name
    }
	
	func addWorkspace(name: String, icon: String) {
		let workspace = Workspace(name: name, icon: icon)
		workspaces.append(workspace)
	}
}
